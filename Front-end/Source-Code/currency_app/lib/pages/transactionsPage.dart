import 'dart:convert';
import 'package:flutter/material.dart';

import '../tools/api.dart';
import '../tools/tools.dart';
import '../tools/toast.dart';
import '../tools/wallet.dart';
import '../tools/transaction.dart';

import '../designs/designs.dart';

/// The [TransactionPage] class is a StatefulWidget for handling transactions.
class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  TransactionPageState createState() => TransactionPageState();
}

/// The [TransactionPageState] class holds the state for [TransactionPage].
class TransactionPageState extends State<TransactionPage> {
  // State variables
  bool completeTransactionButtonDisabled = false;
  bool completeTransactionButtonVisible = false;
  String completeButtonText = 'Send';
  Transaction transaction = Transaction(
    transactionId: '',
    transactionType: '',
    amount: '',
    expiryTime: '',
    status: '',
  );

  TextEditingController transactionIdController = TextEditingController();
  bool loadTransactionButtonDisabled = false;

  /// Handles the press of the complete transaction button.
  void handleCompleteTransactionPress() async {
    if (completeTransactionButtonDisabled) {
      return;
    }

    setState(() {
      completeTransactionButtonDisabled = true;
    });

    // Get current epoch time and calculate expiry time
    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expiryTime = currentEpochTime + 60;

    // Generate a unique transaction ID
    String transactionId = generateUniqueId();

    // Prepare data for API request
    Map<String, dynamic> data = {
      'request_id': transactionId,
      'request_expiry_time': expiryTime.toString(),
      'transaction_id': transaction.transactionId,
      'master_key': base64.encode(await Wallet().getPublicKeyBytes()),
    };

    // Create and send API request
    APIRequest request = APIRequest('/api/complete-transaction', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    // Handle API response
    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      if (transaction.transactionType == 'SEND') {
        sendToast('Received successfully!');
      } else {
        sendToast('Sent successfully!');
      }

      transaction.status = 'COMPLETED';

      setState(() {
        completeTransactionButtonVisible = false;
        transaction.status = 'COMPLETED';
      });
    }

    setState(() {
      completeTransactionButtonDisabled = false;
    });
  }

  /// Handles the press of the load transaction button.
  void handleLoadTransactionPress() async {
    if (loadTransactionButtonDisabled) {
      return;
    }

    setState(() {
      loadTransactionButtonDisabled = true;
    });

    String transactionId = transactionIdController.text;

    // Validate transaction ID
    if (transactionId.isEmpty) {
      setState(() {
        loadTransactionButtonDisabled = false;
      });
      sendToast('No transaction ID entered.');
      return;
    } else if (transactionId.length != 32) {
      sendToast('Transaction id must be 32 digits long.');
      setState(() {
        loadTransactionButtonDisabled = false;
      });
      return;
    }

    try {
      BigInt.parse(transactionId);
    } catch (e) {
      sendToast('Transaction id must be an integer value.');
      setState(() {
        loadTransactionButtonDisabled = false;
      });
      return;
    }

    // Get current epoch time and calculate expiry time
    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expiryTime = currentEpochTime + 60;

    // Generate a unique request ID
    String requestId = generateUniqueId();

    // Prepare data for API request
    Map<String, dynamic> data = {
      'request_id': requestId,
      'request_expiry_time': expiryTime.toString(),
      'transaction_ids': [transactionId],
    };

    // Create and send API request
    APIRequest request = APIRequest('/api/get-transactions', data);
    ApiResponse apiResponse = await request.send();

    // Handle API response
    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      Map<String, dynamic> jsonResponse = apiResponse.getJson();
      Map<String, dynamic> transactions =
          json.decode(jsonResponse['transactions']);
      if (!transactions.containsKey(transactionId)) {
        sendToast('Transaction not found.');
      } else {
        Map<String, dynamic> transactionJson =
            json.decode(transactions[transactionId]);

        // Create a temporary transaction object
        Transaction tempTransaction = Transaction(
          transactionId: transactionId,
          transactionType: transactionJson['transaction_type'],
          amount: transactionJson['transaction_amount'],
          expiryTime: transactionJson['expiry_time'],
          status: transactionJson['status'],
        );

        setState(() {
          transaction = tempTransaction;
          if (transaction.status == 'PENDING') {
            completeTransactionButtonVisible = true;
          } else {
            completeTransactionButtonVisible = false;
          }
          if (transaction.transactionType == 'SEND') {
            completeButtonText = 'Send';
          } else {
            completeButtonText = 'Receive';
          }
        });

        sendToast('Transaction loaded successfully!');
      }
    }

    setState(() {
      loadTransactionButtonDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    toastContext = context;

    // Transaction information map
    Map<String, dynamic> transactionInfo = {
      'Id': transaction.transactionId,
      'Type': transaction.transactionType,
      'Amount': transaction.amount,
      'Expiry Time': transaction.expiryTime,
      'Status': transaction.status,
    };

    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 10,
            child: backButton(context),
          ),
          Expanded(
            flex: 90,
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding:
                          EdgeInsets.only(left: constraints.maxWidth * 0.02),
                      child: TextField(
                        controller: transactionIdController,
                        decoration: InputDecoration(
                          hintText: "Enter Transaction Id...",
                          hintStyle: TextStyle(
                            fontSize: constraints.maxHeight * 0.55,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          fontSize: constraints.maxHeight * 0.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }),
                ),
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding:
                          EdgeInsets.only(left: constraints.maxWidth * 0.06),
                      child: GestureDetector(
                        onTap: () => handleLoadTransactionPress(),
                        child: Text(
                          'Load Transaction',
                          style: TextStyle(
                            fontSize: constraints.maxHeight * 0.55,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Expanded(
                  flex: 30,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Column(
                      children: List.generate(transactionInfo.length, (index) {
                        return Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(
                              left: constraints.maxWidth * 0.1,
                              right: constraints.maxWidth * 0.1,
                            ),
                            child: Text(
                              "${transactionInfo.keys.toList()[index]}: ${transactionInfo.values.toList()[index]}",
                              style: TextStyle(
                                fontSize: constraints.maxHeight * 0.08,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
                Expanded(
                  flex: 5,
                  child: Visibility(
                    visible: completeTransactionButtonVisible,
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Container(
                        alignment: Alignment.centerLeft,
                        padding:
                            EdgeInsets.only(left: constraints.maxWidth * 0.06),
                        child: GestureDetector(
                          onTap: () => handleCompleteTransactionPress(),
                          child: Text(
                            'Complete Transaction',
                            style: TextStyle(
                              fontSize: constraints.maxHeight * 0.55,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const Expanded(
                  flex: 55,
                  child: SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
