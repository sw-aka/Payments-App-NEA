import time  # Importing the time module for handling time-related operations
import logging  # Importing the logging module for logging functionality
import threading  # Importing threading for concurrent execution
from flask import Flask  # Importing Flask for creating a web application

from api_blueprint import app_api_blueprint  # Importing the blueprint_app from api_blueprint
from database import DatabaseCreator, ConnectionPool, DatabaseConnector  # Importing database-related modules
from encryption import Encryption  # Importing Encryption class for handling encryption operations

# Initializing a flag to control the deletion of rows
delete_rows = True

# Creating a Flask web application instance
app = Flask(__name__)

# Registering the blueprint_app with the Flask app
app.register_blueprint(app_api_blueprint)


def delete_expired_rows(connection_pool: ConnectionPool):
    """
    Function to delete expired rows at regular intervals.

    Args:
        connection_pool (ConnectionPool): The connection pool to manage database connections.

    Returns:
        None
    """
    while delete_rows:
        # Creating a DatabaseConnector instance using a connection from the pool
        db_conn = DatabaseConnector(connection_pool.get_conn())
        # Deleting old IDs, transactions, and alias addresses from the database
        db_conn.delete_old_ids()
        db_conn.delete_old_transactions()
        db_conn.delete_old_alias_addresses()
        # Closing the database connection
        db_conn.close()
        # Returning the connection to the pool for reuse
        connection_pool.putconn(db_conn.conn)
        # Sleeping for 10 seconds before the next iteration
        time.sleep(10)


if __name__ == "__main__":
    # Configuring logging settings
    logging.basicConfig(filename='my_app.log', level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

    # Creating a DatabaseCreator instance for the 'currency' database
    db_creator = DatabaseCreator("currency")
    # Creating the 'currency' database if it doesn't exist
    db_creator.create_database_if_not_exists()

    # Creating a ConnectionPool instance for managing database connections
    connection_pool = ConnectionPool('currency', 'postgres', 'password', 'localhost', '5432', 10, 50)

    # Creating a DatabaseConnector instance using a connection from the pool
    db_conn = DatabaseConnector(connection_pool.get_conn())
    # Creating necessary tables if they don't exist
    db_conn.create_tables_if_not_exist()
    # Closing the database connection
    db_conn.close()
    # Returning the connection to the pool for reuse
    connection_pool.putconn(db_conn.conn)

    # Creating a thread for the delete_expired_rows function
    thread = threading.Thread(target=delete_expired_rows, args=(connection_pool,))
    # Starting the thread for periodic deletion of expired rows
    thread.start()

    # Setting up Flask app configurations
    app.config['connection_pool'] = connection_pool
    app.config['encryption'] = Encryption()

    # Running the Flask app in debug mode
    app.run(debug=True)

    # Updating the flag to stop the deletion of rows
    delete_rows = False
    # Waiting for the delete_expired_rows thread to finish
    thread.join()
