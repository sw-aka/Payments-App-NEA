// Import statements
import 'dart:core';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Class providing database functionalities
class DatabaseHelper {
  static Database? _database;

  /// Getter for the database instance
  Future<Database> get database async {
    // Check if the database instance already exists
    if (_database != null) {
      return _database!;
    }

    // If not, initialize and return the database instance
    _database = await initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> initDatabase() async {
    // Define the database file path
    String path = p.join(await getDatabasesPath(), 'my_database.db');
    // Open the database with specified version and onCreate callback
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  /// Database creation callback
  Future<void> _onCreate(Database db, int version) async {
    // Create TransactionHistory table
    await db.execute('''
      CREATE TABLE TransactionHistory (
        TransactionID CHAR(32) PRIMARY KEY,
        TransactionType TEXT NOT NULL,
        Amount DECIMAL(20, 5) NOT NULL,
        ExpiryTime BIGINT NOT NULL,
        Status TEXT NOT NULL
      )
    ''');

    // Create TransferHistory table
    await db.execute('''
      CREATE TABLE TransferHistory (
        PublicKey TEXT NOT NULL,
        Amount DECIMAL(20, 5) NOT NULL,
        TransactionTime BIGINT NOT NULL
      )
    ''');

    // Create AliasAddresses table
    await db.execute('''
      CREATE TABLE AliasAddresses (
        PublicKey TEXT PRIMARY KEY,
        PrivateKey TEXT NOT NULL,
        ExpiryTime BIGINT NOT NULL
      )
    ''');
  }

  /// Delete the database file
  Future<void> deleteDatabaseFile() async {
    // Get the database file path
    String path = p.join(await getDatabasesPath(), 'my_database.db');
    // Delete the database file
    await deleteDatabase(path);
  }
}

// Database instance
late final Database db;
