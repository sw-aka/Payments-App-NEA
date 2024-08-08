import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypton/crypton.dart' as crypton;

import '../config.dart';
import '../tools/wallet.dart';

import '../tools/encryption.dart';
import '../tools/tools.dart';

/// Handles API requests including signing and encryption.
class APIRequest {
  late String _endpoint;
  late Map<String, dynamic> _data;
  late crypton.RSAPrivateKey _privateKey;
  late String _encryptedData;

  /// Constructor to initialize APIRequest with endpoint and data.
  ///
  /// Args:
  ///   - endpoint: The API endpoint.
  ///   - data: Data to be sent in the request.
  APIRequest(String endpoint, Map<String, dynamic> data) {
    _endpoint = endpoint;
    _data = data;
  }

  /// Sorts and signs the data.
  ///
  /// Returns: A Future that resolves when signing is complete.
  Future<void> sign() async {
    // Sorting data for consistent signing.
    List<MapEntry<String, dynamic>> sortedEntries =
        mergeSort(_data.entries.toList());
    _data = Map.fromEntries(sortedEntries);

    String jsonString = json.encode(_data);

    // Signing the JSON data.
    String signatureBs4 =
        base64Encode(await Wallet().sign(utf8.encode(jsonString)));

    _data['signature'] = signatureBs4;
  }

  /// Sends the encrypted request and processes the response.
  ///
  /// Returns: A Future containing ApiResponse.
  Future<ApiResponse> send() async {
    // Checking for active internet connection.
    if (!await activeInternetConnection()) {
      return ApiResponse(message: 'No internet connection.');
    }

    // Encrypting the data.
    ApiResponse apiResponse = await _encrypt();

    if (!apiResponse.success()) {
      return apiResponse;
    }

    // Sending the encrypted request.
    apiResponse = await sendPostRequest(_endpoint);

    if (!apiResponse.success()) {
      return apiResponse;
    }

    final http.Response response = apiResponse.getResponse();

    // Decrypting the response.
    final Map<String, dynamic> jsonResponse = json.decode(response.body);

    if (jsonResponse.containsKey('data')) {
      // Handling decrypted data.
      String cipherText = jsonResponse['data'];

      const int decryptionChunkSize = 344;

      List<String> messageSections = [];
      for (int i = 0; i < cipherText.length; i += decryptionChunkSize) {
        int end = (i + decryptionChunkSize < cipherText.length)
            ? i + decryptionChunkSize
            : cipherText.length;
        messageSections.add(cipherText.substring(i, end));
      }

      List<String> decryptedMessageSections = [];

      for (String section in messageSections) {
        String plainText = _privateKey.decrypt(section);
        decryptedMessageSections.add(plainText);
      }

      String decryptedData = decryptedMessageSections.join('');
      Map<String, dynamic> decryptedJson = json.decode(decryptedData);

      if (response.statusCode != 200) {
        return ApiResponse(
          message: decryptedJson['message'],
          errorMessage: decryptedJson['error_message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          responseJson: decryptedJson,
        );
      }
    } else {
      // Handling non-encrypted response.
      if (response.statusCode != 200) {
        if (jsonResponse['error_message'] == 'invalid_encrypted_data') {
          _updateEncryptionKey();
          return send();
        }
        return ApiResponse(
          message: jsonResponse['message'],
          errorMessage: jsonResponse['error_message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          responseJson: jsonResponse,
        );
      }
    }
  }

  /// Sends a GET request to the specified endpoint.
  ///
  /// Args:
  ///   - endpoint: The API endpoint for the GET request.
  ///
  /// Returns: A Future containing ApiResponse.
  Future<ApiResponse> sendGetRequest(String endpoint) async {
    String url = apiDomain + endpoint;
    try {
      http.Response response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      
      return ApiResponse(
        response: response,
        statusCode: 200,
      );
    } catch (error) {
      if (error is SocketException) {
        return ApiResponse(message: 'Could not connect to server.');
      } else {
        return ApiResponse(message: 'A connection error occurred.');
      }
    }
  }

  /// Sends a POST request to the specified endpoint with encrypted data.
  ///
  /// Args:
  ///   - endpoint: The API endpoint for the POST request.
  ///
  /// Returns: A Future containing ApiResponse.
  Future<ApiResponse> sendPostRequest(String endpoint) async {
    String url = apiDomain + endpoint;

    try {
      http.Response response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        body: _encryptedData,
      );
      return ApiResponse(
        response: response,
        statusCode: 200,
      );
    } catch (error) {
      if (error is SocketException) {
        return ApiResponse(errorMessage: 'Could not connect to server.');
      } else {
        return ApiResponse(errorMessage: 'A connection error occurred.');
      }
    }
  }

  /// Checks for an active internet connection.
  ///
  /// Returns: A Future containing a boolean indicating internet connectivity.
  Future<bool> activeInternetConnection() async {
    final connectivityResult = await (Connectivity().checkConnectivity());

    bool activeConnection = true;
    if (connectivityResult == ConnectivityResult.none) {
      activeConnection = false;
    }

    return activeConnection;
  }

  /// Updates the encryption key by making a GET request to '/api/get-key'.
  ///
  /// Returns: A Future containing ApiResponse.
  Future<ApiResponse> _updateEncryptionKey() async {
    String endpoint = '/api/get-key';

    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    ApiResponse apiResponse = await sendGetRequest(endpoint);
    if (!apiResponse.success()) {
      return apiResponse;
    }

    Map<String, dynamic> jsonData = apiResponse.getJson();

    String publicKeyBase64 = jsonData['key'];

    crypton.RSAPublicKey publicKey =
        crypton.RSAPublicKey.fromString(publicKeyBase64);
    encryptionKey.setPublicKey(publicKey);
    encryptionKey.setUpdateTime(currentEpochTime);

    return ApiResponse();
  }

  /// Encrypts the data using the current encryption key.
  ///
  /// Returns: A Future containing ApiResponse.
  Future<ApiResponse> _encrypt() async {
    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (encryptionKey.getUpdateTime() < currentEpochTime - 3600) {
      ApiResponse apiResponse = await _updateEncryptionKey();
      if (!apiResponse.success()) {
        return apiResponse;
      }
    }

    crypton.RSAPublicKey encryptionPublicKey = encryptionKey.getPublicKey()!;

    crypton.RSAKeypair rsaKeypair = crypton.RSAKeypair.fromRandom();
    crypton.RSAPublicKey decryptionPublicKey = rsaKeypair.publicKey;
    _privateKey = rsaKeypair.privateKey;

    _data['encryption_key'] = _getBase64FromPublicKey(decryptionPublicKey);

    String jsonString = json.encode(_data);

    const int encryptionChunkSize = 190;

    List<String> messageSections = [];
    for (int i = 0; i < jsonString.length; i += encryptionChunkSize) {
      int end = (i + encryptionChunkSize < jsonString.length)
          ? i + encryptionChunkSize
          : jsonString.length;
      messageSections.add(jsonString.substring(i, end));
    }

    List<String> encryptedMessageSections = [];

    for (String section in messageSections) {
      String base64EncodedSection = encryptionPublicKey.encrypt(section);
      encryptedMessageSections.add(base64EncodedSection);
    }

    String finalEncrypted = encryptedMessageSections.join('');

    _encryptedData = finalEncrypted;

    return ApiResponse();
  }

  /// Converts the RSA public key to a Base64 string.
  ///
  /// Args:
  ///   - publicKey: The RSA public key to be converted.
  ///
  /// Returns: A Base64-encoded string representation of the RSA public key.
  String _getBase64FromPublicKey(crypton.RSAPublicKey publicKey) {
    String base64String = publicKey.toString();
    return base64String;
  }
}

/// Represents the response from an API request.
class ApiResponse {
  Map<String, dynamic>? _responseJson;
  String? _message;
  http.Response? _response;
  int? _statusCode;
  bool? _connectionIssue;
  String? _errorMessage;

  /// Constructor to initialize ApiResponse.
  ///
  /// Args:
  ///   - message: A message associated with the response.
  ///   - errorMessage: An error message associated with the response.
  ///   - responseJson: JSON data from the response.
  ///   - response: The HTTP response object.
  ///   - statusCode: The status code of the response.
  ///   - connectionIssue: A boolean indicating whether there was a connection issue.
  ApiResponse({
    String? message,
    String? errorMessage,
    Map<String, dynamic>? responseJson,
    http.Response? response,
    int? statusCode,
    bool? connectionIssue,
  }) {
    _message = message;
    _responseJson = responseJson;
    _response = response;
    _statusCode = statusCode;
    _connectionIssue = connectionIssue;
    _errorMessage = errorMessage;

    // Automatically decode JSON if response is available.
    if (response != null) {
      _responseJson = json.decode(response.body);
    }
  }

  /// Checks if the response was successful.
  ///
  /// Returns: A boolean indicating success.
  bool success() {
    return _message == null;
  }

  /// Gets the message associated with the response.
  ///
  /// Returns: The message string.
  String getMessage() {
    return _message!;
  }

  /// Gets the error message associated with the response.
  ///
  /// Returns: The error message string.
  String getErrorMessage() {
    return _errorMessage!;
  }

  /// Gets the JSON data from the response.
  ///
  /// Returns: A Map containing the JSON data.
  Map<String, dynamic> getJson() {
    return _responseJson!;
  }

  /// Gets the HTTP response object.
  ///
  /// Returns: The HTTP response object.
  http.Response getResponse() {
    return _response!;
  }

  /// Checks if there was a connection issue.
  ///
  /// Returns: A boolean indicating a connection issue.
  bool connectionIssue() {
    return _connectionIssue ?? false;
  }

  /// Gets the status code of the response.
  ///
  /// Returns: The status code.
  int getStatusCode() {
    return _statusCode!;
  }
}
