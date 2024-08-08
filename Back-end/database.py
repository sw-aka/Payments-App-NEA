import logging
import time
import random
import math
from decimal import Decimal
import psycopg2
from psycopg2 import pool

from config import TransactionConfig
from response import Response

# Constants
TRANSACTION_CREATION_FEE = TransactionConfig.TRANSACTION_CREATION_FEE
ADMIN_ADDRESS = TransactionConfig.ADMIN_ADDRESS
TRANSFER_FEE_PERCENT = TransactionConfig.TRANSFER_FEE_PERCENT
DELETION_DELAY_AFTER_EXPIRY = TransactionConfig.DELETION_DELAY_AFTER_EXPIRY
ALIAS_ADDRESS_CREATION_FEE = TransactionConfig.ALIAS_CREATION_FEE

TRANSACTION_ID_LENGTH = 32
PUBLIC_KEY_LENGTH = 44
MAX_TRANSFER_PRECISION = 5

MINIMUM_TRANSFER_FEE = Decimal("0.00001")
MAXIMUM_TRANSFER_FEE = Decimal("1")

# Database Creator Class
class DatabaseCreator:
    """
    Class responsible for creating and managing databases.
    """

    def __init__(self, db_name):
        self.db_name = db_name
        self.conn = None
        self.cur = None

    def connect(self):
        """Establish a connection to the database."""
        self.conn = psycopg2.connect(host="localhost", user="postgres", password="password")
        self.conn.autocommit = True
        self.cur = self.conn.cursor()

    def close(self):
        """Close the database connection."""
        self.conn.close()

    def create_db(self):
        """Create a new database."""
        sql = f"""
            CREATE DATABASE {self.db_name}
            WITH OWNER = postgres
            ENCODING = 'UTF8'
            CONNECTION LIMIT = -1
            IS_TEMPLATE = False;
        """
        self.cur.execute(sql)
        logging.info("Database %s created successfully!", self.db_name)

    def check_db_exists(self):
        """Check if the database already exists."""
        sql = """SELECT datname 
            FROM pg_database 
            WHERE datistemplate = false;"""
        self.cur.execute(sql)
        return any(row[0] == self.db_name for row in self.cur.fetchall())

    def create_database_if_not_exists(self):
        """Create the database if it does not exist."""
        self.connect()
        if not self.check_db_exists():
            self.create_db()
        self.close()


# Connection Pool Class
class ConnectionPool:
    """
    Class for managing a connection pool to the database.
    """

    def __init__(self, db_name, user, password, host, port, min_conn, max_conn):
        self.db_name = db_name
        self.user = user
        self.password = password
        self.host = host
        self.port = port
        self.min_conn = min_conn
        self.max_conn = max_conn
        self.pool = None
        
        self.create_pool()
    
    def create_pool(self):
        """Create a connection pool."""
        db_params = {
            'database': self.db_name,
            'user': self.user,
            'password': self.password,
            'host': self.host,
            'port': self.port
        }

        connection_pool = pool.SimpleConnectionPool(self.min_conn, self.max_conn, **db_params)
        self.pool = connection_pool
        
    def get_conn(self):
        """Get a connection from the pool."""
        return self.pool.getconn()
    
    def putconn(self, connection):
        """Return a connection to the pool."""
        self.pool.putconn(connection)
    
    def close(self):
        """Close all connections in the pool."""
        self.pool.closeall()
        self.pool = None
        
    def __del__(self):
        """Close all connections in the pool when the object is deleted."""
        if self.pool:
            self.pool.closeall()


# Database Connector Class
class DatabaseConnector:
    """
    DatabaseConnector class handles interactions with the database for transactions and related operations.
    """

    def __init__(self, conn):
        """
        Initializes the DatabaseConnector with a database connection and cursor.

        Args:
            conn: psycopg2 connection object
            cur: psycopg2 cursor object
        """
        self.conn = conn
        self.cur = conn.cursor()

    def create_tables_if_not_exist(self):
        """Create database tables if they do not exist."""
        table_queries = [
            """
            DO $$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status') THEN
                    CREATE TYPE status AS ENUM ('PENDING', 'COMPLETED', 'EXPIRED', 'PROCESSING');
                END IF;
            END $$;
            """,
            """
            DO $$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type') THEN
                    CREATE TYPE transaction_type AS ENUM ('SEND', 'RECEIVE');
                END IF;
            END $$;
            """,
            f"""
            CREATE TABLE IF NOT EXISTS Balances (
                PublicAddress CHAR({PUBLIC_KEY_LENGTH}) PRIMARY KEY,
                Balance DECIMAL(20, 5) NOT NULL
            );
            """,
            f"""
            CREATE TABLE IF NOT EXISTS AliasAddresses (
                AliasAddress CHAR({PUBLIC_KEY_LENGTH}) PRIMARY KEY,
                MainPublicAddress CHAR({PUBLIC_KEY_LENGTH}) NOT NULL,
                ExpiryTime BIGINT NOT NULL,
                FOREIGN KEY (MainPublicAddress) REFERENCES Balances(PublicAddress) ON DELETE CASCADE
            );
            """,
            f"""
            CREATE TABLE IF NOT EXISTS Transactions (
                TransactionID NUMERIC(32, 0) PRIMARY KEY,
                TransactionType transaction_type NOT NULL,
                PublicAddress CHAR({PUBLIC_KEY_LENGTH}) NOT NULL,
                Amount DECIMAL(20, {MAX_TRANSFER_PRECISION}) NOT NULL,
                ExpiryTime BIGINT NOT NULL,
                Status status NOT NULL,
                FOREIGN KEY (PublicAddress) REFERENCES Balances(PublicAddress) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS Ids (
                ID NUMERIC(32, 0) PRIMARY KEY,
                ExpiryTime BIGINT NOT NULL
            );
            """
        ]

        for query in table_queries:
            self.cur.execute(query)

        self.commit_transaction()

    def commit_transaction(self):
        """Commit the current transaction."""
        self.conn.commit()

    def rollback_transaction(self):
        """Rollback the current transaction."""
        self.conn.rollback()

    def insert_transaction(self, transaction_type: str, public_key: str, amount: Decimal, expiry_time: int):
        """
        Insert a new transaction into the database.

        Args:
            transaction_type (str): Type of transaction (SEND or RECEIVE).
            public_key (str): Public key of the user.
            amount (Decimal): Amount of the transaction.
            expiry_time (int): Expiry time of the transaction.

        Returns:
            Response: Response object indicating the success or failure of the transaction.
        """
        response = self.change_balance(public_key, -TRANSACTION_CREATION_FEE)
        if response.status_code != 200:
            return response
        self.change_balance(ADMIN_ADDRESS, TRANSACTION_CREATION_FEE)

        final_amount = str(Decimal(amount))

        sql = """
            INSERT INTO Transactions (TransactionID, TransactionType, PublicAddress, Amount, ExpiryTime, Status)
            VALUES (%s, %s, %s, %s, %s, %s);
        """

        for _ in range(0, 5):
            transaction_id = self.generate_transaction_id()

            try:
                self.cur.execute(sql, (transaction_id, transaction_type, public_key, final_amount, expiry_time, 'PENDING'))
                self.commit_transaction()
                self.change_balance(ADMIN_ADDRESS, TRANSACTION_CREATION_FEE)
                return Response(
                    message='success',
                    transaction_id=str(transaction_id),
                    transaction_amount=str(final_amount),
                    status_code=200
                )
            except psycopg2.IntegrityError:
                self.rollback_transaction()
        
        self.change_balance(public_key, TRANSACTION_CREATION_FEE)
        return Response(
            error_message='unknown_error',
            message='Unknown error occurred while creating transaction. You have not been charged.',
            status_code=500
        )

    def create_balance_item(self, public_key: str, amount: int = 0):
        """
        Create a new balance item in the database.

        Args:
            public_key (str): Public key of the user.
            amount (int): Initial balance amount.

        Returns:
            None
        """
        sql = """
            INSERT INTO Balances (PublicAddress, Balance)
            VALUES (%s, %s)
            ON CONFLICT (PublicAddress) DO NOTHING;
        """
        self.cur.execute(sql, (public_key, amount))
        self.commit_transaction()

    def transfer(self, sender_key: str, receiver_key: str, amount: Decimal):
        """
        Transfer funds from one user to another.

        Args:
            sender_key (str): Public key of the sender.
            receiver_key (str): Public key of the receiver.
            amount (Decimal): Amount to be transferred.

        Returns:
            Response: Response object indicating the success or failure of the transfer.
        """
        response = self.change_balance(sender_key, -amount)
        if response.status_code != 200:
            return response

        transfer_fee = round(amount * TRANSFER_FEE_PERCENT, 5)
        if transfer_fee < MINIMUM_TRANSFER_FEE:
            transfer_fee = MINIMUM_TRANSFER_FEE
        elif transfer_fee > MAXIMUM_TRANSFER_FEE:
            transfer_fee = MAXIMUM_TRANSFER_FEE
        
        transfer_amount = amount - transfer_fee
        


        self.change_balance(ADMIN_ADDRESS, transfer_fee)
        self.change_balance(receiver_key, transfer_amount)

        return Response(
            message='success',
            status_code=200
        )

    def add_id(self, request_id: int, expiry_time: int):
        """
        Add an ID to the database.

        Args:
            request_id (int): ID to be added.
            expiry_time (int): Expiry time of the ID.

        Returns:
            bool: True if the ID is added successfully, False otherwise.
        """
        try:
            insert_sql = """
                INSERT INTO Ids (ID, ExpiryTime)
                VALUES (%s, %s);
            """

            try:
                self.cur.execute(insert_sql, (request_id, expiry_time))
                self.commit_transaction()
                return True
            except psycopg2.IntegrityError:
                self.rollback_transaction()
                return False
        except Exception:
            self.cur.execute("ROLLBACK;")
            raise  # Handle other exceptions as needed

    def add_alias_address(self, alias: str, master_key: str, expiry_time: int):
        """
        Add an alias address to the database.

        Args:
            alias (str): Alias address.
            master_key (str): Main public address.
            expiry_time (int): Expiry time of the alias address.

        Returns:
            Response: Response object indicating the success or failure of adding the alias address.
        """
        response = self.change_balance(master_key, -ALIAS_ADDRESS_CREATION_FEE)
        if response.status_code != 200:
            return response

        insert_query = "INSERT INTO AliasAddresses (AliasAddress, MainPublicAddress, ExpiryTime) VALUES (%s, %s, %s)"
        data_to_insert = (alias, master_key, expiry_time)

        try:
            self.cur.execute(insert_query, data_to_insert)
            self.commit_transaction()
            self.change_balance(ADMIN_ADDRESS, ALIAS_ADDRESS_CREATION_FEE)
            return Response(
                message='success',
                status_code=200
            )
        except psycopg2.IntegrityError:
            self.rollback_transaction()
            self.change_balance(master_key, ALIAS_ADDRESS_CREATION_FEE)
            return Response(
                error_message='invalid_alias_address',
                message='Invalid alias address',
                status_code=400
            )

    def get_master_from_alias(self, alias):
        """
        Get the main public address from an alias.

        Args:
            alias (str): Alias address.

        Returns:
            Response: Response object containing the main public address.
        """
        select_query = """
            SELECT MainPublicAddress
            FROM AliasAddresses
            WHERE AliasAddress = %s
        """
        self.cur.execute(select_query, (alias,))
        master_key = self.cur.fetchone()

        if master_key is not None:
            return master_key[0]
        else:
            return alias

    def change_balance(self, key: str, amount: Decimal):
        """
        Change the balance of a user.

        Args:
            key (str): Public key of the user.
            amount (Decimal): Amount to be added or subtracted.

        Returns:
            Response: Response object indicating the success or failure of the balance change.
        """
        self.cur.execute("SELECT COUNT(*) FROM Balances WHERE PublicAddress = %s", (key,))
        count = self.cur.fetchone()[0]

        if (count == 0) and (amount < 0):
            self.rollback_transaction()
            return Response(
                error_message='insufficient_balance',
                message='Insufficient balance.',
                status_code=400
            )
        elif count == 0:
            self.create_balance_item(key)

        self.cur.execute("SELECT Balance FROM Balances WHERE PublicAddress = %s FOR UPDATE", (key,))
        if amount >= 0:
            sql = """
                UPDATE Balances
                SET Balance = Balance + %s
                WHERE PublicAddress = %s
            """
            self.cur.execute(sql, (str(amount), key))
            self.commit_transaction()
            return Response(
                message='success',
                status_code=200
            )
        else:
            current_balance = self.cur.fetchone()[0]

            if current_balance >= abs(amount):
                sql = """
                    UPDATE Balances
                    SET Balance = Balance - %s
                    WHERE PublicAddress = %s
                """
                self.cur.execute(sql, (str(abs(amount)), key))
                self.commit_transaction()
                return Response(
                    message='success',
                    status_code=200
                )
            else:
                self.rollback_transaction()
                return Response(
                    error_message='insufficient_balance',
                    message='Insufficient balance.',
                    status_code=400
                )

    def get_balance(self, key):
        """
        Get the balance of a user.

        Args:
            key (str): Public key of the user.

        Returns:
            Decimal: Balance of the user.
        """
        self.cur.execute("SELECT Balance FROM Balances WHERE PublicAddress = %s;", (key,))

        # Fetch the result (if any)
        result = self.cur.fetchone()

        if result is not None:
            balance = result[0]
        else:
            balance = Decimal(0)

        return balance

    def get_transaction(self, transaction_id):
        """
        Retrieves transaction information from the database based on the given transaction ID.

        Args:
            transaction_id (str): The ID of the transaction to retrieve.

        Returns:
            Response: Response object containing transaction information.
        """
        def get_result():
            # Fetch transaction details from the database
            self.cur.execute(
                "SELECT TransactionType, Amount, ExpiryTime, Status FROM Transactions WHERE TransactionID = %s;",
                (transaction_id,)
            )
            result = self.cur.fetchone()
            return result

        while True:
            result = get_result()
            if result is not None:
                status = result[3]
                if status == 'PROCESSING':
                    continue

                expiry_time = int(result[2])

                if (status == 'PENDING') and (expiry_time < time.time()):
                    status = 'EXPIRED'
                    if expiry_time + DELETION_DELAY_AFTER_EXPIRY < time.time():
                        self.cur.execute('DELETE FROM Transactions WHERE TransactionID = %s;', (transaction_id,))
                    else:
                        self.cur.execute("UPDATE Transactions SET Status = %s WHERE TransactionID = %s;",
                                         (status, transaction_id))
                    self.commit_transaction()

                return Response(
                    message='success',
                    transaction_type=result[0],
                    transaction_amount=str(result[1]),
                    expiry_time=str(expiry_time),
                    status=status,
                    status_code=200
                )
            else:
                return Response(
                    error_message='transaction_not_found',
                    message='Transaction not found.',
                    status_code=400
                )

    def get_transaction_owner(self, transaction_id):
        """
        Retrieves the public address of the transaction owner from the database based on the given transaction ID.

        Args:
            transaction_id (str): The ID of the transaction.

        Returns:
            Response: Response object containing the public address of the transaction owner.
        """
        self.cur.execute("SELECT PublicAddress FROM Transactions WHERE TransactionID = %s;", (transaction_id,))

        # Fetch the result (if any)
        result = self.cur.fetchone()

        if result is not None:
            return Response(
                message='success',
                public_key=result[0],
                status_code=200
            )
        else:
            return Response(
                error_message='transaction_not_found',
                message='Transaction not found.',
                status_code=400
            )

    def delete_transaction(self, transaction_id):
        """
        Deletes a transaction from the database based on the given transaction ID.

        Args:
            transaction_id (str): The ID of the transaction to be deleted.

        Returns:
            Response: Response object indicating the success of the deletion.
        """
        self.cur.execute("DELETE FROM Transactions WHERE TransactionID = %s;", (transaction_id,))
        self.commit_transaction()
        return Response(
            message='success',
            status_code=200
        )

    def complete_transaction(self, transaction_id, master_key):
        """
        Completes a transaction in the database, updating its status and performing necessary balance changes.

        Args:
            transaction_id (str): The ID of the transaction to be completed.
            master_key (str): The public address of the master key.

        Returns:
            Response: Response object indicating the success of the transaction completion.
        """

        def set_transaction_status(status):
            # Set the transaction status in the database
            self.cur.execute(
                "SELECT PublicAddress, TransactionType, Amount, ExpiryTime, Status FROM Transactions WHERE TransactionID = %s FOR UPDATE;",
                (transaction_id,)
            )
            result = self.cur.fetchone()

            if result is not None:
                self.cur.execute("UPDATE Transactions SET Status = %s WHERE TransactionID = %s;",
                                 (status, transaction_id))
                self.commit_transaction()
            else:
                self.rollback_transaction()

        self.cur.execute(
            "SELECT PublicAddress, TransactionType, Amount, ExpiryTime, Status FROM Transactions WHERE TransactionID = %s FOR UPDATE;",
            (transaction_id,)
        )

        # Fetch the result (if any)
        result = self.cur.fetchone()

        if result is not None:
            expiry_time = int(result[3])
            status = result[4]

            if status == 'COMPLETED':
                self.rollback_transaction()
                return Response(
                    error_message='transaction_completed',
                    message='Transaction is already completed.',
                    status_code=400
                )
            elif (status == 'EXPIRED') or (expiry_time < time.time()):
                self.rollback_transaction()
                return Response(
                    error_message='transaction_expired',
                    message='Transaction has expired.',
                    status_code=400
                )
            else:
                public_key = result[0]
                transaction_type = result[1]
                amount = Decimal(result[2])

                self.cur.execute("UPDATE Transactions SET Status = %s WHERE TransactionID = %s;",
                                 ('PROCESSING', transaction_id))

                self.commit_transaction()

                if transaction_type == 'SEND':
                    sending_key = public_key
                    receiving_key = master_key
                else:
                    sending_key = master_key
                    receiving_key = public_key

                response = self.change_balance(sending_key, -amount)

                if response.status_code != 200:
                    set_transaction_status('PENDING')
                    return response

                transaction_fee = amount * TRANSFER_FEE_PERCENT
                transfer_fee = round(amount * TRANSFER_FEE_PERCENT, 5)
                if transfer_fee < MINIMUM_TRANSFER_FEE:
                    transfer_fee = MINIMUM_TRANSFER_FEE
                elif transfer_fee > MAXIMUM_TRANSFER_FEE:
                    transfer_fee = MAXIMUM_TRANSFER_FEE
                
                transfer_amount = amount - transaction_fee

                self.change_balance(ADMIN_ADDRESS, transaction_fee)
                self.change_balance(receiving_key, transfer_amount)

                set_transaction_status('COMPLETED')

                return Response(
                    message='success',
                    status_code=200
                )
        else:
            self.rollback_transaction()
            return Response(
                error_message='transaction_not_found',
                message='Transaction not found.',
                status_code=400
            )

    def delete_alias_address(self, alias_address):
        """
        Deletes an alias address from the database based on the given alias address.

        Args:
            alias_address (str): The alias address to be deleted.

        Returns:
            Response: Response object indicating the success of the deletion.
        """
        select_query = """
            SELECT 1
            FROM AliasAddresses
            WHERE AliasAddress = %s;
        """
        self.cur.execute(select_query, (alias_address,))
        row_exists = self.cur.fetchone()

        if row_exists:
            delete_query = """
            DELETE FROM AliasAddresses
            WHERE AliasAddress = %s;
            """

            self.cur.execute(delete_query, (alias_address,))
            self.commit_transaction()

            response = Response(
                message='success',
                status_code=200
            )
        else:
            self.rollback_transaction()
            response = Response(
                error_message='alias_address_not_found',
                message='Alias address not found.',
                status_code=400
            )

        return response

    def delete_old_transactions(self):
        """
        Deletes old transactions from the database based on the expiry time and deletion delay.

        Returns:
            None
        """
        delete_query = """
        DELETE FROM Transactions
        WHERE ExpiryTime < %s;
        """

        cutoff_time = math.ceil(time.time()) - DELETION_DELAY_AFTER_EXPIRY

        self.cur.execute(delete_query, (cutoff_time,))
        self.commit_transaction()

    def delete_old_ids(self):
        """
        Deletes old IDs from the database based on the expiry time.

        Returns:
            None
        """
        delete_query = """
        DELETE FROM Ids
        WHERE ExpiryTime < %s;
        """

        cutoff_time = math.ceil(time.time())

        self.cur.execute(delete_query, (cutoff_time,))
        self.commit_transaction()

    def delete_old_alias_addresses(self):
        """
        Deletes old alias addresses from the database based on the expiry time.

        Returns:
            None
        """
        delete_query = """
        DELETE FROM AliasAddresses
        WHERE ExpiryTime < %s;
        """

        cutoff_time = math.ceil(time.time())

        self.cur.execute(delete_query, (cutoff_time,))
        self.commit_transaction()

    def number_of_transactions(self, master_key):
        """
        Returns the number of transactions associated with a wallet.

        Returns:
            int: The number of transactions associated with a specific wallet.
        """
        self.cur.execute("SELECT COUNT(*) FROM Transactions WHERE PublicAddress = ?", (master_key,))
        result = self.cur.fetchone()
        return result[0]

    def sum_of_send_transactions(self, master_key):
        """
        Returns the sum of all send transactions.

        Returns:
            Decimal: The sum of all send transactions.
        """
        ## Technique: Aggregate SQL Function
        self.cur.execute("SELECT COALESCE(SUM(Amount), 0) FROM Transactions WHERE PublicAddress = ? AND TransactionType = 'SEND'", (master_key,))
        result = self.cur.fetchone()
        return result[0]

    def sum_of_receive_transactions(self, master_key):
        """
        Returns the sum of all receive transactions.

        Returns:
            Decimal: The sum of all receive transactions.
        """
        ## Technique: Aggregate SQL Function
        self.cur.execute("SELECT COALESCE(SUM(Amount), 0) FROM Transactions WHERE PublicAddress = ? AND TransactionType = 'RECEIVE'", (master_key,))
        result = self.cur.fetchone()
        return result[0]

    def average_transaction_value(self):
        """
        Returns the average transaction value.

        Returns:
            Decimal: The average transaction value.
        """
        ## Technique: Aggregate SQL Function
        self.cur.execute("SELECT COALESCE(AVG(Amount), 0) FROM Transactions")
        result = self.cur.fetchone()
        return result[0]
    
    def get_sum_of_balances(self):
        """
        Returns the sum of all balances.

        Returns:
            Decimal: The sum of all balances.
        """
        ## Technique: Aggregate SQL Function
        self.cur.execute("SELECT COALESCE(SUM(Balance), 0) FROM Balances")
        result = self.cur.fetchone()
        return result[0]

    def wallet_info(self, master_key):
        """
        Returns the wallet information for a given master key.

        Returns:
            dict: The wallet information for the given master key.
        """
        ## Technique: Cross table parameterised SQL
        query = """
            SELECT
                B.Balance,
                COUNT(T.TransactionID) AS num_transactions,
                ARRAY_AGG(T.* ORDER BY T.TransactionID) AS transactions,
                COUNT(AA.AliasAddress) AS num_aliases,
                ARRAY_AGG(AA.AliasAddress ORDER BY AA.AliasAddress) AS alias_addresses
            FROM
                Balances B
            LEFT JOIN
                Transactions T ON B.PublicAddress = T.PublicAddress
            LEFT JOIN
                AliasAddresses AA ON B.PublicAddress = AA.MainPublicAddress
            WHERE
                B.PublicAddress = %s
            GROUP BY
                B.Balance
        """

        self.cur.execute(query, (master_key,))
        result = self.cur.fetchone()
        if result:
            wallet_info = {
                'balance': result[0],
                'num_transactions': result[1],
                'transactions': result[2],
                'num_aliases': result[3],
                'alias_addresses': result[4],
            }
            return wallet_info
        else:
            return None
    

    def close(self):
        """
        Closes the database connection and cursor.

        Returns:
            None
        """
        self.cur.close()
        self.conn.close()

    @staticmethod
    def generate_transaction_id():
        """
        Generates a unique transaction ID based on the current time and a random number.

        Returns:
            str: The generated transaction ID.
        """
        random_number = random.randrange(10 ** 19, 10 ** 20)
        current_time = time.time()
        transaction_id = f"{current_time * 10**7:.0f}"[5:] + str(random_number)

        return transaction_id
