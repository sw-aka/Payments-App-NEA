import 'package:flutter/material.dart';
import 'package:convert/convert.dart';
import 'package:flutter/services.dart';
import 'dart:core';
import 'package:flutter_svg/flutter_svg.dart';

import '../tools/toast.dart';
import '../tools/wallet.dart';
import '../tools/tools.dart';

import '../designs/designs.dart';

// Class representing the MoreWalletInfoPage widget
class MoreWalletInfoPage extends StatefulWidget {
  const MoreWalletInfoPage({super.key});

  @override
  MoreWalletInfoPageState createState() => MoreWalletInfoPageState();
}

// State class for the MoreWalletInfoPage widget
class MoreWalletInfoPageState extends State<MoreWalletInfoPage> {
  // String to store the public key in hexadecimal format
  String publicKeyHex = '';

  // Controller for the private key input field
  TextEditingController privateKeyInputController = TextEditingController();

  // Initializing the state
  @override
  void initState() {
    super.initState();
    updatePublicKeyHex().then((result) {
      setState(() {
        publicKeyHex = result;
      });
    });
  }

  // Asynchronous function to update the public key in hexadecimal format
  Future<String> updatePublicKeyHex() async {
    publicKeyHex = hex.encode(await Wallet().getPublicKeyBytes());
    return publicKeyHex;
  }

  // Build method for the MoreWalletInfoPage widget
  @override
  Widget build(BuildContext context) {
    // Setting the context for toast messages
    toastContext = context;

    // Building the scaffold with a column layout
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 10,
            child: backButton(context),
          ),
          Expanded(
            flex: 90,
            child: Column(
              children: <Widget>[
                const Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 10,
                  child: Container(
                    color: Colors.transparent,
                    child: LayoutBuilder(builder: (context, constraints) {
                      double fontSize = constraints.maxHeight * 0.2;

                      // Displaying wallet address
                      return Column(
                        children: [
                          Expanded(
                            child: Row(
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
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: publicKeyHex,
                                          ),
                                        );
                                        sendToast(
                                            'Wallet address copied to clipboard.');
                                      },
                                      child: SvgPicture.asset(
                                          'assets/copy-icon.svg',
                                          height: constraints.maxHeight * 0.3,
                                          width: constraints.maxWidth * 0.3),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
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
                                            'Private Key',
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
                                            '################################################################',
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
                                      onTap: () async {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: hex.encode(await Wallet()
                                                .getPrivateKeyBytes()),
                                          ),
                                        );
                                        sendToast(
                                            'Private key copied to clipboard.');
                                      },
                                      child: SvgPicture.asset(
                                          'assets/copy-icon.svg',
                                          height: constraints.maxHeight * 0.3,
                                          width: constraints.maxWidth * 0.3),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.only(left: constraints.maxWidth * 0.02),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            flex: 90,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: privateKeyInputController,
                                decoration: InputDecoration(
                                  hintText: 'Enter New Private Key Hex...',
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
                                  fontSize: constraints.maxHeight * 0.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 10,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () async {
                                  String inputtedPrivateKeyHex =
                                      privateKeyInputController.text;

                                  // Validating the inputted private key
                                  if (inputtedPrivateKeyHex.isEmpty) {
                                    sendToast('Empty private key.');
                                    return;
                                  } else if (inputtedPrivateKeyHex.length !=
                                      64) {
                                    sendToast(
                                        'Private key must be 64 characters long.');
                                    return;
                                  } else if (isHex(inputtedPrivateKeyHex) ==
                                      false) {
                                    sendToast(
                                        'Private key must be a hexadecimal string.');
                                    return;
                                  } else {}

                                  privateKeyInputController.clear();

                                  // Creating a wallet from the inputted private key
                                  List<List<int>> keys = await Wallet()
                                      .createWalletFromKey(
                                          hex.decode(inputtedPrivateKeyHex));

                                  // Updating the public key
                                  setState(() {
                                    publicKeyHex = hex.encode(keys[1]);
                                  });

                                  sendToast('Wallet loaded successfully.');
                                },
                                child: SvgPicture.asset(
                                  'assets/upgrade-icon.svg',
                                  height: constraints.maxHeight * 0.7,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      child: GestureDetector(
                        onTap: () async {
                          // Generating a new wallet
                          List<List<int>> keys = await Wallet().createNewWallet();

                          // Updating the public key
                          setState(() {
                            publicKeyHex = hex.encode(keys[1]);
                          });

                          sendToast('New wallet generated successfully.');
                        },
                        child: Text(
                          'Generate New Wallet',
                          style: TextStyle(
                            fontSize: constraints.maxHeight * 0.55,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const Expanded(
                  flex: 53,
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
