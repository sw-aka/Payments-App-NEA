import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../tools/api.dart';
import '../tools/database.dart';
import '../tools/toast.dart';
import '../tools/tools.dart';
import '../tools/wallet.dart';

import '../designs/designs.dart';

/// SendPage class for handling transaction creation and transfer.
class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  SendPageState createState() => SendPageState();
}

/// State class for the SendPage widget.
class SendPageState extends State<SendPage> {
  // Text editing controllers for the input fields.
  TextEditingController receiverAddressController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  // Flags to disable buttons during processing.
  bool createTransactionButtonDisabled = false;
  bool transferButtonDisabled = false;

  /// Handles the button press for creating a transaction.
  void handleCreateTransactionPress() async {
    // Check if the button is disabled.
    if (createTransactionButtonDisabled) {
      return;
    }

    // Disable the button to prevent multiple presses.
    setState(() {
      createTransactionButtonDisabled = true;
    });

    // Remove the currency symbol from the amount.
    String transactionAmountString = amountController.text.replaceAll('£', '');

    // Check if the amount is empty.
    if (transactionAmountString.isEmpty) {
      setState(() {
        createTransactionButtonDisabled = false;
      });
      sendToast('No amount entered.');
      return;
    }

    late Decimal transactionAmount;
    try {
      // Parse the transaction amount.
      transactionAmount = Decimal.parse(transactionAmountString);
    } catch (e) {
      setState(() {
        createTransactionButtonDisabled = false;
      });
      sendToast('Amount must be numeric.');
      return;
    }

    // Get the current epoch time.
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
      'transaction_type': 'SEND',
      'master_key': base64.encode(await Wallet().getPublicKeyBytes()),
    };

    // Create an API request and send it.
    APIRequest request = APIRequest('/api/create-transaction', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    // Handle the API response.
    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      // Clear the amount field.
      amountController.clear();
      
      // Get transaction details from the API response.
      String transactionId = apiResponse.getJson()['transaction_id'].toString();
      String amount = apiResponse.getJson()['transaction_amount'];

      // Insert transaction details into the local database.
      await db.insert('TransactionHistory', {
        'TransactionID': transactionId,
        'TransactionType': 'SEND',
        'Amount': amount,
        'ExpiryTime': transactionExpiryTime,
        'Status': 'PENDING'
      });

      sendToast('Transaction created successfully!');
    }

    // Enable the button after processing.
    setState(() {
      createTransactionButtonDisabled = false;
    });
  }

  /// Handles the button press for transferring funds.
  void handleTransferPress() async {
    // Check if the button is disabled.
    if (transferButtonDisabled) {
      return;
    }

    // Disable the button to prevent multiple presses.
    setState(() {
      transferButtonDisabled = true;
    });

    // Remove the currency symbol from the amount.
    String transferAmount = amountController.text.replaceAll("£", "");

    // Check if the amount is empty.
    if (transferAmount.isEmpty) {
      setState(() {
        transferButtonDisabled = false;
      });
      sendToast('No amount entered.');
      return;
    }

    try {
      // Parse the transfer amount.
      Decimal.parse(transferAmount);
    } catch (e) {
      setState(() {
        transferButtonDisabled = false;
      });
      sendToast('Amount must be numeric');
      return;
    }

    // Get receiver's address from the input field.
    String receiverAddress = receiverAddressController.text;

    // Validate receiver's address.
    if (receiverAddress.length != 64) {
      setState(() {
        transferButtonDisabled = false;
      });
      sendToast("Receiver's address must be 64 characters long.");
      return;
    } else if (!isHex(receiverAddress)) {
      setState(() {
        transferButtonDisabled = false;
      });
      sendToast("Receiver's address must be a hexadecimal string.");
      return;
    }

    // Get the current epoch time.
    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expiryTime = currentEpochTime + 60;

    // Generate a unique transaction ID.
    String transactionId = generateUniqueId();

    // Encode receiver's address to base64.
    String receiverAddressB64 = base64Encode(hex.decode(receiverAddress));

    // Prepare data for the API request.
    Map<String, dynamic> data = {
      'request_id': transactionId,
      'request_expiry_time': expiryTime.toString(),
      'transfer_amount': transferAmount,
      'sender_key': base64.encode(await Wallet().getPublicKeyBytes()),
      'recipient_key': receiverAddressB64,
    };

    // Create an API request and send it.
    APIRequest request = APIRequest('/api/transfer', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    // Handle the API response.
    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      // Insert transfer details into the local database.
      await db.insert('TransferHistory', {
        'PublicKey': receiverAddress,
        'Amount': transferAmount,
        'TransactionTime': currentEpochTime.toString(),
      });

      // Clear input fields.
      amountController.clear();
      receiverAddressController.clear();

      sendToast('Transfer Successful!');
    }

    // Enable the button after processing.
    setState(() {
      transferButtonDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set the context for toast messages.
    toastContext = context;

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
                      padding: EdgeInsets.only(left: constraints.maxWidth * 0.02),
                      child: TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          hintText: 'Enter Amount To Send...',
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
                          // Add currency symbol if not present.
                          if (!value.startsWith('£')) {
                            amountController.text = '£$value';
                            amountController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: amountController.text.length),
                            );
                          }
                        },
                      ),
                    );
                  }),
                ),
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.only(left: constraints.maxWidth * 0.06),
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
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.only(left: constraints.maxWidth * 0.02),
                      child: TextField(
                        controller: receiverAddressController,
                        decoration: InputDecoration(
                          hintText: "Enter Receiver's Address...",
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
                      padding: EdgeInsets.only(left: constraints.maxWidth * 0.06),
                      child: GestureDetector(
                        onTap: () => handleTransferPress(),
                        child: Text(
                          'Send',
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
                  flex: 80,
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
