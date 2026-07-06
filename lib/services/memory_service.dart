import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/models/memory_entry.dart';
import 'package:xiao_p/utils/logger.dart';

class MemoryService {
  static Database? _database;
  static const _keyLastConsolidation = 'memory_last_consolidation';
  static const _consolidationInterval = Duration(hours: 6);

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'xiao_p_memory.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            importance INTEGER DEFAULT 1,
            level INTEGER DEFAULT 2,
            recall_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_memories_category ON memories(category)');
        await db.execute('CREATE INDEX idx_memories_level ON memories(level)');
        await db.execute('CREATE INDEX idx_memories_importance ON memories(importance DESC)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE memories ADD COLUMN level INTEGER DEFAULT 2');
          await db.execute('ALTER TABLE memories ADD COLUMN recall_count INTEGER DEFAULT 0');
          await db.execute('CREATE INDEX idx_memories_level ON memories(level)');
        }
      },
    );
  }

  // ==================== 基础 CRUD ====================

  static Future<int> insertMemory(MemoryEntry entry) async {
    final db = await database;
    return await db.insert('memories', entry.toMap());
  }

  static Future<List<MemoryEntry>> getAllMemories() async {
    final db = await database;
    final maps = await db.query('memories', orderBy: 'level ASC, importance DESC, updated_at DESC');
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  static Future<List<MemoryEntry>> getMemoriesByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'memories',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'importance DESC, updated_at DESC',
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  static Future<List<MemoryEntry>> searchMemories(String query) async {
    final db = await database;
    final maps = await db.query(
      'memories',
      where: 'key LIKE ? OR value LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'importance DESC, updated_at DESC',
      limit: 20,
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  static Future<MemoryEntry?> findMemory(String category, String key) async {
    final db = await database;
    final maps = await db.query(
      'memories',
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MemoryEntry.fromMap(maps.first);
  }

  static Future<void> upsertMemory(String category, String key, String value,
      {int importance = 1, MemoryLevel level = MemoryLevel.l2}) async {
    final existing = await findMemory(category, key);
    final now = DateTime.now();
    if (existing != null) {
      final db = await database;
      await db.update(
        'memories',
        {
          'value': value,
          'importance': importance,
          'level': level.index,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await insertMemory(MemoryEntry(
        category: category,
        key: key,
        value: value,
        importance: importance,
        level: level,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  static Future<void> deleteMemory(int id) async {
    final db = await database;
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteMemoriesByCategory(String category) async {
    final db = await database;
    await db.delete('memories', where: 'category = ?', whereArgs: [category]);
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('memories');
  }

  // ==================== 分层记忆查询 ====================

  /// L1: 长期记忆 - 高重要性的沉淀认知
  static Future<List<MemoryEntry>> getLongTermMemories() async {
    final db = await database;
    final maps = await db.query(
      'memories',
      where: 'level <= 1',
      orderBy: 'importance DESC',
      limit: 50,
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  /// L2: 热记忆 - 最近2天的记忆
  static Future<List<MemoryEntry>> getHotMemories() async {
    final db = await database;
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
    final maps = await db.query(
      'memories',
      where: 'updated_at >= ?',
      whereArgs: [twoDaysAgo],
      orderBy: 'importance DESC, updated_at DESC',
      limit: 30,
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  /// L3: 温记忆 - 3-7天前，按需检索
  static Future<List<MemoryEntry>> getWarmMemories() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
    final maps = await db.query(
      'memories',
      where: 'updated_at >= ? AND updated_at < ?',
      whereArgs: [sevenDaysAgo, twoDaysAgo],
      orderBy: 'importance DESC',
      limit: 30,
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  /// 记忆被召回时增加 recall_count
  static Future<void> incrementRecall(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE memories SET recall_count = recall_count + 1, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  // ==================== 记忆上下文构建 ====================

  static Future<String> buildMemoryContext(String recentConversation) async {
    final buffer = StringBuffer();

    // L1: 长期记忆 - 最重要
    final longTerm = await getLongTermMemories();
    if (longTerm.isNotEmpty) {
      buffer.writeln('【长期记忆】');
      for (final m in longTerm.take(15)) {
        buffer.writeln('${m.key}: ${m.value}');
      }
    }

    // L2: 热记忆
    final hot = await getHotMemories();
    if (hot.isNotEmpty) {
      buffer.writeln('【近期记忆】');
      for (final m in hot.take(10)) {
        buffer.writeln('${m.key}: ${m.value}');
      }
    }

    // 按分类补充
    final userPrefs = await getMemoriesByCategory('user_preference');
    if (userPrefs.isNotEmpty) {
      buffer.writeln('【用户偏好】');
      for (final m in userPrefs.take(8)) {
        buffer.writeln('${m.key}: ${m.value}');
      }
    }

    final emotions = await getMemoriesByCategory('emotion');
    if (emotions.isNotEmpty) {
      buffer.writeln('【情绪记录】');
      for (final m in emotions.take(5)) {
        buffer.writeln('${m.key}: ${m.value}');
      }
    }

    final facts = await getMemoriesByCategory('fact');
    if (facts.isNotEmpty) {
      buffer.writeln('【已知事实】');
      for (final m in facts.take(10)) {
        buffer.writeln('${m.key}: ${m.value}');
      }
    }

    return buffer.toString();
  }

  // ==================== 记忆整合与归档 ====================

  /// 记忆整合：将热记忆提升为长期记忆，衰减旧记忆的重要性
  static Future<void> consolidateMemories() async {
    final db = await database;

    // 1. 将高重要性、高召回次数的热记忆提升为 L1
    await db.rawUpdate('''
      UPDATE memories
      SET level = 1
      WHERE level >= 2
        AND importance >= 3
        AND recall_count >= 2
    ''');

    // 2. 衰减7天以上未更新的记忆的重要性
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.rawUpdate('''
      UPDATE memories
      SET importance = MAX(1, importance - 1)
      WHERE updated_at < ?
        AND importance > 1
        AND level > 1
    ''', [sevenDaysAgo]);

    // 3. 将30天以上、重要性为1的记忆降级为 L4
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await db.rawUpdate('''
      UPDATE memories
      SET level = 4
      WHERE updated_at < ?
        AND importance <= 1
        AND level < 4
    ''', [thirtyDaysAgo]);

    // 4. 删除 L4 中90天以上的记忆
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    await db.delete(
      'memories',
      where: 'level = 4 AND updated_at < ?',
      whereArgs: [ninetyDaysAgo],
    );
  }

  /// 检查并执行定期整合（每6小时一次）
  static Future<void> checkAndConsolidate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString(_keyLastConsolidation);
      final lastTime = lastStr != null ? DateTime.tryParse(lastStr) : null;

      if (lastTime != null && DateTime.now().difference(lastTime) < _consolidationInterval) {
        return; // 还没到下次整合时间
      }

      Log.d('执行记忆整合...');
      await consolidateMemories();
      await prefs.setString(_keyLastConsolidation, DateTime.now().toIso8601String());
      Log.d('记忆整合完成');
    } catch (e) {
      Log.w('记忆整合失败: $e');
    }
  }
}
