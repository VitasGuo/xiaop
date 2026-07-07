import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/core/dio_client.dart';
import 'package:xiao_p/models/chat_message.dart';
import 'package:xiao_p/models/companion.dart';
import 'package:xiao_p/utils/logger.dart';
import 'package:xiao_p/models/conversation.dart';
import 'package:xiao_p/services/ai_providers.dart';
import 'package:xiao_p/services/api_key_service.dart';
import 'package:xiao_p/services/memory_service.dart';
import 'package:xiao_p/services/web_search_service.dart';
import 'package:dio/dio.dart';

class ChatService {
  static const _keyConversations = 'conversations_list';
  static const _keyPrefix = 'chat_';
  static const _maxMessages = 200;

  // ==================== 对话管理 ====================

  Future<List<Conversation>> getConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyConversations);
    if (json == null) return [];
    final list = Conversation.decodeList(json);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<Conversation> createConversation({String? title}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final conversation = Conversation(
      id: id,
      title: title ?? '新对话',
      createdAt: now,
      updatedAt: now,
    );

    final conversations = await getConversations();
    conversations.insert(0, conversation);
    await _saveConversations(conversations);

    return conversation;
  }

  Future<void> updateConversationTitle(String id, String title) async {
    final conversations = await getConversations();
    final index = conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      conversations[index] = Conversation(
        id: conversations[index].id,
        title: title,
        createdAt: conversations[index].createdAt,
        updatedAt: DateTime.now(),
        messageCount: conversations[index].messageCount,
      );
      await _saveConversations(conversations);
    }
  }

  Future<void> deleteConversation(String id) async {
    final conversations = await getConversations();
    conversations.removeWhere((c) => c.id == id);
    await _saveConversations(conversations);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$id');
  }

  Future<void> togglePin(String id) async {
    final conversations = await getConversations();
    final index = conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      conversations[index] = conversations[index].copyWith(
        isPinned: !conversations[index].isPinned,
      );
      await _saveConversations(conversations);
    }
  }

  Future<void> saveUserMessage(String conversationId, String text) async {
    final userMsg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_u',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    await addMessage(conversationId, userMsg);

    // 自动用第一条消息作为标题
    final messages = await getMessages(conversationId);
    if (messages.length == 1) {
      final title = text.length > 20 ? '${text.substring(0, 20)}...' : text;
      await updateConversationTitle(conversationId, title);
    }

    // 触发定期记忆整合
    MemoryService.checkAndConsolidate();
  }

  Future<void> _saveConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConversations, Conversation.encodeList(conversations));
  }

  Future<void> touchConversation(String id) async {
    final conversations = await getConversations();
    final index = conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = conversations[index];
      conversations[index] = Conversation(
        id: old.id,
        title: old.title,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        messageCount: old.messageCount + 1,
      );
      // 移到最前面
      final updated = conversations.removeAt(index);
      conversations.insert(0, updated);
      await _saveConversations(conversations);
    }
  }

  // ==================== 消息管理 ====================

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_keyPrefix$conversationId');
    if (json == null) return [];
    return ChatMessage.decodeList(json);
  }

  Future<void> addMessage(String conversationId, ChatMessage message) async {
    final messages = await getMessages(conversationId);
    messages.add(message);
    if (messages.length > _maxMessages) {
      messages.removeRange(0, messages.length - _maxMessages);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$conversationId', ChatMessage.encodeList(messages));
  }

  Future<void> clearMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$conversationId');
  }

  // ==================== AI 响应（流式） ====================

  Future<void> streamAiResponse({
    required String conversationId,
    required String userMessage,
    required String providerName,
    required String modelName,
    String? customUrl,
    required Companion companion,
    bool enableThinking = false,
    int contextLength = 20,
    CancelToken? cancelToken,
    required void Function(String token) onToken,
    required void Function(String fullText) onComplete,
    required void Function(String error) onError,
  }) async {
    final provider = AiProviders.getByName(providerName);
    if (provider == null) {
      onError('未找到AI提供商: $providerName');
      return;
    }

    final baseUrl = customUrl?.isNotEmpty == true
        ? customUrl!
        : provider.defaultBaseUrl;

    if (baseUrl.isEmpty) {
      onError('请先填写API地址');
      return;
    }

    String? apiKey;
    if (provider.hasPresetKey) {
      apiKey = provider.presetApiKey;
    } else if (provider.needsApiKey) {
      apiKey = await ApiKeyService.getEffectiveApiKey(provider);
      if (apiKey.isEmpty) {
        onError('请先配置 ${provider.displayName} 的API Key');
        return;
      }
    }

    final memoryContext = await MemoryService.buildMemoryContext(userMessage);

    // 联网搜索 - 根据设置开关决定是否执行
    String searchContext = '';
    final prefs = await SharedPreferences.getInstance();
    final webSearchEnabled = prefs.getBool('web_search_enabled') ?? true;
    if (webSearchEnabled) {
      try {
        final searchService = WebSearchService();
        searchContext = await searchService.search(userMessage).timeout(
          const Duration(seconds: 5),
          onTimeout: () => '',
        );
      } catch (e) {
        Log.w('联网搜索失败: $e');
      }
    }

    final systemPrompt = StringBuffer();
    systemPrompt.writeln(companion.systemPrompt);
    if (!enableThinking) {
      systemPrompt.writeln('');
      systemPrompt.writeln('/no_think 请直接回答，不要展示推理过程。');
    }
    if (memoryContext.isNotEmpty) {
      systemPrompt.writeln('');
      systemPrompt.writeln('以下是关于这个用户的记忆信息，你可以适当参考：');
      systemPrompt.writeln(memoryContext);
    }
    if (searchContext.isNotEmpty) {
      systemPrompt.writeln('');
      systemPrompt.writeln('以下是联网搜索到的相关信息，你可以参考回答用户问题：');
      systemPrompt.writeln(searchContext);
    }

    final messages = await getMessages(conversationId);
    final recentMessages =
        messages.length > contextLength ? messages.sublist(messages.length - contextLength) : messages;

    final dio = createDio(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300),
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final buffer = StringBuffer();

    try {
      final response = await dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
        data: {
          if (modelName.isNotEmpty) 'model': modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt.toString()},
            ...recentMessages.map((m) => {'role': m.role, 'content': m.content}),
          ],
          'temperature': 0.7,
          'max_tokens': 4096,
          'stream': true,
          if (enableThinking) 'reasoning': {'effort': 'high'},
        },
      );

      if (response.statusCode == 200) {
        String leftover = '';
        await for (final chunk in response.data!.stream) {
          leftover += utf8.decode(chunk, allowMalformed: true);
          final lines = leftover.split('\n');
          leftover = lines.removeLast(); // 最后一段可能不完整，保留到下次

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              if (data == '[DONE]') continue;
              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                final choices = json['choices'] as List?;
                if (choices != null && choices.isNotEmpty) {
                  final delta = choices[0]['delta'] as Map<String, dynamic>?;
                  if (delta != null) {
                    final reasoning = delta['reasoning_content'] as String?;
                    if (reasoning != null && reasoning.isNotEmpty) {
                      onToken(reasoning);
                    }
                    if (delta['content'] != null) {
                      final token = delta['content'] as String;
                      buffer.write(token);
                      onToken(token);
                    }
                  }
                }
              } catch (e) {
                Log.w('SSE解析异常: $e');
              }
            }
          }
        }

        onComplete(buffer.toString());
      } else {
        onError('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      // 用户主动取消不报错
      if (e is DioException && e.type == DioExceptionType.cancel) {
        if (buffer.isNotEmpty) {
          onComplete(buffer.toString());
        }
        return;
      }
      if (buffer.isNotEmpty) {
        onComplete(buffer.toString());
      } else {
        String msg = '连接失败';
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            msg = '连接超时';
          } else if (e.type == DioExceptionType.connectionError) {
            msg = '无法连接: $baseUrl';
          } else if (e.response != null) {
            msg = '请求失败: ${e.response?.statusCode}';
          }
        }
        onError(msg);
      }
    }
  }

  // ==================== AI 记忆提取 ====================

  Future<void> extractMemoryWithAI({
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
      }

      final existingMemories = await MemoryService.buildMemoryContext('');

      final prompt = '''你是一个记忆提取助手。分析以下对话，提取值得长期记住的信息。

用户说：$userMessage
AI回复：$aiResponse

已有记忆：
$existingMemories

请提取以下类型的信息（JSON数组格式，每条包含 category、key、value、importance）：
- category: "fact" - 用户的基本事实（名字、职业、年龄、家庭、住址等）
- category: "user_preference" - 用户的喜好（喜欢/讨厌什么、偏好）
- category: "emotion" - 用户的情绪状态
- category: "important_event" - 重要事件
- category: "habit" - 用户的日常习惯
- category: "relationship" - 用户提到的人际关系

importance: 1-5（1=琐碎，5=核心信息）

规则：
1. 只提取明确提到的信息，不要猜测
2. 如果已有相同信息，不要重复
3. 如果信息有更新，覆盖旧信息
4. 每次最多提取3条最重要的信息
5. 无信息可提取时输出空数组 []
6. 必须输出合法的JSON数组

输出格式：
[{"category":"fact","key":"用户名字","value":"小明","importance":3}]''';

      final dio = createDio(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await dio.post(
        '$baseUrl/chat/completions',
        options: Options(headers: headers),
        data: {
          if (modelName.isNotEmpty) 'model': modelName,
          'messages': [
            {'role': 'system', 'content': '你是一个记忆提取助手，只输出JSON数组。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 512,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] as String;
        _parseAndSaveExtractedMemories(content);
      }
    } catch (e) {
      Log.w('AI记忆提取失败: $e');
    }
  }

  Future<void> _parseAndSaveExtractedMemories(String content) async {
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

        await MemoryService.upsertMemory(category, key, value, importance: importance);
      }
    } catch (e) {
      Log.w('解析AI记忆失败: $e');
    }
  }
}
