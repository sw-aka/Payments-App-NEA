import json

class Response:
    """
    Represents a response object with various attributes.

    Args:
        message (str): The main message in the response.
        status_code (int): The HTTP status code of the response.
        error_message (str, optional): An optional error message.
        transfer_amount (str, optional): An optional transfer amount.
        transaction_amount (str, optional): An optional transaction amount.
        transaction_id (str, optional): An optional transaction ID.
        transaction_type (str, optional): An optional transaction type.
        expiry_time (str, optional): An optional expiry time.
        status (str, optional): An optional status.
        public_key (str, optional): An optional public key.
        transactions (str, optional): An optional transactions field.
        balance (str, optional): An optional balance.
        encryption_key (str, optional): An optional encryption key.

    Returns:
        None

    Methods:
        json(): Converts the Response object to a JSON-formatted string.
    """

    def __init__(
        self,
        message: str,
        status_code: int,
        error_message: str = None,
        transfer_amount: str = None,
        transaction_amount: str = None,
        transaction_id: str = None,
        transaction_type: str = None,
        expiry_time: str = None,
        status: str = None,
        public_key: str = None,
        transactions: str = None,
        balance: str = None,
        encryption_key: str = None
    ):
        # Initialize Response attributes
        self.message = message
        self.status_code = status_code
        self.error_message = error_message
        self.transfer_amount = transfer_amount
        self.transaction_amount = transaction_amount
        self.transaction_id = transaction_id
        self.transaction_type = transaction_type
        self.expiry_time = expiry_time
        self.status = status
        self.public_key = public_key
        self.transactions = transactions
        self.balance = balance
        self.encryption_key = encryption_key
    
    def json(self):
        """
        Converts the Response object to a JSON-formatted string.

        Args:
            None

        Returns:
            str: A JSON-formatted string representing the Response object.
        """
        response_dict = {'message': self.message}

        # Add non-None variables to the response_dict
        for attr_name, attr_value in self.__dict__.items():
            if attr_value is not None:
                response_dict[attr_name] = attr_value

        return json.dumps(response_dict)
