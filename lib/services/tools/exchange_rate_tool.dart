import 'package:dio/dio.dart';
import 'package:xiao_p/utils/logger.dart';
import 'tool_plugin.dart';

/// 汇率换算工具 - 使用 open.er-api.com 免费 API
class ExchangeRateTool implements ToolPlugin {
  @override
  String get name => 'exchange_rate';

  @override
  String get displayName => '汇率换算';

  @override
  String get description => '查询实时汇率并进行货币换算。当用户询问汇率、货币兑换、外币价格时调用。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'amount': {
        'type': 'number',
        'description': '要换算的金额（默认为1）',
      },
      'from': {
        'type': 'string',
        'description': '源货币代码（如 USD、CNY、EUR、JPY、GBP）',
      },
      'to': {
        'type': 'string',
        'description': '目标货币代码',
      },
    },
    'required': ['from', 'to'],
  };

  @override
  ToolCategory get category => ToolCategory.utility;

  @override
  bool get requiresNetwork => true;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final from = (arguments['from'] as String?)?.toUpperCase() ?? '';
    final to = (arguments['to'] as String?)?.toUpperCase() ?? '';
    final amount = (arguments['amount'] as num?)?.toDouble() ?? 1.0;

    if (from.isEmpty || to.isEmpty) return '货币代码不能为空';
    if (from == to) return '$amount $from = $amount $to';

    try {
      final url = 'https://open.er-api.com/v6/latest/$from';
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        return '汇率查询失败: HTTP ${response.statusCode}';
      }

      final data = response.data as Map<String, dynamic>;
      final result = data['result'] as String?;
      if (result != 'success') {
        return '汇率查询失败: ${data['error-type'] ?? '未知错误'}';
      }

      final rates = data['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate == null) return '未找到 $from 到 $to 的汇率';

      final converted = (rate as num).toDouble() * amount;
      final rateStr = rate.toStringAsFixed(4);
      final convertedStr = converted % 1 == 0
          ? converted.toInt().toString()
          : converted.toStringAsFixed(2);

      return '$amount $from = $convertedStr $to（汇率: 1 $from = $rateStr $to）\n'
          '更新时间: ${data['time_last_update_utc'] ?? '未知'}';
    } catch (e) {
      Log.w('汇率查询失败: $e');
      return '汇率查询失败: $e。请稍后重试。';
    }
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    final amount = arguments['amount'] ?? 1;
    final from = arguments['from'] ?? '';
    final to = arguments['to'] ?? '';
    return '\n\n> 💱 汇率换算: $amount $from → $to\n\n';
  }
}
