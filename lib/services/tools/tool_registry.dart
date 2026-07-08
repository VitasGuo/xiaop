import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/utils/logger.dart';
import 'tool_plugin.dart';
import 'web_search_tool.dart';
import 'get_current_time_tool.dart';
import 'get_location_tool.dart';
import 'weather_tool.dart';
import 'exchange_rate_tool.dart';
import 'calculator_tool.dart';
import 'translate_tool.dart';

/// 工具注册中心 - 单例，管理所有工具的注册、查询、执行
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._();
  factory ToolRegistry() => _instance;
  ToolRegistry._();

  final Map<String, ToolPlugin> _tools = {};
  bool _builtinRegistered = false;

  /// 注册工具
  void register(ToolPlugin tool) {
    _tools[tool.name] = tool;
    Log.d('工具已注册: ${tool.name} (${tool.displayName})');
  }

  /// 注册内置工具（启动时调用一次）
  void registerBuiltin() {
    if (_builtinRegistered) return;
    _builtinRegistered = true;
    register(WebSearchTool());
    register(GetCurrentTimeTool());
    register(GetLocationTool());
    register(WeatherTool());
    register(ExchangeRateTool());
    register(CalculatorTool());
    register(TranslateTool());
  }

  /// 获取所有已注册工具
  List<ToolPlugin> get allTools => _tools.values.toList();

  /// 获取已启用工具的 schema（传给 AI 的 tools 参数）
  /// 读取 SharedPreferences 中每个工具的启用状态，默认启用
  Future<List<Map<String, dynamic>>> getEnabledSchemas() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <Map<String, dynamic>>[];
    for (final tool in _tools.values) {
      final enabled = prefs.getBool('tool_enabled_${tool.name}') ?? true;
      if (enabled) {
        result.add({
          'type': 'function',
          'function': {
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.parametersSchema,
          },
        });
      }
    }
    return result;
  }

  /// 执行工具调用
  Future<String> execute(String name, String arguments) async {
    final tool = _tools[name];
    if (tool == null) return '未知工具: $name';
    try {
      final args = arguments.isNotEmpty
          ? jsonDecode(arguments) as Map<String, dynamic>
          : <String, dynamic>{};
      Log.d('执行工具: $name, 参数: $args');
      return await tool.execute(args);
    } catch (e) {
      Log.w('工具执行失败 $name: $e');
      return '工具执行失败: $e';
    }
  }

  /// 获取 UI 提示
  String? getUiHint(String name, String arguments) {
    final tool = _tools[name];
    if (tool == null) return null;
    try {
      final args = arguments.isNotEmpty
          ? jsonDecode(arguments) as Map<String, dynamic>
          : <String, dynamic>{};
      return tool.formatUiHint(args);
    } catch (_) {
      return null;
    }
  }

  /// 获取工具显示名
  String? getDisplayName(String name) => _tools[name]?.displayName;
}
