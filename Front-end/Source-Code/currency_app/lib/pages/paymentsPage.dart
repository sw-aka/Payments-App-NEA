import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math';

import '../designs/designs.dart';
import '../tools/api.dart';
import '../tools/database.dart';
import '../tools/toast.dart';
import '../tools/tools.dart';
import '../tools/transaction.dart';
import '../tools/wallet.dart';

/// Page for displaying payment transactions.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({Key? key});

  @override
  PaymentsPageState createState() => PaymentsPageState();
}

/// State class for PaymentsPage.
class PaymentsPageState extends State<PaymentsPage> {
  @override
  Widget build(BuildContext context) {
    toastContext = context;
    return Scaffold(
      body: Column(children: <Widget>[
        Expanded(
          flex: 10,
          child: backButton(context),
        ),
        Expanded(
          flex: 90,
          child: Container(
            padding: EdgeInsets.only(
              left: MediaQuery.of(context).size.height * 0.01,
              right: MediaQuery.of(context).size.height * 0.01,
              bottom: MediaQuery.of(context).size.height * 0.02,
            ),
            child: const TransactionListSection(),
          ),
        ),
      ]),
    );
  }
}

/// Widget for displaying the list of transactions.
class TransactionListSection extends StatefulWidget {
  const TransactionListSection({Key? key});

  @override
  TransactionListSectionState createState() => TransactionListSectionState();
}

/// State class for TransactionListSection.
class TransactionListSectionState extends State<TransactionListSection> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Transaction> transactions = [];
  bool initialLoad = false;

  @override
  void initState() {
    getTransactions().then((result) {
      setState(() {
        transactions = result;
      });
    });
    super.initState();
  }

  /// Fetches transactions from the database.
  Future<List<Transaction>> getTransactions() async {
    List<Map<String, dynamic>> maps = await db.query('TransactionHistory');
    Map<String, Transaction> transactionsMap = {};

    for (Map<String, dynamic> map in maps) {
      transactionsMap[map['TransactionID']] = Transaction(
        transactionId: map['TransactionID'],
        transactionType: map['TransactionType'],
        amount: map['Amount'].toString(),
        expiryTime: map['ExpiryTime'].toStringAsFixed(0),
        status: map['Status'],
      );
    }

    setState(() {
      transactions = transactionsMap.values.toList();
      initialLoad = true;
    });

    List<String> transactionsToUpdate = [];

    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (Transaction transaction in transactionsMap.values) {
      if (!['COMPLETED', 'EXPIRED'].contains(transaction.status)) {
        int expiryTime = int.parse(transaction.expiryTime!);

        if (expiryTime < currentEpochTime) {
          transaction.status = "EXPIRED";
          transactionsMap[transaction.transactionId] = transaction;
          await db.rawUpdate(
            'UPDATE TransactionHistory SET Status = ? WHERE TransactionID = ?',
            ['EXPIRED', transaction.transactionId],
          );
        } else {
          transactionsToUpdate.add(transaction.transactionId);
        }
      }
    }

    int chunkSize = 100;

    List<List<String>> transactionsToUpdateSections = [];
    for (var i = 0; i < transactionsToUpdate.length; i += chunkSize) {
      transactionsToUpdateSections.add(transactionsToUpdate.sublist(
          i,
          i + chunkSize > transactionsToUpdate.length
              ? transactionsToUpdate.length
              : i + chunkSize));
    }

    for (List<String> transactionsToUpdate in transactionsToUpdateSections) {
      Map<String, dynamic> data = {
        'transaction_ids': transactionsToUpdate.toString(),
      };

      // Fetch updated transactions from the server.
      APIRequest request = APIRequest('/api/get-transactions', data);
      ApiResponse apiResponse = await request.send();

      if (!apiResponse.success()) {
        sendToast(apiResponse.getMessage());
        return transactionsMap.values.toList();
      } else {
        Map<String, dynamic> updatedTransactionsJson =
            json.decode(apiResponse.getJson()['transactions']);

        for (String transactionId in updatedTransactionsJson.keys) {
          Map<String, dynamic> updatedTransactionJson =
              json.decode(updatedTransactionsJson[transactionId]);
          Transaction updatedTransaction = Transaction(
              transactionId: transactionId,
              status: updatedTransactionJson['status']);

          Transaction currentTransaction = transactionsMap[transactionId]!;
          if (updatedTransaction.status != currentTransaction.status) {
            currentTransaction.status = updatedTransaction.status;
            transactionsMap[transactionId] = currentTransaction;
            await db.rawUpdate(
              'UPDATE TransactionHistory SET Status = ? WHERE TransactionID = ?',
              [updatedTransaction.status, transactionId],
            );
          }
        }
      }
    }

    List<String> missingTransactions = transactionsMap.keys
        .where((element) => !transactionsToUpdate.contains(element))
        .toList();

    await db.rawUpdate(
      'UPDATE TransactionHistory SET Status = ? WHERE TransactionID IN (${List.filled(missingTransactions.length, '?').join(', ')})',
      ['UNKNOWN', ...missingTransactions],
    );

    return transactionsMap.values.toList();
  }

  /// Loads items asynchronously.
  Future<void> _loadItems() async {
    final loadedItems = await getTransactions();
    if (mounted) {
      setState(() {
        transactions = loadedItems;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    toastContext = context;

    int itemCount = transactions.length;

    if (!initialLoad) {
      return const SizedBox();
    }
    if (itemCount == 0) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.1,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 2.0,
            ),
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          double fontSize = constraints.maxHeight * 0.03;
          return Container(
            alignment: Alignment.topLeft,
            padding: EdgeInsets.all(constraints.maxWidth * 0.01),
            child: Text(
              "You do not have any transactions.",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
      );
    } else {
      return ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.1,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.black,
                  width: 2.0,
                ),
              ),
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              String status = transactions[index].status;
              String amount = transactions[index].amount!;
              int num_decimals = 2;
              if (amount.split(".").length == 2) {
                num_decimals = max(amount.split(".")[1].length, num_decimals);
              }
              String amount_formatted =
                  Decimal.parse(transactions[index].amount!)
                      .toStringAsFixed(num_decimals);
              double fontSize = constraints.maxHeight * 0.25;
              return Row(
                children: <Widget>[
                  const Expanded(
                    flex: 5,
                    child: SizedBox(),
                  ),
                  Expanded(
                    flex: 25,
                    child: Text(
                      transactions[index].transactionType!,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "£${amount_formatted}",
                        //"£${Decimal.parse(transactions[index].amount!).toStringAsFixed(max((transactions[index].amount!.split('.')[1].length), 2))}",
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: SizedBox(),
                  ),
                  Expanded(
                    flex: 26,
                    child: FittedBox(
                      child: Text(
                        transactions[index].status,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: SizedBox(),
                  ),
                  Expanded(
                    flex: 10,
                    child: LayoutBuilder(builder: (context, constraints) {
                      return GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: transactions[index].transactionId,
                            ),
                          );
                          sendToast("Transaction ID copied to clipboard.");
                        },
                        child: SvgPicture.asset(
                          'assets/copy-icon.svg',
                          height: constraints.maxHeight * 0.3,
                        ),
                      );
                    }),
                  ),
                  Expanded(
                    flex: 10,
                    child: LayoutBuilder(builder: (context, constraints) {
                      if (status != 'PENDING') {
                        return GestureDetector(
                          onTap: () async {
                            String transactionId =
                                transactions[index].transactionId;

                            await db.delete(
                              'TransactionHistory',
                              where: 'TransactionID = ?',
                              whereArgs: [transactionId],
                            );
                            await _loadItems();
                          },
                          child: LayoutBuilder(builder: (context, constraints) {
                            return SvgPicture.asset('assets/trash-icon.svg',
                                height: constraints.maxHeight * 0.3);
                          }),
                        );
                      } else {
                        return GestureDetector(
                          onTap: () async {
                            String transactionId =
                                transactions[index].transactionId;

                            int currentEpochTime =
                                DateTime.now().millisecondsSinceEpoch ~/ 1000;
                            int expiryTime = currentEpochTime + 60;

                            String uniqueId = generateUniqueId();

                            Map<String, dynamic> data = {
                              'request_id': uniqueId,
                              'request_expiry_time': expiryTime.toString(),
                              'transaction_id': transactionId,
                              'master_key': base64
                                  .encode(await Wallet().getPublicKeyBytes()),
                            };

                            APIRequest request =
                                APIRequest('/api/delete-transaction', data);
                            await request.sign();
                            ApiResponse apiResponse = await request.send();

                            if (!apiResponse.success() &&
                                apiResponse.getErrorMessage() !=
                                    'invalid_transaction_id') {
                              sendToast(apiResponse.getMessage());
                            } else {
                              sendToast('Transaction cancelled successfully!');

                              await db.rawUpdate(
                                'UPDATE TransactionHistory SET Status = ? WHERE TransactionID = ?',
                                ['CANCELLED', transactionId],
                              );

                              await _loadItems();
                            }
                          },
                          child: LayoutBuilder(builder: (context, constraints) {
                            return SvgPicture.asset(
                              'assets/close-round-icon.svg',
                              height: constraints.maxHeight * 0.3,
                            );
                          }),
                        );
                      }
                    }),
                  ),
                  const Expanded(
                    flex: 5,
                    child: SizedBox(),
                  ),
                ],
              );
            }),
          );
        },
      );
    }
  }
}
