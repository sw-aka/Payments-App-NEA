import time
import re
import ast
import json
import base64
import string
from decimal import Decimal, InvalidOperation
from flask import Request
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.exceptions import InvalidSignature
from response import Response
from tools import CustomList
from config import TransactionConfig, TransferLimits
from database import ConnectionPool
from encryption import Encryption

MAX_REQUEST_EXPIRY_TIME = TransactionConfig.MAX_REQUEST_EXPIRY_TIME
MAX_TRANSACTION_EXPIRY_TIME = TransactionConfig.MAX_TRANSACTION_EXPIRY_TIME
MAX_ALIAS_EXPIRY_TIME = TransactionConfig.MAX_ALIAS_EXPIRY_TIME
MAX_TRANSFER_PRECISION = TransferLimits.MAX_TRANSFER_PRECISION
MAX_TRANSFER_AMOUNT = TransferLimits.MAX_TRANSFER_AMOUNT
MIN_TRANSFER_AMOUNT = TransferLimits.MIN_TRANSFER_AMOUNT
MAX_REQUEST_SIZE = TransactionConfig.MAX_REQUEST_SIZE

class RequestData:
    """
    Class representing request data and providing methods for verification.
    """

    ID_LENGTH = 32
    PUBLIC_KEY_LENGTH = 44
    SIGNATURE_LENGTH = 88
    ALLOWED_TRANSACTION_TYPES = ['SEND', 'RECEIVE']

    @staticmethod
    def is_valid_decimal(number: str):
        """Check if a string represents a valid decimal number."""
        try:
            Decimal(number)
            return True
        except InvalidOperation:
            return False
    
    @staticmethod
    def count_decimal_digits(value: str):
        """Count the decimal digits in a string."""
        match = re.match(r"^(\d*\.\d*?)0*$", value)
        if match:
            return len(match.group(1).split('.')[1])
        else:
            return 0
        
    @staticmethod
    def is_list(string: str):
        """Check if a string represents a valid list."""
        try:
            ast.literal_eval(string)
            return True
        except SyntaxError:
            return False
    
    @staticmethod
    def is_hex(string: str):
        """Check if a string represents a valid hexadecimal number."""
        if all(c.isdigit() or c.lower() in 'abcdef' for c in string):
            return True
        else:
            return False
    
    @staticmethod
    def is_base64(s):
        """Check if a string represents a valid base64 encoded string."""
        try:
            # Attempt to decode the string
            base64.b64decode(s, validate=True)
            
            # If decoding succeeds, it's a valid Base64 string
            return True
        except base64.binascii.Error:
            # If decoding fails, it's not a valid Base64 string
            return False
    
    def __init__(self, data: dict):
        """Initialize RequestData object with the given data."""
        data = {key: str(value) for key, value in data.items()}
        self.data = data
    
    def verify_id_syntax(self, var_name: str, var: str):
        """Verify syntax of an ID."""
        request_id = var

        if not request_id.isdigit():
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} must be an integer.',
                status_code=400
            )  
        elif len(request_id) != self.ID_LENGTH:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} length is incorrect. It should be exactly {self.ID_LENGTH} characters.',
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                status_code=200
            )
        
        return response
    
    def verify_transaction_ids_syntax(self, var_name: str, var: str):
        """Verify syntax of transaction IDs."""
        if not RequestData.is_list(var):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} must be a list.',
                status_code=400
            )
        else:        
            ids = ast.literal_eval(var)
            ids = list(map(str, ids))
            
            if len(ids) == 0:
                response = Response(
                    error_message=f'invalid_{var_name}',
                    message='Transaction id list is empty.',
                    status_code=400
                )
            else:
                for transaction_id in ids:
                    response = self.verify_id_syntax(var_name, transaction_id)
                    if response.status_code != 200:
                        response.error_message = f'invalid_{var_name}'
                        break
                else:
                    response =  Response(
                        message='valid',
                        status_code=200
                    )
        
        return response
    
    def verify_public_key_syntax(self, var_name: str, var: str):
        """Verify syntax of a public key."""
        public_key = var


        if len(public_key) != self.PUBLIC_KEY_LENGTH:
            response =Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} length is incorrect. It should be exactly {self.PUBLIC_KEY_LENGTH} characters.',
                status_code=400
            )
        elif not RequestData.is_base64(public_key):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} contains invalid characters. It should only contain base64 digits.',
                status_code=400
            )
        elif not len(base64.b64decode(public_key)) == 32:
            response =Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} length is incorrect. It should be exactly 32 bytes.',
                status_code=400
            )
        else:
            response =  Response(
                message='valid',
                status_code=200
            )
        
        return response
    
    def verify_expiry_time(self, var_name: str, var: str, max_expiry_time: int):
        """Verify syntax of an expiry time."""
        expiry_time = var

        if not expiry_time.isdigit():
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} must be an integer.',
                status_code=400
            )
        elif int(expiry_time) <= time.time():
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} must be in the future.',
                status_code=400
            )
        elif int(expiry_time) > time.time() + max_expiry_time:
            response = Response(
                error_message=f'invalid_{var_name}',
                message=f'{var_name} is too far in the future. Maximum of {max_expiry_time} seconds.',
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                status_code=200
            )
        
        return response
    
    def verify_request_expiry_time(self, var_name: str, var: str):
        """Verify syntax of request expiry time."""
        return self.verify_expiry_time(var_name, var, MAX_REQUEST_EXPIRY_TIME)    

    def verify_alias_expiry_time(self, var_name: str, var: str):
        """Verify syntax of alias expiry time."""
        return self.verify_expiry_time(var_name, var, MAX_ALIAS_EXPIRY_TIME)

    def verify_transaction_expiry_time(self, var_name: str, var: str):
        """Verify syntax of transaction expiry time."""
        return self.verify_expiry_time(var_name, var, MAX_TRANSACTION_EXPIRY_TIME)

    def verify_amount(self, var_name: str, var: str):
        """Verify syntax of an amount."""
        amount = var

        if not RequestData.is_valid_decimal(amount):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} must be a valid decimal.',
                status_code=400
            )
        elif RequestData.count_decimal_digits(amount) > MAX_TRANSFER_PRECISION:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} has too many decimal places. Max is {MAX_TRANSFER_PRECISION}.',
                status_code=400
            )
        elif Decimal(amount) > MAX_TRANSFER_AMOUNT:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} is too large. Max is {MAX_TRANSFER_AMOUNT}.',
                status_code=400
            )
        elif Decimal(amount) < MIN_TRANSFER_AMOUNT:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} is too small. Min is {MIN_TRANSFER_AMOUNT}.',
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                status_code=200
            )
        
        return response
    
    def verify_signature_syntax(self, var_name: str, var: str):
        """Verify syntax of a signature."""
        signature = var

        if len(signature) != self.SIGNATURE_LENGTH:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} length is incorrect. It should be exactly {self.SIGNATURE_LENGTH} characters.',
                status_code=400
            )
        elif not RequestData.is_base64(signature):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} contains invalid characters. It should only contain base64 digits.',
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                status_code=200
            )
        
        return response
    
    def verify_transaction_type(self, var_name: str, var: str):
        """Verify syntax of a transaction type."""
        if var not in self.ALLOWED_TRANSACTION_TYPES:
            response = Response(
                error_message=f'invalid_{var_name}', 
                message= f'{var_name} must be one of the following: {self.ALLOWED_TRANSACTION_TYPES}', 
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                status_code=200
            )
        
        return response

    def verify_signature(self, verifying_key_name: str, message_vars: list) -> Response:
        """Verify a signature."""
        public_key_b64 = self.data[verifying_key_name]
        signature_b64 = self.data['signature']

        message_vars = CustomList(message_vars)
        message_vars_sorted = message_vars.merge_sort()
        
        message_dict = {}
        for var_name in message_vars_sorted:
            message_dict[var_name] = self.data[var_name]
        
        message = json.dumps(message_dict, separators=(',', ':')).encode('utf-8')

        public_key_bytes = base64.b64decode(public_key_b64)
        signature = base64.b64decode(signature_b64)
        public_key = ed25519.Ed25519PublicKey.from_public_bytes(public_key_bytes)

        try:
            public_key.verify(signature, message)
            response = Response(
                message='valid',
                status_code=200
            )
        except InvalidSignature:
            response = Response(
                error_message='invalid_signature',
                message= 'Invalid signature',
                status_code=400
            )
        
        return response

    def verify_encrypted_data_syntax(self, var_name: str, var: str):
        """Verify syntax of encrypted data."""
        encrypted_data = var

        if not RequestData.is_base64(encrypted_data):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} contains invalid characters. It should only contain base64 characters.',
                status_code=400
            )
        elif len(encrypted_data) % 344 != 0:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} length is incorrect. It should be a multiple of 344.',
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                status_code=200
            )
        
        return response

    def verify_encryption_key(self, var_name: str, var: str):
        """Verify syntax of an encryption key."""
        encryption_key = var

        if not RequestData.is_base64(encryption_key):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} contains invalid characters. It should only contain base64 characters.',
                status_code=400
            )
        elif len(encryption_key) != 392:
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} length is incorrect. It should be a 392 characters long.',
                status_code=400
            )
        elif not RequestData.valid_rsa_public_key(encryption_key):
            response = Response(
                error_message=f'invalid_{var_name}',
                message= f'{var_name} is not a valid RSA public key.',
                status_code=400
            )
        else:
            response = Response(
                message='valid',
                encryption_key=encryption_key,
                status_code=200
            )
        
        return response
    
    @staticmethod
    def valid_rsa_public_key(public_key: str) -> bool:
        """Check if a string represents a valid RSA public key."""
        serialized_public_key = base64.b64decode(public_key)
        try:
            serialization.load_der_public_key(
                serialized_public_key,
                backend=default_backend()
            )
            return True
        except ValueError:
            return False

    def verify(self, required: list) -> Response:
        """Verify the request data against the required keys."""
        
        data_keys = list(self.data.keys())
        
        missing_keys = [key for key in required if key not in data_keys]
        if missing_keys:
            response = Response(
                error_message='missing_keys',
                message=f'Missing {", ".join(missing_keys)} in JSON data',
                status_code=400
            )
        else:
            verification_functions = {
                'request_id' : self.verify_id_syntax,
                'transaction_id' : self.verify_id_syntax,
                'transaction_ids' : self.verify_transaction_ids_syntax,
                'alias_address' : self.verify_public_key_syntax,
                'master_key' : self.verify_public_key_syntax,
                'request_expiry_time' : self.verify_request_expiry_time,
                'alias_expiry_time' : self.verify_alias_expiry_time,
                'transaction_expiry_time' : self.verify_transaction_expiry_time,
                'transaction_amount' : self.verify_amount,
                'transfer_amount' : self.verify_amount,
                'signature' : self.verify_signature_syntax,
                'transaction_type' : self.verify_transaction_type,
                'sender_key' : self.verify_public_key_syntax,
                'recipient_key' : self.verify_public_key_syntax,
                'data' : self.verify_encrypted_data_syntax,
                'encryption_key' : self.verify_encryption_key

            }
            
            encryption_key = None
            for key in required:
                response = verification_functions[key](var_name=key, var=self.data[key])
                if response.encryption_key is not None:
                    encryption_key = response.encryption_key
                if response.status_code != 200:
                    break
            else:
                response = Response(
                    message='valid',
                    encryption_key=encryption_key,
                    status_code=200
                )
        
        return response

class VerifyRequest:
    """
    Class to handle the verification of incoming requests.
    """

    def __init__(self, request: Request, encryption: Encryption, connection_pool: ConnectionPool) -> None:
        """
        Initialize the VerifyRequest instance.

        Args:
            request (Request): The incoming request object.
            encryption (Encryption): The encryption object.
            connection_pool (ConnectionPool): The connection pool object.
        """
        self.request = request
        self.connection_pool = connection_pool
        self.data = None
        self.response = None
        self.encryption_key = None
        self.encryption = encryption

        self.verify_encrypted_data()

    def verify_encrypted_data(self):
        """
        Verify the encrypted data in the incoming request.
        """
        # Get the content length from the request headers
        content_length = int(self.request.headers.get('Content-Length'))

        # Check if the content length exceeds the maximum allowed size
        if content_length > MAX_REQUEST_SIZE:
            self.response = Response(
                error_message='request_too_large',
                message=f'Request size is too large. Maximum is {MAX_REQUEST_SIZE} bytes.',
                status_code=413
            )
            return
        else:
            # Extract encrypted data from the request
            encrypted_data = self.request.data

            # Decrypt the encrypted data
            response = self.encryption.decrypt_message(encrypted_data)

            # Check the status code of the decryption response
            if response.status_code != 200:
                self.response = response
                return

            # Try to load the decrypted data as JSON
            try:
                self.data = json.loads(response.message)
            except json.JSONDecodeError:
                self.response = Response(
                    error_message='invalid_json',
                    message='Invalid JSON data in encrypted data.',
                    status_code=400
                )
                return

    def verify_request(self, required: list, message_vars: list = None, verifying_key_name: str = None):
        """
        Verify the incoming request.

        Args:
            required (List): List of required elements in the request.
            message_vars (List): List of message variables for signature verification.
            verifying_key_name (str): Name of the verifying key.

        Returns:
            Response: The response object indicating the result of the verification.
        """
        if self.response is not None:
            return self.response

        # Create a RequestData instance using the decrypted data
        self.request = RequestData(self.data)

        # Verify the required elements in the request
        response = self.request.verify(required)
        self.encryption_key = response.encryption_key

        # Check the status code of the verification response
        if response.status_code != 200:
            return response

        # Verify the signature if message variables are provided
        if message_vars is not None:
            response = self.request.verify_signature(verifying_key_name, message_vars)

            # Check the status code of the signature verification response
            if response.status_code != 200:
                return response

        # Return a valid response if all verifications pass
        return Response(
            message='valid',
            status_code=200
        )
