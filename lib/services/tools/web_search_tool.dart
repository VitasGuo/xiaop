import 'package:xiao_p/services/web_search_service.dart';
import 'tool_plugin.dart';

/// 联网搜索工具 - 包装现有 WebSearchService
class WebSearchTool implements ToolPlugin {
  @override
  String get name => 'web_search';

  @override
  String get displayName => '联网搜索';

  @override
  String get description => '搜索互联网获取最新信息、新闻、天气、价格等实时数据。当用户询问时效性信息或你不确定的事实时调用此工具。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': '搜索关键词，用简洁的词语描述要查找的内容',
      },
    },
    'required': ['query'],
  };

  @override
  ToolCategory get category => ToolCategory.search;

  @override
  bool get requiresNetwork => true;

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String? ?? '';
    if (query.isEmpty) return '搜索关键词为空';
    final result = await WebSearchService().search(query).timeout(
      const Duration(seconds: 20),
      onTimeout: () => '搜索超时，请基于已有信息回答',
    );
    return result.isEmpty ? '未找到相关结果' : result;
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    final query = arguments['query'] ?? '';
    return '\n\n> 🔍 正在搜索: $query\n\n';
  }
}
