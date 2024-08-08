import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:convert/convert.dart';
import 'dart:convert';

import '../tools/toast.dart';
import '../tools/wallet.dart';
import '../tools/api.dart';
import '../tools/database.dart';
import '../designs/designs.dart';
import '../tools/tools.dart';

/// Represents the Alias Address Page.
class AliasAddressPage extends StatefulWidget {
  const AliasAddressPage({Key? key});

  @override
  AliasAddressPageState createState() => AliasAddressPageState();
}

/// State class for Alias Address Page.
class AliasAddressPageState extends State<AliasAddressPage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<AliasAddress> aliasAddresses = [];

  /// Initializes the state.
  @override
  void initState() {
    _loadItems();
    super.initState();
  }

  /// Handles the press event for creating a new alias.
  void handleCreateNewAliasPress() async {
    List<List<int>> keys = await Wallet().generateAlias();
    List<int> privateKey = keys[0];
    List<int> publicKey = keys[1];

    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expiryTime = currentEpochTime + 60;
    int aliasExpiryTime = currentEpochTime + 86400;

    Map<String, dynamic> data = {
      'request_id': generateUniqueId(),
      'request_expiry_time': expiryTime.toString(),
      'alias_address': base64.encode(publicKey),
      'master_key': base64.encode(await Wallet().getPublicKeyBytes()),
      'alias_expiry_time': aliasExpiryTime.toString()
    };

    // Create API request.
    APIRequest request = APIRequest('/api/add-alias', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    if (!apiResponse.success()) {
      sendToast(apiResponse.getMessage());
    } else {
      await db.insert('AliasAddresses', {
        'PublicKey': hex.encode(publicKey),
        'PrivateKey': hex.encode(privateKey),
        'ExpiryTime': aliasExpiryTime
      });

      sendToast('Alias created successfully!');

      _loadItems();
    }
  }

  /// Handles the press event for deleting an alias.
  Future<void> handleDeleteAliasPress(String aliasAddressHex) async {
    String aliasAddressB64 = base64Encode(hex.decode(aliasAddressHex));

    int currentEpochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int expiryTime = currentEpochTime + 60;

    String uniqueId = generateUniqueId();

    Map<String, dynamic> data = {
      'request_id': uniqueId,
      'request_expiry_time': expiryTime.toString(),
      'alias_address': aliasAddressB64,
      'master_key': base64.encode(await Wallet().getPublicKeyBytes()),
    };

    // Create API request.
    APIRequest request = APIRequest('/api/delete-alias', data);
    await request.sign();
    ApiResponse apiResponse = await request.send();

    if (!apiResponse.success() &&
        apiResponse.getErrorMessage() != 'alias_does_not_exist') {
      sendToast(apiResponse.getMessage());
    } else {
      await db.delete(
        'AliasAddresses',
        where: 'PublicKey = ?',
        whereArgs: [aliasAddressHex],
      );
      await _loadItems();
      sendToast('Alias deleted successfully.');
    }
  }

  /// Builds the Alias Address Page.
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
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: () async => handleCreateNewAliasPress(),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Create New Alias Address',
                      style: TextStyle(
                        fontSize: 1000,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: SizedBox(),
              ),
              Expanded(
                flex: 93,
                child: Container(
                  padding: EdgeInsets.only(
                    left: MediaQuery.of(context).size.height * 0.01,
                    right: MediaQuery.of(context).size.height * 0.01,
                    bottom: MediaQuery.of(context).size.height * 0.02,
                  ),
                  child: aliasAddressSection(),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// Builds the Alias Address section.
  ListView aliasAddressSection() {
    return ListView.builder(
        itemCount: aliasAddresses.length,
        itemBuilder: (context, index) {
          String publicKeyHex = aliasAddresses[index].publicKey;
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
              child: Row(children: <Widget>[
                const Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 60,
                  child: LayoutBuilder(builder: (context, constraints) {
                    double fontSize = constraints.maxHeight * 0.2;
                    return Text(
                      publicKeyHex,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                      ),
                    );
                  }),
                ),
                const Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 10,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: publicKeyHex,
                          ),
                        );
                        sendToast('Alias address copied to clipboard.');
                      },
                      child: LayoutBuilder(builder: (context, constraints) {
                        return SvgPicture.asset(
                          'assets/copy-icon.svg',
                          height: constraints.maxHeight * 0.3
                        );
                      }),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 10,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () async {
                        await handleDeleteAliasPress(publicKeyHex);
                      },
                      child: LayoutBuilder(builder: (context, constraints) {
                        return SvgPicture.asset(
                          'assets/trash-icon.svg',
                          height: constraints.maxHeight * 0.3
                        );
                      }),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
              ]));
        });
  }

  /// Loads alias items.
  Future<void> _loadItems() async {
    final loadedItems = await getAliasAddresses();
    setState(() {
      aliasAddresses = loadedItems;
    });
  }

  /// Gets alias addresses from the database.
  Future<List<AliasAddress>> getAliasAddresses() async {
    List<Map<String, dynamic>> maps = await db.query('AliasAddresses');
    List<AliasAddress> aliasAddresses = [];

    for (Map<String, dynamic> map in maps) {
      aliasAddresses.add(AliasAddress(
        publicKey: map['PublicKey'],
        expiryTime: map['ExpiryTime'].toStringAsFixed(0),
      ));
    }

    return aliasAddresses;
  }
}

/// Represents an Alias Address.
class AliasAddress {
  late final String publicKey;
  late final String expiryTime;

  /// Constructor for Alias Address.
  AliasAddress({
    required this.publicKey,
    required this.expiryTime,
  });
}
