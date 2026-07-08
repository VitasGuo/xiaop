/// 工具插件接口 - 所有工具实现此接口
abstract class ToolPlugin {
  /// 工具唯一标识（如 'web_search'）
  String get name;

  /// 展示名称（如 '联网搜索'）
  String get displayName;

  /// 工具描述（给 AI 看，决定是否调用）
  String get description;

  /// OpenAI Function Calling 参数 schema
  Map<String, dynamic> get parametersSchema;

  /// 工具类别（用于 UI 分组）
  ToolCategory get category;

  /// 是否需要网络
  bool get requiresNetwork;

  /// 执行工具，返回结果文本（回传给 AI）
  Future<String> execute(Map<String, dynamic> arguments);

  /// 格式化 UI 提示（在聊天气泡中显示）
  /// 如 "🔍 正在搜索: xxx"，返回 null 则用默认提示
  String? formatUiHint(Map<String, dynamic> arguments) => null;
}

/// 工具类别
enum ToolCategory {
  search('搜索'),
  utility('实用'),
  productivity('效率'),
  system('系统');

  final String label;
  const ToolCategory(this.label);
}
