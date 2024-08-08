import time  # Import time module for timestamp operations
import math  # Import math module for mathematical operations
import base64  # Import base64 module for base64 encoding/decoding
from cryptography.hazmat.backends import default_backend  # Import cryptography library for RSA encryption
from cryptography.hazmat.primitives.asymmetric import rsa, padding  # Import RSA and padding modules
from cryptography.hazmat.primitives import serialization  # Import serialization module

from response import Response  # Import Response class from response module


class Encryption:
    """
    Class for handling RSA encryption and decryption.

    Attributes:
        KEY_LENGTH (int): Length of RSA key pairs.
        ENCRYPTION_CHUNK_SIZE (int): Size of chunks for encryption.
        DECRYPTION_CHUNK_SIZE (int): Size of chunks for decryption.
    """

    KEY_LENGTH = 392
    ENCRYPTION_CHUNK_SIZE = 190
    DECRYPTION_CHUNK_SIZE = 344

    def __init__(self):
        """
        Initialize the Encryption class and generate RSA key pair.
        """
        self._update_keypairs()  # Call method to generate and update RSA key pair

        self.old_updated = None
        self.old_private_key = None

    def _update_keypairs(self):
        """
        Update RSA key pair and related attributes.
        """
        self.cur_private_key, self.cur_public_key = self._generate_rsa_keypair()  # Generate new RSA key pair
        serialized_public_key = self.cur_public_key.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        self.cur_public_key_b64 = base64.b64encode(serialized_public_key).decode('utf-8')  # Base64 encode public key
        self.cur_updated = math.floor(time.time()) // 3600 * 3600  # Update timestamp

    @staticmethod
    def _generate_rsa_keypair():
        """
        Generate RSA key pair.

        Returns:
            tuple: Private key and public key.
        """
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend()
        )
        public_key = private_key.public_key()
        return private_key, public_key

    def get_public_key(self):
        """
        Get the current public key.

        Returns:
            str: Base64-encoded current public key.
        """
        if self.cur_updated + 3600 <= math.floor(time.time()):  # Check if current key pair is outdated
            if self.cur_updated + 7200 > math.floor(time.time()):  # Check if old key pair is still valid
                self.old_private_key = self.cur_private_key
                self.old_public_key = self.cur_public_key
                self.old_updated = self.cur_updated
            else:
                self.old_private_key = None
                self.old_public_key = None

            self._update_keypairs()  # Update key pair if needed

        if (self.old_updated is not None) and (self.old_updated + 5400 <= math.floor(time.time())):  # Check if old key pair is outdated
            self.old_private_key = None
            self.old_public_key = None
            self.old_updated = None

        return self.cur_public_key_b64  # Return current public key

    def encrypt_message(self, public_key_b64: str, message: str):
        """
        Encrypt a message using RSA public key.

        Args:
            public_key_b64 (str): Base64-encoded public key.
            message (str): Message to be encrypted.

        Returns:
            Response: Encrypted message and status code.
        """
        serialized_public_key = base64.b64decode(public_key_b64)  # Decode base64-encoded public key
        public_key = serialization.load_der_public_key(
            serialized_public_key,
            backend=default_backend()
        )
        message_sections = [message[i:i + self.ENCRYPTION_CHUNK_SIZE] for i in range(0, len(message), self.ENCRYPTION_CHUNK_SIZE)]  # Divide message into chunks
        encrypted_message_sections = []

        for section in message_sections:
            ciphertext = public_key.encrypt(section.encode('utf-8'), padding.PKCS1v15())  # Encrypt each message chunk
            encrypted_message_sections.append(base64.b64encode(ciphertext).decode('utf-8'))

        final_encrypted = ''.join(encrypted_message_sections)
        return Response(message=final_encrypted, status_code=200)

    def decrypt_message(self, ciphertext: str):
        """
        Decrypt an RSA-encrypted message.

        Args:
            ciphertext (str): Encrypted message.

        Returns:
            Response: Decrypted message and status code.
        """
        ciphertext_sections = [ciphertext[i:i + self.DECRYPTION_CHUNK_SIZE] for i in range(0, len(ciphertext), self.DECRYPTION_CHUNK_SIZE)]  # Divide ciphertext into chunks
        plaintext_sections = []

        for section in ciphertext_sections:
            try:
                plaintext = self.cur_private_key.decrypt(base64.b64decode(section), padding.PKCS1v15())  # Decrypt each ciphertext chunk
            except ValueError:
                try:
                    if self.old_private_key is not None:
                        plaintext = self.old_private_key.decrypt(base64.b64decode(section), padding.PKCS1v15())
                    else:
                        raise ValueError
                except ValueError:
                    return Response(
                        error_message='invalid_encrypted_data',
                        message='Encrypted data is corrupt. May have been encrypted using incorrect key.',
                        status_code=400
                    )

            plaintext_sections.append(plaintext.decode('utf-8'))

        final_plaintext = ''.join(plaintext_sections)
        return Response(message=final_plaintext, status_code=200)

    def get_encrypted_response(self, response: Response, key: str):
        """
        Get encrypted response.

        Args:
            response (Response): Original response.
            key (str): Base64-encoded public key.

        Returns:
            tuple: Encrypted response and status code.
        """
        if key is None:
            return response.json(), response.status_code
        return {'data': self.encrypt_message(key, response.json()).message}, response.status_code
