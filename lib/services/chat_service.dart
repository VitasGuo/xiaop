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

  // ==================== AI 响应（流式 + Agent Loop） ====================

  /// 工具定义 schema（OpenAI 兼容 function calling 格式）
  static const _toolDefinitions = [
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description': '搜索互联网获取最新信息、新闻、天气、价格等实时数据。当用户询问时效性信息或你不确定的事实时调用此工具。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': '搜索关键词，用简洁的词语描述要查找的内容',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_current_time',
        'description': '获取当前日期和时间。当用户询问今天日期、当前时间时调用。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
  ];

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
    void Function(String toolName, String args)? onToolCall,
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

    final prefs = await SharedPreferences.getInstance();
    final webSearchEnabled = prefs.getBool('web_search_enabled') ?? true;

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
    // 引导 AI 使用工具
    if (provider.supportsToolUse && webSearchEnabled) {
      systemPrompt.writeln('');
      systemPrompt.writeln('你可以使用工具来获取实时信息。当需要最新资讯、天气、价格等时效性信息时，请调用 web_search 工具。当需要当前日期时间时，请调用 get_current_time 工具。不需要时直接回答即可。');
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

    // 构建 API 消息列表（循环中会追加 tool 消息）
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt.toString()},
      ...recentMessages.map((m) => {'role': m.role, 'content': m.content}),
    ];

    final fullBuffer = StringBuffer();

    // ===== 路径 A：支持 Function Calling → Agent Loop =====
    if (provider.supportsToolUse && webSearchEnabled) {
      const maxIterations = 5;
      for (var iteration = 0; iteration < maxIterations; iteration++) {
        final result = await _streamRequest(
          dio: dio,
          url: '$baseUrl/chat/completions',
          headers: headers,
          modelName: modelName,
          messages: apiMessages,
          enableThinking: enableThinking,
          tools: _toolDefinitions,
          cancelToken: cancelToken,
          onToken: onToken,
        );

        if (result.error != null) {
          if (fullBuffer.isNotEmpty) {
            onComplete(fullBuffer.toString());
          } else {
            onError(result.error!);
          }
          return;
        }

        // 累积内容
        if (result.content.isNotEmpty) {
          fullBuffer.write(result.content);
        }

        // 有工具调用 → 执行并循环
        if (result.toolCalls.isNotEmpty) {
          // 把 assistant 消息（含 tool_calls）加入上下文
          final assistantMsg = <String, dynamic>{
            'role': 'assistant',
            if (result.content.isNotEmpty) 'content': result.content,
            'tool_calls': result.toolCalls.map((tc) => tc.toApiJson()).toList(),
          };
          apiMessages.add(assistantMsg);

          // 执行每个工具调用
          for (final tc in result.toolCalls) {
            final toolResult = await _executeTool(tc.name, tc.arguments);
            apiMessages.add({
              'role': 'tool',
              'tool_call_id': tc.id,
              'content': toolResult,
            });
            // UI 反馈
            if (onToolCall != null) {
              onToolCall(tc.name, tc.arguments);
            }
          }
          // 继续循环，让 AI 看到工具结果后继续
          continue;
        }

        // 无工具调用 → 完成
        onComplete(fullBuffer.toString());
        return;
      }
      // 超过最大轮数
      if (fullBuffer.isNotEmpty) {
        onComplete(fullBuffer.toString());
      } else {
        onError('工具调用轮数超限');
      }
      return;
    }

    // ===== 路径 B：不支持 Function Calling → 规则触发搜索 =====
    String searchContext = '';
    if (webSearchEnabled && _needsWebSearch(userMessage)) {
      try {
        final searchService = WebSearchService();
        final searchQuery = _extractSearchQuery(userMessage);
        Log.d('联网搜索触发(规则): "$searchQuery"');
        searchContext = await searchService.search(searchQuery).timeout(
          const Duration(seconds: 8),
          onTimeout: () => '',
        );
      } catch (e) {
        Log.w('联网搜索失败: $e');
      }
    }

    if (searchContext.isNotEmpty) {
      apiMessages.insert(1, {
        'role': 'system',
        'content': '以下是联网搜索到的相关信息，你可以参考回答用户问题：\n$searchContext',
      });
    }

    final result = await _streamRequest(
      dio: dio,
      url: '$baseUrl/chat/completions',
      headers: headers,
      modelName: modelName,
      messages: apiMessages,
      enableThinking: enableThinking,
      tools: null,
      cancelToken: cancelToken,
      onToken: onToken,
    );

    if (result.error != null) {
      if (result.content.isNotEmpty) {
        onComplete(result.content);
      } else {
        onError(result.error!);
      }
    } else {
      onComplete(result.content);
    }
  }

  /// 执行单次流式请求，解析 SSE
  Future<_StreamResult> _streamRequest({
    required Dio dio,
    required String url,
    required Map<String, String> headers,
    required String modelName,
    required List<Map<String, dynamic>> messages,
    required bool enableThinking,
    required List<Map<String, dynamic>>? tools,
    CancelToken? cancelToken,
    required void Function(String token) onToken,
  }) async {
    final contentBuffer = StringBuffer();
    final toolCallAccumulator = <int, _ToolCallBuilder>{};
    String? finishReason;

    try {
      final response = await dio.post(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
        data: {
          if (modelName.isNotEmpty) 'model': modelName,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 4096,
          'stream': true,
          // ignore: use_null_aware_elements
          if (tools != null) 'tools': tools,
          if (enableThinking) 'reasoning': {'effort': 'high'},
        },
      );

      if (response.statusCode != 200) {
        return _StreamResult(error: '请求失败: ${response.statusCode}');
      }

      String leftover = '';
      await for (final chunk in response.data!.stream) {
        leftover += utf8.decode(chunk, allowMalformed: true);
        final lines = leftover.split('\n');
        leftover = lines.removeLast();

        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') continue;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices == null || choices.isEmpty) continue;
            final choice = choices[0] as Map<String, dynamic>;
            final delta = choice['delta'] as Map<String, dynamic>?;
            final reason = choice['finish_reason'] as String?;
            if (reason != null) finishReason = reason;

            if (delta == null) continue;

            // 推理内容
            final reasoning = delta['reasoning_content'] as String?;
            if (reasoning != null && reasoning.isNotEmpty) {
              onToken(reasoning);
            }

            // 正文内容
            final content = delta['content'] as String?;
            if (content != null) {
              contentBuffer.write(content);
              onToken(content);
            }

            // 工具调用（流式分片，需按 index 累积）
            final toolCalls = delta['tool_calls'] as List?;
            if (toolCalls != null) {
              for (final tc in toolCalls) {
                final tcMap = tc as Map<String, dynamic>;
                final index = tcMap['index'] as int? ?? 0;
                final builder = toolCallAccumulator.putIfAbsent(index, () => _ToolCallBuilder());

                final id = tcMap['id'] as String?;
                if (id != null) builder.id = id;

                final fn = tcMap['function'] as Map<String, dynamic>?;
                if (fn != null) {
                  final name = fn['name'] as String?;
                  if (name != null) builder.name = name;
                  final args = fn['arguments'] as String?;
                  if (args != null) builder.arguments += args;
                }
              }
            }
          } catch (e) {
            Log.w('SSE解析异常: $e');
          }
        }
      }

      // 构建工具调用列表
      final parsedToolCalls = <_ToolCall>[];
      if (toolCallAccumulator.isNotEmpty) {
        final sortedKeys = toolCallAccumulator.keys.toList()..sort();
        for (final key in sortedKeys) {
          final builder = toolCallAccumulator[key]!;
          if (builder.name != null) {
            parsedToolCalls.add(_ToolCall(
              id: builder.id ?? 'call_$key',
              name: builder.name!,
              arguments: builder.arguments,
            ));
          }
        }
      }

      return _StreamResult(
        content: contentBuffer.toString(),
        toolCalls: parsedToolCalls,
        finishReason: finishReason,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return _StreamResult(content: contentBuffer.toString());
      }
      String msg = '连接失败';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = '连接超时';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = '无法连接';
      } else if (e.response != null) {
        msg = '请求失败: ${e.response?.statusCode}';
      }
      return _StreamResult(content: contentBuffer.toString(), error: msg);
    } catch (e) {
      return _StreamResult(content: contentBuffer.toString(), error: '连接失败: $e');
    }
  }

  /// 执行工具调用，返回结果文本
  Future<String> _executeTool(String name, String arguments) async {
    try {
      final args = arguments.isNotEmpty
          ? jsonDecode(arguments) as Map<String, dynamic>
          : <String, dynamic>{};

      switch (name) {
        case 'web_search':
          final query = args['query'] as String? ?? '';
          if (query.isEmpty) return '搜索关键词为空';
          Log.d('工具调用 web_search: "$query"');
          final result = await WebSearchService().search(query).timeout(
            const Duration(seconds: 10),
            onTimeout: () => '搜索超时',
          );
          return result.isEmpty ? '未找到相关结果' : result;

        case 'get_current_time':
          final now = DateTime.now();
          return '当前时间: ${now.year}年${now.month}月${now.day}日 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}（星期${_weekday(now.weekday)}）';

        default:
          return '未知工具: $name';
      }
    } catch (e) {
      Log.w('工具执行失败: $e');
      return '工具执行失败: $e';
    }
  }

  String _weekday(int n) {
    const map = ['', '一', '二', '三', '四', '五', '六', '日'];
    return map[n];
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

  /// 判断用户消息是否需要联网搜索
  /// 情感陪伴场景下大部分对话不需要搜索，仅当时效性/事实性问题时触发
  static const _factKeywords = [
    '最新', '今天', '昨天', '明天', '近期', '最近', '现在', '当前', '实时',
    '新闻', '天气', '温度', '预报',
    '价格', '多少钱', '股价', '汇率', '利率',
    '发布', '更新', '上线', '出',
    '比分', '排名', '排行', '赛果',
    '2024', '2025', '2026',
  ];

  static const _searchIntents = [
    '搜索', '搜一下', '查一下', '帮我查', '帮我搜', '联网', '查询', '查找',
  ];

  static const _factQuestions = [
    '几点', '什么时候', '在哪', '哪里', '是多少', '多少钱',
    '是谁', '什么是', '怎么回事',
  ];

  bool _needsWebSearch(String message) {
    // 明确搜索意图
    for (final kw in _searchIntents) {
      if (message.contains(kw)) return true;
    }
    // 时效/事实关键词
    for (final kw in _factKeywords) {
      if (message.contains(kw)) return true;
    }
    // 事实性疑问
    for (final kw in _factQuestions) {
      if (message.contains(kw)) return true;
    }
    return false;
  }

  /// 从用户消息提取搜索关键词
  String _extractSearchQuery(String message) {
    // 去掉标点和常见语气词，截取有效部分
    var query = message
        .replaceAll(RegExp(r'[，。！？、…~\s]+$'), '')
        .replaceAll(RegExp(r'^[，。！？、…~\s]+'), '');

    // 去掉搜索意图前缀
    for (final prefix in ['帮我搜一下', '帮我搜索', '帮我查一下', '帮我查', '搜一下', '搜索', '查一下', '查询', '查找']) {
      if (query.startsWith(prefix)) {
        query = query.substring(prefix.length).trim();
        break;
      }
    }

    // 限制长度，避免搜索词过长
    if (query.length > 60) {
      query = query.substring(0, 60);
    }
    return query.isEmpty ? message : query;
  }
}

/// 单次流式请求的结果
class _StreamResult {
  final String content;
  final List<_ToolCall> toolCalls;
  final String? finishReason;
  final String? error;

  _StreamResult({
    this.content = '',
    this.toolCalls = const [],
    this.finishReason,
    this.error,
  });
}

/// 解析后的工具调用
class _ToolCall {
  final String id;
  final String name;
  final String arguments;

  _ToolCall({required this.id, required this.name, required this.arguments});

  Map<String, dynamic> toApiJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': arguments},
  };
}

/// 流式 tool_calls 累积构建器（按 index 拼装分片）
class _ToolCallBuilder {
  String? id;
  String? name;
  String arguments = '';
}
