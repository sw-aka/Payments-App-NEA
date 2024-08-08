from database import ConnectionPool, DatabaseConnector
from response import Response

class DatabaseHandler:
    """
    A class for handling database operations.
    """

    def __init__(self, connection_pool: ConnectionPool):
        """
        Initialize the DatabaseHandler with a connection pool.

        Args:
        - connection_pool (ConnectionPool): The connection pool for database connections.
        """
        self.connection_pool = connection_pool

    def add_id(self, transaction_id: int, expiry_time: int) -> Response:
        """
        Add an ID to the database.

        Args:
        - transaction_id (int): The transaction ID to be added.
        - expiry_time (int): The expiry time for the transaction ID.

        Returns:
        - Response: The response object with the result of the operation.
        """
        # Creating a DatabaseConnector instance using a connection from the pool
        db_conn = DatabaseConnector(self.connection_pool.get_conn())

        # Adding the ID to the database using the DatabaseConnector
        response = db_conn.add_id(transaction_id, expiry_time)

        # Closing the database connection
        db_conn.close()

        # Returning the connection to the connection pool
        self.connection_pool.putconn(db_conn.conn)

        # Checking the response and creating a corresponding Response object
        if response:
            response = Response(
                message='success',
                status_code=200
            )
        else:
            response = Response(
                error_message='invalid_id',
                message='Id has expired',
                status_code=400
            )

        return response
