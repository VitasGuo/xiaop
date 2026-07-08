import 'package:dio/dio.dart';
import 'package:xiao_p/utils/logger.dart';
import 'tool_plugin.dart';

/// 天气查询工具 - 使用 wttr.in 免费 API
class WeatherTool implements ToolPlugin {
  @override
  String get name => 'weather';

  @override
  String get displayName => '天气查询';

  @override
  String get description => '查询指定城市的天气信息，包括当前温度、体感温度、湿度、风速和未来预报。当用户询问天气情况时调用。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'city': {
        'type': 'string',
        'description': '城市名（中文或英文，如 北京、Shanghai）',
      },
      'days': {
        'type': 'integer',
        'description': '预报天数（0=仅当前天气, 1-3=包含预报）',
      },
    },
    'required': ['city'],
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
    final city = arguments['city'] as String? ?? '';
    if (city.isEmpty) return '城市名为空';
    final days = (arguments['days'] as num?)?.toInt() ?? 1;

    try {
      final url = 'https://wttr.in/${Uri.encodeComponent(city)}?format=j1&lang=zh';
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode != 200) {
        return '天气查询失败: HTTP ${response.statusCode}';
      }

      final data = response.data as Map<String, dynamic>;
      final buffer = StringBuffer();

      // 当前天气
      final current = (data['current_condition'] as List?)?.firstOrNull as Map<String, dynamic>?;
      if (current != null) {
        final temp = current['temp_C'] ?? '?';
        final feelsLike = current['FeelsLikeC'] ?? '?';
        final humidity = current['humidity'] ?? '?';
        final windSpeed = current['windspeedKmph'] ?? '?';
        final desc = (current['lang_zh'] as List?)
            ?.firstOrNull?['value'] as String? ??
            (current['weatherDesc'] as List?)?.firstOrNull?['value'] as String? ??
            '未知';
        buffer.writeln('当前天气（$city）:');
        buffer.writeln('  天气: $desc');
        buffer.writeln('  温度: $temp°C（体感 $feelsLike°C）');
        buffer.writeln('  湿度: $humidity%');
        buffer.writeln('  风速: ${windSpeed}km/h');
      }

      // 预报
      if (days > 0) {
        final weather = data['weather'] as List?;
        if (weather != null) {
          final forecastDays = weather.take(days).toList();
          for (final day in forecastDays) {
            final d = day as Map<String, dynamic>;
            final date = d['date'] ?? '';
            final maxT = d['maxtempC'] ?? '?';
            final minT = d['mintempC'] ?? '?';
            final avgT = d['avgtempC'] ?? '?';
            // 取中午时段的天气描述
            final hourly = d['hourly'] as List?;
            final noon = hourly?.firstWhere(
              (h) => (h as Map<String, dynamic>)['time'] == '1200',
              orElse: () => hourly.first,
            ) as Map<String, dynamic>?;
            final desc = (noon?['lang_zh'] as List?)
                ?.firstOrNull?['value'] as String? ??
                (noon?['weatherDesc'] as List?)?.firstOrNull?['value'] as String? ??
                '未知';
            buffer.writeln('$date: $desc, $minT°C~$maxT°C（均$avgT°C）');
          }
        }
      }

      final result = buffer.toString().trim();
      return result.isEmpty ? '未获取到天气数据' : result;
    } catch (e) {
      Log.w('天气查询失败: $e');
      return '天气查询失败: $e。请稍后重试或基于已知信息回答。';
    }
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    final city = arguments['city'] ?? '';
    return '\n\n> 🌤 查询天气: $city\n\n';
  }
}
