// lib/data/database_helper.dart
import 'dart:io'; // ✨ ADDED: Needed for the Directory class.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern to ensure only one instance of the database helper is created.
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// Gets the database instance. If it doesn't exist, it initializes it.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ✨ ADDED: A private method to get the persistent storage directory.
  // This directory will NOT be deleted when the app is uninstalled.
  Future<Directory> _getDbDirectory() async {
    // ✨ MODIFIED: Path is now independent of the app's package name to protect against "Clear data".
    final dir = Directory('/storage/emulated/0/.vlt_data');
    if (!(await dir.exists())) {
      // Create the directory if it doesn't exist.
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Initializes the database by opening it and creating tables if they don't exist.
  Future<Database> _initDatabase() async {
    // ✨ MODIFIED: Get the path to our new persistent directory.
    Directory documentsDirectory = await _getDbDirectory();
    String path = join(documentsDirectory.path, 'vault.db');

    // Open the database. The `onCreate` callback is called only the first time
    // the database is created.
    return await openDatabase(
      path,
      version: 2, // ✨ MODIFIED: Incremented version for schema change.
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // ✨ ADDED: Handle database schema upgrades.
    );
  }

  // ✨ ADDED: Handles migrations when the database version increases.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the new sortOrder column to the existing folders table.
      await db.execute(
          'ALTER TABLE folders ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// SQL commands to create the initial tables.
  Future<void> _onCreate(Database db, int version) async {
    // Create the 'folders' table.
    await db.execute('''
      CREATE TABLE folders(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        iconFontFamily TEXT,
        iconFontPackage TEXT,
        color INTEGER NOT NULL,
        parentPath TEXT NOT NULL,
        creationDate TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0 
      )
    ''');

    // Create the 'files' table.
    // INTEGER is used for booleans (0 = false, 1 = true).
    await db.execute('''
      CREATE TABLE files(
        id TEXT PRIMARY KEY,
        fileName TEXT NOT NULL,
        originalPath TEXT NOT NULL,
        dateAdded TEXT NOT NULL,
        isInRecycleBin INTEGER NOT NULL DEFAULT 0,
        deletionDate TEXT,
        originalParentPath TEXT NOT NULL,
        isFavorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}