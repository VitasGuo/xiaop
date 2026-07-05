import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/core/dio_client.dart';
import 'package:xiao_p/models/chat_message.dart';
import 'package:xiao_p/models/companion.dart';
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

    // 联网搜索 - 仅对可能需要搜索的问题执行，且并行不阻塞
    String searchContext = '';
    try {
      final searchService = WebSearchService();
      searchContext = await searchService.search(userMessage).timeout(
        const Duration(seconds: 5),
        onTimeout: () => '',
      );
    } catch (_) {}

    final systemPrompt = StringBuffer();
    systemPrompt.writeln(companion.systemPrompt);
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
        messages.length > 10 ? messages.sublist(messages.length - 10) : messages;

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
        data: {
          if (modelName.isNotEmpty) 'model': modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt.toString()},
            ...recentMessages.map((m) => {'role': m.role, 'content': m.content}),
          ],
          'temperature': 0.7,
          'max_tokens': 4096,
          'stream': true,
          if (enableThinking) 'thinking': {'type': 'enabled'},
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
              } catch (_) {}
            }
          }
        }

        onComplete(buffer.toString());
      } else {
        onError('请求失败: ${response.statusCode}');
      }
    } catch (e) {
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

}
