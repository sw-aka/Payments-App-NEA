import 'package:flutter/material.dart';
import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'dart:core';
import 'package:flutter_svg/flutter_svg.dart';

import '../tools/toast.dart';
import '../tools/wallet.dart';

import '../pages/sendPage.dart';
import '../pages/receivePage.dart';
import '../pages/paymentsPage.dart';
import '../pages/aliasAddressPage.dart';
import '../pages/walletInfoPage.dart';
import '../pages/transactionsPage.dart';

// Class and Function Docstrings
/// HomePage class represents the main page of the application.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

/// HomePageState class manages the state of the HomePage widget.
class HomePageState extends State<HomePage> {
  // Class Variables
  String publicKeyHex = '';
  String mainBalance = '0.00';
  String extraDecimalBalance = '000';

  Map<String, dynamic> visiblePages = {
    'Send': const SendPage(),
    'Receive': const ReceivePage(),
    'Alias Addresses': const AliasAddressPage(),
    'Transaction List': const PaymentsPage(),
    'Enter Transaction ID': const TransactionPage()
  };

  bool walletSettingsPageVisible = false;

  // Class Functions

  /// Updates the public key in hexadecimal format.
  Future<String> updatePublicKeyHex() async {
    publicKeyHex = hex.encode(await Wallet().getPublicKeyBytes());
    return publicKeyHex;
  }

  /// Initializes the state of the widget.
  @override
  void initState() {
    super.initState();
    updatePublicKeyHex().then((result) {
      setState(() {
        publicKeyHex = result;
      });
    });
    String fullBalance = Wallet().balance.toStringAsFixed(5);

    setState(() {
      mainBalance = fullBalance.substring(0, fullBalance.length - 3);
      extraDecimalBalance = fullBalance.substring(fullBalance.length - 3);
    });
  }

  /// Handles the refresh of the wallet balance.
  void handleRefreshBalance() async {
    Decimal tempBalance = await Wallet().updateBalance();
    if (tempBalance != Decimal.parse("-1")) {
      String fullBalance = tempBalance.toStringAsFixed(5);

      setState(() {
        mainBalance = fullBalance.substring(0, fullBalance.length - 3);
        extraDecimalBalance = fullBalance.substring(fullBalance.length - 3);
      });
      sendToast('Balance updated successfully!');
    }
  }

  // Widget Building

  /// Builds the content of the home page.
  Container homePageContent(BuildContext context) {
    toastContext = context;
    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          const Expanded(
            flex: 10,
            child: SizedBox(),
          ),
          Expanded(
              flex: 10,
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 100,
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          alignment: Alignment.center,
                          heightFactor: 0.7,
                          child: LayoutBuilder(builder: (context, constraints) {
                            double fontSize = constraints.maxHeight * 0.8;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: () async => handleRefreshBalance(),
                                    child: SvgPicture.asset(
                                      'assets/refresh-icon.svg',
                                      height: constraints.maxHeight * 0.7,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth * 0.03,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: <Widget>[
                                    Container(
                                      alignment: Alignment.bottomRight,
                                      child: Text('£$mainBalance',
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                          )),
                                    ),
                                    Container(
                                      alignment: Alignment.bottomLeft,
                                      child: Text(
                                        extraDecimalBalance,
                                        style: TextStyle(
                                          fontSize: fontSize * 0.7,
                                          fontWeight: FontWeight.w500,
                                          height: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    )
                  ],
                ),
              )),
          const Expanded(
            flex: 2,
            child: SizedBox(),
          ),
          Expanded(
            flex: 7,
            child: Container(
              color: Colors.transparent,
              child: LayoutBuilder(builder: (context, constraints) {
                double fontSize = constraints.maxHeight * 0.3;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      flex: 75,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerRight,
                        widthFactor: 0.8,
                        child: Column(children: <Widget>[
                          Expanded(
                            child: Container(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                'Wallet Address',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.topLeft,
                              child: Text(
                                publicKeyHex,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSize,
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: SizedBox(),
                    ),
                    Expanded(
                      flex: 23,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const MoreWalletInfoPage()),
                            );
                          },
                          child: SvgPicture.asset('assets/settings-icon.svg',
                              height: constraints.maxHeight * 0.6,
                              width: constraints.maxWidth * 0.6),
                        ),
                      ),
                    )
                  ],
                );
              }),
            ),
          ),
          const Expanded(
            flex: 19,
            child: SizedBox(),
          ),
          Expanded(
            flex: 38,
            child: Container(
              color: Colors.transparent,
              child: LayoutBuilder(builder: (context, constraints) {
                return Column(
                  children: List.generate(visiblePages.length, (index) {
                    return Expanded(
                      child: Container(
                        margin:
                            EdgeInsets.only(left: constraints.maxWidth * 0.05),
                        alignment: Alignment.centerLeft,
                        color: Colors.transparent,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => visiblePages[
                                      visiblePages.keys.toList()[index]]),
                            );
                          },
                          child: Text(
                            visiblePages.keys.toList()[index],
                            style: TextStyle(
                              fontSize: constraints.maxHeight * 0.1,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
          const Expanded(
            flex: 8,
            child: SizedBox(),
          ),
          Expanded(
              flex: 10,
              child: Visibility(
                visible: false,
                child: Container(
                  color: Colors.transparent,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return GestureDetector(
                      onTap: () {},
                      child: SvgPicture.asset(
                        'assets/qr-code-scan-icon.svg',
                        height: constraints.maxHeight * 0.9,
                        width: constraints.maxWidth * 0.9,
                      ),
                    );
                  }),
                ),
              )),
          const Expanded(
            flex: 4,
            child: SizedBox(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: homePageContent(context),
    );
  }
}
