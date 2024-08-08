// Importing necessary libraries
import 'dart:core';
import 'package:crypton/crypton.dart' as crypton;

// Defining the EncryptionKey class
class EncryptionKey {
  // Private fields for RSAPublicKey and updateTime
  crypton.RSAPublicKey? _publicKey;
  int? _updateTime;

  // Getter for updateTime
  int getUpdateTime() {
    return _updateTime ?? 0;
  }

  // Getter for RSAPublicKey
  crypton.RSAPublicKey? getPublicKey() {
    return _publicKey;
  }

  // Setter for RSAPublicKey
  void setPublicKey(crypton.RSAPublicKey publicKey) {
    _publicKey = publicKey;
  }

  // Setter for updateTime
  void setUpdateTime(int updateTime) {
    _updateTime = updateTime;
  }
}

// Creating an instance of EncryptionKey
EncryptionKey encryptionKey = EncryptionKey();
