import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    String path = join(dbPath, 'enclaves.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        enclave_id INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE enclaves (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_member INTEGER NOT NULL DEFAULT 0,
        created_by_me INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertMessage(String content, int enclaveId) async {
    Database db = await instance.database;
    return await db.insert(
      'messages',
      {
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'enclave_id': enclaveId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(int enclaveId) async {
    Database db = await instance.database;
    return await db.query(
      'messages',
      where: 'enclave_id = ?',
      whereArgs: [enclaveId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<int> createEnclave(String name, String description) async {
    Database db = await instance.database;
    return await db.insert(
      'enclaves',
      {
        'name': name,
        'description': description,
        'is_member': 1,  // The creator is automatically a member
        'created_by_me': 1,  // Mark as created by the current user
      },
    );
  }

  Future<List<Map<String, dynamic>>> getEnclaves() async {
    Database db = await instance.database;
    return await db.query('enclaves', orderBy: 'name ASC');
  }

  Future<void> joinEnclave(int enclaveId) async {
    Database db = await instance.database;
    await db.update(
      'enclaves',
      {'is_member': 1},
      where: 'id = ?',
      whereArgs: [enclaveId],
    );
  }

  // New method to delete an enclave and its associated messages
  Future<void> deleteEnclave(int enclaveId) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'messages',
        where: 'enclave_id = ?',
        whereArgs: [enclaveId],
      );
      await txn.delete(
        'enclaves',
        where: 'id = ?',
        whereArgs: [enclaveId],
      );
    });
  }
}
