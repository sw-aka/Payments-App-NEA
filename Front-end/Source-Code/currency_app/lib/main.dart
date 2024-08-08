// Importing necessary packages
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqlite;
import 'dart:core';

// Importing project-specific modules
import 'tools/toast.dart';
import 'tools/wallet.dart';
import 'tools/database.dart';
import 'pages/homePage.dart';

// Entry point of the application
void main() async {
  // Initializing the wallet
  await Wallet().initialize();

  // Ensuring Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initializing SQLite database
  sqlite.sqfliteFfiInit();
  sqlite.databaseFactory = sqlite.databaseFactoryFfi;

  // Creating a database helper instance
  var dbHelper = DatabaseHelper();
  db = await dbHelper.database;

  // Running the Flutter app
  runApp(const MyApp());

  // Configuring window settings
  doWhenWindowReady(() {
    // Setting initial window size
    const initialSize = ui.Size(378, 812);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.bottomRight;
    appWindow.position = const Offset(10, 10);
    appWindow.title = "Currency App";
    appWindow.show();
  });
}

// Main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Setting the toast context for displaying messages
    toastContext = context;

    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
