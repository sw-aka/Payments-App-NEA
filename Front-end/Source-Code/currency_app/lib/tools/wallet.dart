// Import necessary libraries in a better order
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import custom tools
import '../tools/toast.dart';
import '../tools/api.dart';

/// A class representing a wallet with cryptographic functions.
class Wallet {
  // Singleton instance of the Wallet class
  static final Wallet _instance = Wallet._internal();

  // Private variables for key pair, shared preferences, and balance
  late SimpleKeyPair _keyPair;
  late SharedPreferences _prefs;
  late Decimal balance;

  // Private constructor for the singleton pattern
  Wallet._internal();

  // Factory method to get the singleton instance
  factory Wallet() {
    return _instance;
  }

  /// Initializes the wallet by loading or generating key pair and balance.
  /// Args: None
  /// Returns: Future<void>
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    String? privateKeyHex = _prefs.getString('privKeyHex');
    String? tempBalance = _prefs.getString('balance');

    if (privateKeyHex == null) {
      _keyPair = await _generateKeyPair();
      await _prefs.setString(
          'privKeyHex', base64.encode(await _keyPair.extractPrivateKeyBytes()));
    } else {
      _keyPair = await Ed25519().newKeyPairFromSeed(hex.decode(privateKeyHex));
    }

    if (tempBalance == null) {
      await _prefs.setString('balance', '0');
      balance = Decimal.parse('0');
    } else {
      balance = Decimal.parse(tempBalance);
    }
  }

  /// Generates a new cryptographic key pair.
  /// Args: None
  /// Returns: Future<SimpleKeyPair>
  Future<SimpleKeyPair> _generateKeyPair() async {
    return Ed25519().newKeyPair();
  }

  /// Creates a new wallet by generating a new key pair.
  /// Args: None
  /// Returns: Future<List<List<int>>>
  Future<List<List<int>>> createNewWallet() async {
    _keyPair = await _generateKeyPair();
    await _prefs.setString(
        'privKeyHex', hex.encode(await _keyPair.extractPrivateKeyBytes()));
    return [await getPrivateKeyBytes(), await getPublicKeyBytes()];
  }

  /// Generates an alias consisting of a new key pair.
  /// Args: None
  /// Returns: Future<List<List<int>>>
  Future<List<List<int>>> generateAlias() async {
    SimpleKeyPair keyPair = await Ed25519().newKeyPair();

    return [
      await keyPair.extractPrivateKeyBytes(),
      (await keyPair.extractPublicKey()).bytes
    ];
  }

  /// Retrieves the private key bytes.
  /// Args: None
  /// Returns: Future<List<int>>
  Future<List<int>> getPrivateKeyBytes() async {
    return _keyPair.extractPrivateKeyBytes();
  }

  /// Retrieves the public key bytes.
  /// Args: None
  /// Returns: Future<List<int>>
  Future<List<int>> getPublicKeyBytes() async {
    return (await _keyPair.extractPublicKey()).bytes;
  }

  /// Creates a wallet from a provided private key.
  /// Args: List<int> privateKeyBytes
  /// Returns: Future<List<List<int>>>
  Future<List<List<int>>> createWalletFromKey(
      List<int> privateKeyBytes) async {
    _keyPair = await Ed25519().newKeyPairFromSeed(privateKeyBytes);
    await _prefs.setString(
        'privKeyHex', hex.encode(await _keyPair.extractPrivateKeyBytes()));
    return [await getPrivateKeyBytes(), await getPublicKeyBytes()];
  }

  /// Signs the provided data using the private key.
  /// Args: List<int> data
  /// Returns: Future<List<int>>
  Future<List<int>> sign(List<int> data) async {
    return (await Ed25519().sign(data, keyPair: _keyPair)).bytes;
  }

  /// Checks if the provided private key hex is valid.
  /// Args: String privateKeyBytes
  /// Returns: bool
  static bool checkPrivateKeyHex(String privateKeyBytes) {
    try {
      Ed25519().newKeyPairFromSeed(hex.decode(privateKeyBytes));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Updates the wallet balance by making an API request.
  /// Args: None
  /// Returns: Future<Decimal>
  Future<Decimal> updateBalance() async {
    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    int expiryTime = currentEpochTime + 60;

    final random = Random();
    int min = 10000;
    int max = 99999;
    late int randomNumber;

    String randomString = "";

    // Generate a random string for transaction ID
    for (int i = 0; i < 4; i++) {
      randomNumber = min + random.nextInt(max - min + 1);
      randomString += randomNumber.toString();
    }

    // Create a unique transaction ID
    final double currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
    final String currentTimeString =
        (currentTime * 10000000).toStringAsFixed(0).substring(5);

    final String transactionId = currentTimeString + randomString;

    // Prepare data for API request
    Map<String, dynamic> data = {
      'request_id': transactionId,
      'request_expiry_time': expiryTime.toString(),
      'master_key': base64.encode(await Wallet().getPublicKeyBytes())
    };

    // Create and send API request
    APIRequest request = APIRequest('/api/get-balance', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    Decimal tempBalance = Decimal.parse('-1');

    // Check API response and update balance
    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      balance = Decimal.parse(apiResponse.getJson()['balance']);
      _prefs.setString('balance', balance.toString());
      tempBalance = balance;
    }

    return tempBalance;
  }
}
