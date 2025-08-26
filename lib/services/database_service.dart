import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/voice_note.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'voice_notes.db';
  static const String _tableName = 'notes';
  static const int _version = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    debugPrint('Database path: $path');
    
    return await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName(
        id TEXT PRIMARY KEY,
        audioPath TEXT NOT NULL,
        transcription TEXT NOT NULL,
        intentDescription TEXT,
        createdAt TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        locationName TEXT
      )
    ''');
    
    debugPrint('Database table created');
  }

  // Insert a new note
  Future<void> insertNote(VoiceNote note) async {
    final db = await database;
    await db.insert(
      _tableName,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Note saved to database: ${note.id}');
  }

  // Get all notes
  Future<List<VoiceNote>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'createdAt DESC',
    );
    
    return List.generate(maps.length, (i) {
      return VoiceNote.fromMap(maps[i]);
    });
  }

  // Get a single note by ID
  Future<VoiceNote?> getNoteById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return VoiceNote.fromMap(maps.first);
    }
    return null;
  }

  // Update a note
  Future<void> updateNote(VoiceNote note) async {
    final db = await database;
    await db.update(
      _tableName,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // Delete a note
  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Search notes by transcription or intent
  Future<List<VoiceNote>> searchNotes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'transcription LIKE ? OR intentDescription LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    
    return List.generate(maps.length, (i) {
      return VoiceNote.fromMap(maps[i]);
    });
  }

  // Get notes by date range
  Future<List<VoiceNote>> getNotesByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'createdAt BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'createdAt DESC',
    );
    
    return List.generate(maps.length, (i) {
      return VoiceNote.fromMap(maps[i]);
    });
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}