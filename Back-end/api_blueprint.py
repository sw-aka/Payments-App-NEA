from flask import request, Blueprint, current_app, jsonify
from encryption import Encryption
from request_handling import (TransferRequest, GetTransactionsRequest, CreateTransactionRequest,
                              DeleteTransactionRequest, AddAliasRequest, DeleteAliasRequest,
                              GetBalanceRequest, CompleteTransactionRequest)

# Create a Flask Blueprint
app_api_blueprint = Blueprint('app_api', __name__)

# Define route to process transfer request
@app_api_blueprint.route('/api/transfer', methods=['POST'])
def process_transfer_request():
    """
    Process the transfer request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = TransferRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process create transaction request
@app_api_blueprint.route('/api/create-transaction', methods=['POST'])
def process_create_transaction_request():
    """
    Process the create transaction request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = CreateTransactionRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process get transactions request
@app_api_blueprint.route('/api/get-transactions', methods=['POST'])
def process_get_transaction_request():
    """
    Process the get transactions request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = GetTransactionsRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process delete transaction request
@app_api_blueprint.route('/api/delete-transaction', methods=['POST'])
def process_delete_transaction_request():
    """
    Process the delete transaction request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = DeleteTransactionRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process complete transaction request
@app_api_blueprint.route('/api/complete-transaction', methods=['POST'])
def process_complete_transaction_request():
    """
    Process the complete transaction request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = CompleteTransactionRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process add alias request
@app_api_blueprint.route('/api/add-alias', methods=['POST'])
def process_add_alias_request():
    """
    Process the add alias request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = AddAliasRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process delete alias request
@app_api_blueprint.route('/api/delete-alias', methods=['POST'])
def process_delete_alias_request():
    """
    Process the delete alias request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = DeleteAliasRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process get balance request
@app_api_blueprint.route('/api/get-balance', methods=['POST'])
def process_get_balance_request():
    """
    Process the get balance request and return an encrypted response.

    Args:
        request: Flask request object.
        encryption: Encryption instance.
        connection_pool: Connection pool instance.

    Returns:
        Response: Encrypted response.
    """
    connection_pool = current_app.config['connection_pool']
    encryption = current_app.config['encryption']
    transfer_request = GetBalanceRequest(request, encryption, connection_pool)
    return encryption.get_encrypted_response(transfer_request.response, transfer_request.encryption_key)

# Define route to process get key request
@app_api_blueprint.route('/api/get-key', methods=['GET'])
def process_get_key_request():
    """
    Process the get key request and return the public key.

    Args:
        encryption: Encryption instance.

    Returns:
        Response: JSON response containing the public key.
    """
    encryption: Encryption = current_app.config['encryption']
    return jsonify({'key': encryption.get_public_key()})
