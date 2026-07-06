import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:xiao_p/models/chat_message.dart';

class MessageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'xiao_p_messages.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversation_id)',
        );
      },
    );
  }

  static Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 200}) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => ChatMessage(
      id: m['id'] as String,
      role: m['role'] as String,
      content: m['content'] as String,
      timestamp: DateTime.parse(m['timestamp'] as String),
    )).toList();
  }

  static Future<void> addMessage(String conversationId, ChatMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        'id': message.id,
        'conversation_id': conversationId,
        'role': message.role,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM messages WHERE conversation_id = ?',
      [conversationId],
    ));
    if (count != null && count > 200) {
      await db.rawDelete('''
        DELETE FROM messages WHERE conversation_id = ? AND id NOT IN (
          SELECT id FROM messages WHERE conversation_id = ? ORDER BY timestamp DESC LIMIT 200
        )
      ''', [conversationId, conversationId]);
    }
  }

  static Future<void> clearMessages(String conversationId) async {
    final db = await database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [conversationId]);
  }
}
