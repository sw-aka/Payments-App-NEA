import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:decimal/decimal.dart';

import '../tools/toast.dart';
import '../tools/wallet.dart';
import '../tools/api.dart';
import '../tools/database.dart';
import '../tools/tools.dart';

import '../designs/designs.dart';

/// A stateful widget for the Receive Page.
class ReceivePage extends StatefulWidget {
  const ReceivePage({Key? key});

  @override
  ReceivePageState createState() => ReceivePageState();
}

/// The state class for the Receive Page.
class ReceivePageState extends State<ReceivePage> {
  // Controllers for text input fields.
  TextEditingController receiverAddressController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  // Flags to control button states.
  bool createTransactionButtonDisabled = false;
  bool transferButtonDisabled = false;

  /// Handles the press event of the "Create Transaction" button.
  void handleCreateTransactionPress() async {
    // Check if the button is disabled.
    if (createTransactionButtonDisabled) {
      return;
    }

    // Disable the button.
    setState(() {
      createTransactionButtonDisabled = true;
    });

    // Extract transaction amount from text input.
    String transactionAmountString = amountController.text.replaceAll('£', '');

    // Check if amount is empty.
    if (transactionAmountString.isEmpty) {
      setState(() {
        createTransactionButtonDisabled = false;
      });
      sendToast('No amount entered.');
      return;
    }

    // Parse the amount to Decimal.
    late Decimal transactionAmount;
    try {
      transactionAmount = Decimal.parse(transactionAmountString);
    } catch (e) {
      setState(() {
        createTransactionButtonDisabled = false;
      });
      sendToast('Amount must be numeric.');
      return;
    }

    // Generate timestamps for transaction and request expiration.
    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expiryTime = currentEpochTime + 60;
    int transactionExpiryTime = currentEpochTime + 300;

    // Generate a unique transaction ID.
    String transactionId = generateUniqueId();

    // Prepare data for the API request.
    Map<String, dynamic> data = {
      'request_id': transactionId,
      'request_expiry_time': expiryTime.toString(),
      'transaction_expiry_time': transactionExpiryTime.toString(),
      'transaction_amount': transactionAmount.toString(),
      'transaction_type': 'RECEIVE',
      'master_key': base64.encode(await Wallet().getPublicKeyBytes()),
    };

    // Create and send the API request.
    APIRequest request = APIRequest('/api/create-transaction', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    // Handle API response.
    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      // Clear the amount input field.
      amountController.clear();

      // Extract transaction details from the response.
      String transactionId = apiResponse.getJson()['transaction_id'].toString();
      String amount = apiResponse.getJson()['transaction_amount'];

      // Insert transaction details into the local database.
      await db.insert('TransactionHistory', {
        'TransactionID': transactionId,
        'TransactionType': 'RECEIVE',
        'Amount': amount,
        'ExpiryTime': transactionExpiryTime,
        'Status': 'PENDING'
      });

      sendToast('Transaction created successfully!');
    }

    // Re-enable the button.
    setState(() {
      createTransactionButtonDisabled = false;
    });
  }

  /// Build method for the Receive Page.
  @override
  Widget build(BuildContext context) {
    // Set the context for toasts.
    toastContext = context;

    // Return the main scaffold structure.
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
                // Amount input field.
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding:
                          EdgeInsets.only(left: constraints.maxWidth * 0.02),
                      child: TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          hintText: 'Enter Amount To Receive...',
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
                          fontSize: constraints.maxHeight * 0.55,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (value) {
                          // Ensure amount starts with '£'.
                          if (!value.startsWith('£')) {
                            amountController.text = '£$value';
                            amountController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: amountController.text.length),
                            );
                          }
                        },
                      ),
                    );
                  }),
                ),
                // "Create Transaction" button.
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding:
                          EdgeInsets.only(left: constraints.maxWidth * 0.06),
                      child: GestureDetector(
                        onTap: () => handleCreateTransactionPress(),
                        child: Text(
                          'Create Transaction',
                          style: TextStyle(
                            fontSize: constraints.maxHeight * 0.55,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const Expanded(
                  flex: 90,
                  child: SizedBox(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
