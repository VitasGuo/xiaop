import 'tool_plugin.dart';

/// 当前时间工具
class GetCurrentTimeTool implements ToolPlugin {
  @override
  String get name => 'get_current_time';

  @override
  String get displayName => '当前时间';

  @override
  String get description => '获取当前日期和时间。当用户询问今天日期、当前时间时调用。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  ToolCategory get category => ToolCategory.system;

  @override
  bool get requiresNetwork => false;

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    const weekdays = ['', '一', '二', '三', '四', '五', '六', '日'];
    return '当前时间: ${now.year}年${now.month}月${now.day}日 '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
        '（星期${weekdays[now.weekday]}）';
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    return '\n\n> 🕐 获取当前时间...\n\n';
  }
}
