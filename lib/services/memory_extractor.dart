import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:xiao_p/core/dio_client.dart';
import 'package:xiao_p/models/memory_entry.dart';
import 'package:xiao_p/services/ai_providers.dart';
import 'package:xiao_p/services/api_key_service.dart';
import 'package:xiao_p/services/memory_service.dart';

class MemoryExtractor {
  static final MemoryExtractor _instance = MemoryExtractor._();
  factory MemoryExtractor() => _instance;
  MemoryExtractor._();

  DateTime? _lastConsolidation;
  static const _consolidationInterval = Duration(hours: 6);

  /// 每次对话后调用，AI 提取记忆
  Future<void> extractFromConversation({
    required String userMessage,
    required String aiResponse,
    required String providerName,
    required String modelName,
    String? customUrl,
  }) async {
    try {
      final provider = AiProviders.getByName(providerName);
      if (provider == null) return;

      final baseUrl = customUrl?.isNotEmpty == true
          ? customUrl!
          : provider.defaultBaseUrl;
      if (baseUrl.isEmpty) return;

      String? apiKey;
      if (provider.hasPresetKey) {
        apiKey = provider.presetApiKey;
      } else if (provider.needsApiKey) {
        apiKey = await ApiKeyService.getEffectiveApiKey(provider);
        if (apiKey.isEmpty) return;
      }

      final existingMemories = await MemoryService.buildMemoryContext('');

      final prompt = '''你是一个记忆提取助手。分析以下对话，提取值得记住的信息。

用户说的话：$userMessage
AI的回复：$aiResponse

已有的记忆信息：
$existingMemories

请提取以下类型的信息（JSON数组格式）：
- category: "fact" - 用户的基本事实（名字、职业、年龄、家庭、住址等）
- category: "user_preference" - 用户的喜好（喜欢/讨厌什么、偏好）
- category: "emotion" - 用户的情绪状态（开心/难过/焦虑/疲惫等）
- category: "important_event" - 重要事件（考试、旅行、生日、面试等）
- category: "habit" - 用户的日常习惯（作息、运动、饮食等）
- category: "relationship" - 用户提到的人际关系

每条包含：
- category: 分类
- key: 简短的键名（如"用户名字"、"喜欢的食物"）
- value: 具体内容
- importance: 1-5（1=琐碎，2=一般，3=重要，4=很重要，5=核心信息）

规则：
1. 只提取明确提到的信息，不要猜测
2. 如果已有相同信息，不要重复
3. 如果信息有更新，覆盖旧信息
4. 每次最多提取5条最重要的信息
5. 无信息可提取时输出空数组 []
6. 必须输出合法的JSON数组

输出格式：
[{"category":"fact","key":"用户名字","value":"小明","importance":3}]''';

      final dio = createDio(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      );

      final response = await dio.post(
        '$baseUrl/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': '你是一个记忆提取助手，只输出JSON。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 1024,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] as String;
        _parseAndSaveMemories(content);
      }
    } catch (_) {}
  }

  void _parseAndSaveMemories(String content) async {
    try {
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
      if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
      if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      jsonStr = jsonStr.trim();

      final List<dynamic> memories = jsonDecode(jsonStr);
      for (final item in memories) {
        final map = item as Map<String, dynamic>;
        final category = map['category'] as String;
        final key = map['key'] as String;
        final value = map['value'] as String;
        final importance = (map['importance'] as num?)?.toInt() ?? 2;

        // 高重要性记忆提升为 L1
        final level = importance >= 3 ? MemoryLevel.l1 : MemoryLevel.l2;

        await MemoryService.upsertMemory(category, key, value,
            importance: importance, level: level);
      }
    } catch (_) {}
  }

  /// 定期整合记忆：提升、衰减、归档
  Future<void> consolidateMemories({
    required String providerName,
    required String modelName,
    String? customUrl,
  }) async {
    if (_lastConsolidation != null &&
        DateTime.now().difference(_lastConsolidation!) < _consolidationInterval) {
      return;
    }

    // 先执行本地规则整合
    await MemoryService.consolidateMemories();

    // 再用 AI 做深度整合
    try {
      final provider = AiProviders.getByName(providerName);
      if (provider == null) return;

      final baseUrl = provider.isCustom
          ? (customUrl?.isNotEmpty == true ? customUrl! : provider.defaultBaseUrl)
          : provider.defaultBaseUrl;
      if (baseUrl.isEmpty) return;

      final apiKey = await ApiKeyService.getEffectiveApiKey(provider);
      if (apiKey.isEmpty) return;

      final allMemories = await MemoryService.getAllMemories();
      if (allMemories.isEmpty) return;

      final memoriesText = allMemories.map((m) =>
          '[${m.category}] ${m.key}: ${m.value} (重要性:${m.importance}, 层级:L${m.level.index}, 召回:${m.recallCount})'
      ).join('\n');

      final prompt = '''你是一个记忆整合助手。分析以下记忆列表，执行整合操作：

1. 合并重复或相似的记忆（如"喜欢苹果"和"喜欢吃苹果"合并）
2. 删除过时或不再重要的记忆
3. 更新重要性评分

当前记忆：
$memoriesText

请输出需要执行的操作（JSON数组格式）：
- {"action": "delete", "id": 记忆ID} - 删除记忆
- {"action": "update_importance", "id": 记忆ID, "importance": 新重要性} - 更新重要性
- {"action": "upsert", "category": "分类", "key": "键", "value": "值", "importance": 重要性} - 新增/更新

规则：
1. 只输出需要变更的操作
2. 没有需要变更的就输出空数组 []
3. 必须输出合法的JSON数组''';

      final dio = createDio(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      );

      final response = await dio.post(
        '$baseUrl/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': '你是一个记忆整合助手，只输出JSON。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 1024,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] as String;
        _parseAndExecuteConsolidation(content);
        _lastConsolidation = DateTime.now();
      }
    } catch (_) {}
  }

  void _parseAndExecuteConsolidation(String content) async {
    try {
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
      if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
      if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      jsonStr = jsonStr.trim();

      final List<dynamic> actions = jsonDecode(jsonStr);
      for (final item in actions) {
        final map = item as Map<String, dynamic>;
        final action = map['action'] as String;

        if (action == 'delete' && map['id'] != null) {
          await MemoryService.deleteMemory(map['id'] as int);
        } else if (action == 'update_importance' && map['id'] != null) {
          final id = map['id'] as int;
          final importance = (map['importance'] as num?)?.toInt() ?? 1;
          final db = await MemoryService.database;
          await db.update(
            'memories',
            {'importance': importance},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else if (action == 'upsert') {
          await MemoryService.upsertMemory(
            map['category'] as String,
            map['key'] as String,
            map['value'] as String,
            importance: (map['importance'] as num?)?.toInt() ?? 2,
          );
        }
      }
    } catch (_) {}
  }
}
