import 'dart:math';
import 'package:expressions/expressions.dart';
import 'tool_plugin.dart';

/// 计算器工具 - 纯本地计算，支持四则运算、百分比、幂运算
class CalculatorTool implements ToolPlugin {
  @override
  String get name => 'calculator';

  @override
  String get displayName => '计算器';

  @override
  String get description => '数学计算工具，支持四则运算、百分比、幂运算。当需要精确计算数学表达式时调用。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'expression': {
        'type': 'string',
        'description': '数学表达式，如 2+3*4、15%100、2^10、(1+2)*3',
      },
    },
    'required': ['expression'],
  };

  @override
  ToolCategory get category => ToolCategory.productivity;

  @override
  bool get requiresNetwork => false;

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final expression = arguments['expression'] as String? ?? '';
    if (expression.isEmpty) return '表达式为空';

    try {
      // 预处理：将 ^ 转换为 pow() 调用
      final processed = _preprocessExpression(expression);

      final expr = Expression.parse(processed);
      final evaluator = const ExpressionEvaluator();
      final context = <String, dynamic>{
        'pow': (num a, num b) => pow(a, b),
      };

      final result = evaluator.eval(expr, context);

      if (result is num) {
        // 整数结果去掉小数点
        if (result == result.toInt()) {
          return '$expression = ${result.toInt()}';
        }
        return '$expression = ${result.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}';
      }

      return '$expression = $result';
    } catch (e) {
      return '无法计算表达式 "$expression": $e';
    }
  }

  /// 预处理表达式：将 ^ 替换为 pow() 调用
  String _preprocessExpression(String expr) {
    // 去除空格
    var result = expr.replaceAll(' ', '');

    // 反复处理 ^ 运算符（从左到右）
    // 匹配: 操作数^操作数，操作数可以是数字、变量或括号表达式
    var prevResult = '';
    while (result != prevResult) {
      prevResult = result;
      // 匹配 数字或括号表达式 ^ 数字或括号表达式
      result = result.replaceAllMapped(
        RegExp(r'((?:\d+\.?\d*)|(?:\([^()]*\)))\^((?:\d+\.?\d*)|(?:\([^()]*\)))'),
        (m) => 'pow(${m.group(1)}, ${m.group(2)})',
      );
    }

    return result;
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    final expression = arguments['expression'] ?? '';
    return '\n\n> 🧮 计算: $expression\n\n';
  }
}
