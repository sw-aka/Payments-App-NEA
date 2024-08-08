from decimal import Decimal  # Import the Decimal class from the decimal module
import base64  # Import the base64 module

class TransactionConfig:
    """
    Configurations related to transactions.
    """

    TRANSFER_FEE_PERCENT = Decimal("0.01")  # Set transfer fee percentage to 0.01 (1%)
    TRANSACTION_CREATION_FEE = Decimal("0.00001")  # Set transaction creation fee to 0.000001
    ALIAS_CREATION_FEE = Decimal("0.00001")  # Set alias creation fee to 0.000001
    ADMIN_ADDRESS = base64.b64encode(bytes.fromhex("e734ea6c2b6257de72355e472aa05a4c487e6b463c029ed306df2f01b5636b58")).decode()  # Set admin address using base64 encoding
    DELETION_DELAY_AFTER_EXPIRY = 3600  # Set deletion delay after expiry to 3600 seconds (1 hour)
    MAX_REQUEST_SIZE = 1024 * 1024  # Set max request size to 1 MB
    MAX_REQUEST_EXPIRY_TIME = 60  # Set max request expiry time to 60 seconds
    MAX_TRANSACTION_EXPIRY_TIME = 3600  # Set max transaction expiry time to 3600 seconds (1 hour)
    MAX_ALIAS_EXPIRY_TIME = 86400  # Set max alias expiry time to 86400 seconds (1 day)


class TransferLimits:
    """
    Configurations related to transfer limits.
    """

    MAX_TRANSFER_PRECISION = 5  # Set max transfer precision to 5
    MAX_TRANSFER_AMOUNT = Decimal("99999999999999.99999")  # Set max transfer amount to 99999999999999.99999
    MIN_TRANSFER_AMOUNT = Decimal("0.00001")  # Set min transfer amount to 0.00001
