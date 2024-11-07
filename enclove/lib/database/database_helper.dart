import 'dart:async';
import 'package:sqlite_crdt/sqlite_crdt.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static SqliteCrdt? _database;


  DatabaseHelper._privateConstructor();

  Future<SqliteCrdt> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<SqliteCrdt> _initDatabase() async {
    // Initialize CRDT database and return it
    return await SqliteCrdt.openInMemory(
        version: 1,
        onCreate: (db, version) async {
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

      await db.execute('''
        CREATE TABLE pins (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          enclave_id INTEGER,
          latitude REAL,
          longitude REAL,
          description TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          requires_approval INTEGER NOT NULL DEFAULT 0
        )
      ''');
    });
  }

  Future<void> joinPin(int pinId) async {
    final db = await instance.database;

    await db.execute(
      'UPDATE pins SET is_joined = 1 WHERE id = ?',
      [pinId],
    );
  }

  Future<void> insertMessage(String content, int enclaveId) async {
    final db = await instance.database;

    await db.execute(
      'INSERT INTO messages (content, timestamp, enclave_id) VALUES (?, ?, ?)',
      [content, DateTime.now().toIso8601String(), enclaveId],
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(int enclaveId) async {
    final db = await instance.database;

    final results = await db.query(
      'SELECT * FROM messages WHERE enclave_id = ? ORDER BY timestamp ASC',
      [enclaveId],
    );

    return results;
  }

  Future<void> createEnclave(String name, String description) async {
    final db = await instance.database;

    await db.execute(
      'INSERT INTO enclaves (name, description, is_member, created_by_me) VALUES (?, ?, 1, 1)',
      [name, description],
    );
  }

  Future<List<Map<String, dynamic>>> getEnclaves() async {
    final db = await instance.database;

    final results = await db.query(
      'SELECT * FROM enclaves ORDER BY name ASC',
    );

    return results;
  }

  Future<void> joinEnclave(String enclaveName) async {
    final db = await instance.database;

    // Check if the enclave already exists
    final existingEnclave = await db.query(
      'SELECT * FROM enclaves WHERE name = ?',
      [enclaveName],
    );

    if (existingEnclave.isEmpty) {
      // Insert the new enclave if it doesn't exist
      await db.execute(
        'INSERT INTO enclaves (name, is_member, created_by_me) VALUES (?, 1, 0)',
        [enclaveName],
      );
    }
  }

  // New method to delete an enclave and its associated messages
  Future<void> deleteEnclave(int enclaveId) async {
    final db = await instance.database;

    await db.execute(
      'DELETE FROM messages WHERE enclave_id = ?',
      [enclaveId],
    );

    await db.execute(
      'DELETE FROM enclaves WHERE id = ?',
      [enclaveId],
    );
  }

  Future<void> addPin(int enclaveId, double latitude, double longitude, String description) async {
    final db = await instance.database;

    await db.execute(
      'INSERT INTO pins (enclave_id, latitude, longitude, description) VALUES (?, ?, ?, ?)',
      [enclaveId, latitude, longitude, description],
    );
  }

  Future<List<Map<String, dynamic>>> getPins(int enclaveId) async {
    final db = await instance.database;

    final results = await db.query(
      'SELECT * FROM pins WHERE enclave_id = ?',
      [enclaveId],
    );

    return results;
  }
}
