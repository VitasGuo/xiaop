import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/core/dio_client.dart';
import 'package:xiao_p/services/ai_providers.dart';
import 'package:xiao_p/services/api_key_service.dart';
import 'package:xiao_p/utils/logger.dart';
import 'tool_plugin.dart';

/// 翻译工具 - 复用当前 AI provider 进行翻译，无需额外 API key
class TranslateTool implements ToolPlugin {
  @override
  String get name => 'translate';

  @override
  String get displayName => '翻译';

  @override
  String get description => '文本翻译工具，支持多种语言互译。当用户需要翻译文本时调用。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'text': {
        'type': 'string',
        'description': '要翻译的文本',
      },
      'target_language': {
        'type': 'string',
        'description': '目标语言（如 中文、英文、日本語、한국어、Français）',
      },
    },
    'required': ['text', 'target_language'],
  };

  @override
  ToolCategory get category => ToolCategory.productivity;

  @override
  bool get requiresNetwork => true;

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final text = arguments['text'] as String? ?? '';
    final targetLang = arguments['target_language'] as String? ?? '';
    if (text.isEmpty) return '翻译文本为空';
    if (targetLang.isEmpty) return '目标语言为空';

    try {
      // 从 SharedPreferences 读取当前 AI 配置
      final prefs = await SharedPreferences.getInstance();
      final providerName = prefs.getString('ai_selected_provider') ?? 'lmstudio';
      final provider = AiProviders.getByName(providerName);
      if (provider == null) return '翻译服务不可用: 未知AI提供商';

      final model = prefs.getString('ai_model_$providerName') ?? provider.defaultModel;
      final customUrl = prefs.getString('ai_url_$providerName');
      final baseUrl = customUrl?.isNotEmpty == true ? customUrl! : provider.defaultBaseUrl;
      if (baseUrl.isEmpty) return '翻译服务不可用: 请先配置API地址';

      String? apiKey;
      if (provider.hasPresetKey) {
        apiKey = provider.presetApiKey;
      } else if (provider.needsApiKey) {
        apiKey = await ApiKeyService.getEffectiveApiKey(provider);
        if (apiKey.isEmpty) return '翻译服务不可用: 请先配置API Key';
      }

      final dio = createDio(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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
          if (model.isNotEmpty) 'model': model,
          'messages': [
            {
              'role': 'system',
              'content': '你是一个专业翻译助手。请将用户提供的文本翻译成指定语言，只输出翻译结果，不要添加任何解释或额外内容。'
            },
            {
              'role': 'user',
              'content': '请将以下文本翻译成$targetLang：\n\n$text',
            },
          ],
          'temperature': 0.3,
          'max_tokens': 2048,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] as String;
        return '翻译结果（$targetLang）:\n${content.trim()}';
      }

      return '翻译失败: HTTP ${response.statusCode}';
    } catch (e) {
      Log.w('翻译失败: $e');
      return '翻译服务暂不可用: $e';
    }
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    final targetLang = arguments['target_language'] ?? '';
    return '\n\n> 🌐 翻译: → $targetLang\n\n';
  }
}
