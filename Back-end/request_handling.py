import ast
import json
from decimal import Decimal
from flask import Request

from database import ConnectionPool, DatabaseConnector
from database_operations import DatabaseHandler
from request_verification import RequestData, VerifyRequest
from response import Response
from encryption import Encryption


class TransferRequest(VerifyRequest):
    """
    Handles transfer requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the transfer request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'transfer_amount',
                      'sender_key',
                      'recipient_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'request_expiry_time',
                          'transfer_amount',
                          'sender_key',
                          'recipient_key'],
            verifying_key_name='sender_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.transfer()

    def transfer(self):
        # Extract data from the request
        data = self.request.data
        amount_decimal = Decimal(data['transfer_amount'])

        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        # Get master keys for sender and recipient
        sender_master_key = db_conn.get_master_from_alias(data['sender_key'])
        recipient_master_key = db_conn.get_master_from_alias(data['recipient_key'])

        # Perform the transfer
        response = db_conn.transfer(sender_master_key, recipient_master_key, amount_decimal)

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response


class DeleteTransactionRequest(VerifyRequest):
    """
    Handles delete transaction requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the delete transaction request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'transaction_id',
                      'master_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'request_expiry_time',
                          'transaction_id',
                          'master_key'],
            verifying_key_name='master_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.delete_transaction()

    def delete_transaction(self):
        # Extract data from the request
        data = self.request.data
        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        # Get transaction owner
        response = db_conn.get_transaction_owner(data['transaction_id'])

        if response.public_key == data['master_key']:
            response = db_conn.delete_transaction(data['transaction_id'])
        else:
            response = Response(
                error_message='invalid_transaction_id',
                message='Invalid transaction id.',
                status_code=400
            )

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response


class GetTransactionsRequest(VerifyRequest):
    """
    Handles get transactions requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the get transactions request
        self.response = self.verify_request(
            required=['transaction_ids',
                      'encryption_key']
        )
        if self.response.status_code == 200:
            self.response = self.get_transactions()

    def get_transactions(self):
        # Extract data from the request
        transaction_ids = ast.literal_eval(self.request.data['transaction_ids'])
        transaction_ids = list(map(str, transaction_ids))

        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        transactions = {}

        # Retrieve transaction details for each transaction ID
        for transaction_id in transaction_ids:
            response = db_conn.get_transaction(transaction_id)
            if response.status_code == 200:
                transactions[transaction_id] = json.dumps({
                    'transaction_type': response.transaction_type,
                    'transaction_amount': response.transaction_amount,
                    'expiry_time': response.expiry_time,
                    'status': response.status
                })

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return Response(
            message='success',
            transactions=json.dumps(transactions),
            status_code=200
        )


class CreateTransactionRequest(VerifyRequest):
    """
    Handles create transaction requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the create transaction request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'transaction_expiry_time',
                      'transaction_amount',
                      'transaction_type',
                      'master_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'request_expiry_time',
                          'transaction_expiry_time',
                          'transaction_amount',
                          'transaction_type',
                          'master_key'],
            verifying_key_name='master_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.create_transaction()

    def create_transaction(self):
        # Extract data from the request
        data = self.request.data
        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        response = db_conn.insert_transaction(transaction_type=data['transaction_type'],
                                               public_key=data['master_key'],
                                               amount=Decimal(data['transaction_amount']),
                                               expiry_time=int(data['transaction_expiry_time']))

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response


class CompleteTransactionRequest(VerifyRequest):
    """
    Handles complete transaction requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the complete transaction request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'transaction_id',
                      'master_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'request_expiry_time',
                          'transaction_id',
                          'master_key'],
            verifying_key_name='master_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.complete_transaction()

    def complete_transaction(self):
        # Extract data from the request
        data = self.request.data
        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        response = db_conn.complete_transaction(transaction_id=data['transaction_id'],
                                                master_key=data['master_key'])

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response


class AddAliasRequest(VerifyRequest):
    """
    Handles add alias requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the add alias request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'alias_expiry_time',
                      'alias_address',
                      'master_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'request_expiry_time',
                          'alias_expiry_time',
                          'alias_address',
                          'master_key'],
            verifying_key_name='master_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.add_alias()

    def add_alias(self):
        # Extract data from the request
        data = self.request.data

        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        response = db_conn.add_alias_address(data['alias_address'],
                                             data['master_key'],
                                             int(data['alias_expiry_time']))
        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response


class DeleteAliasRequest(VerifyRequest):
    """
    Handles delete alias requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the delete alias request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'alias_address',
                      'master_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'alias_address',
                          'master_key',
                          'request_expiry_time'],
            verifying_key_name='master_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.delete_alias()

    def delete_alias(self):
        # Extract data from the request
        data = self.request.data

        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        alias_owner = db_conn.get_master_from_alias(data['alias_address'])

        # Delete alias if the owner matches
        if alias_owner == data['master_key']:
            response = db_conn.delete_alias_address(data['alias_address'])
        else:
            response = Response(
                error_message='alias_does_not_exist',
                message='Alias address does not exist.',
                status_code=400
            )

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response


class GetBalanceRequest(VerifyRequest):
    """
    Handles get balance requests.
    
    Args:
        request (Request): The Flask request object.
        encryption (Encryption): An instance of the Encryption class.
        connection_pool (ConnectionPool): Connection pool for database connections.

    Returns:
        Response: The response object.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool):
        super().__init__(request, encryption, connection_pool)

        self.request: RequestData = None

        # Verify and process the get balance request
        self.response = self.verify_request(
            required=['request_id',
                      'request_expiry_time',
                      'master_key',
                      'signature',
                      'encryption_key'],
            message_vars=['request_id',
                          'request_expiry_time',
                          'master_key'],
            verifying_key_name='master_key'
        )
        if self.response.status_code == 200:
            self.response = DatabaseHandler(self.connection_pool).add_id(self.request.data['request_id'],
                                   self.request.data['request_expiry_time'])
            if self.response.status_code == 200:
                self.response = self.get_balance()

    def get_balance(self):
        # Extract data from the request
        data = self.request.data

        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        # Get the balance for the master key
        balance = db_conn.get_balance(data['master_key'])
        response = Response(
            message='success',
            balance=str(balance),
            status_code=200
        )

        db_conn.close()
        self.connection_pool.putconn(db_conn.conn)

        return response
