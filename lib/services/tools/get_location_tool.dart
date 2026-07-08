import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xiao_p/utils/logger.dart';
import 'tool_plugin.dart';

/// 位置获取工具 - 获取手机当前 GPS 位置 + 反向地理编码城市名
class GetLocationTool implements ToolPlugin {
  @override
  String get name => 'get_location';

  @override
  String get displayName => '当前位置';

  @override
  String get description => '获取用户当前的位置信息（城市名和坐标）。当用户询问天气但未指定城市、或需要基于位置提供服务时调用此工具。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  ToolCategory get category => ToolCategory.system;

  @override
  bool get requiresNetwork => true;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    try {
      // 1. 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return '定位服务未开启，请在系统设置中开启定位';
      }

      // 2. 检查并请求权限
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return '位置权限被拒绝，请在设置中授予位置权限';
      }
      if (permission == LocationPermission.deniedForever) {
        return '位置权限被永久拒绝，请在系统设置中手动授予位置权限';
      }

      // 3. 获取当前位置（低精度优先，快速返回）
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 4. 反向地理编码获取城市名
      final cityName = await _reverseGeocode(position.latitude, position.longitude);

      final result = cityName.isNotEmpty
          ? '当前位置: $cityName（坐标: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}）'
          : '当前位置坐标: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}（未能获取城市名）';

      return result;
    } catch (e) {
      Log.w('获取位置失败: $e');
      return '获取位置失败: $e';
    }
  }

  /// 反向地理编码：用 Nominatim (OpenStreetMap) 免费 API 获取城市名
  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lon&format=json&accept-language=zh-CN';
      final response = await _dio.get(
        url,
        options: Options(headers: {
          'User-Agent': 'xiao-p-app/1.4.0',
        }),
      );
      if (response.statusCode != 200) return '';

      final data = response.data as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return '';

      // 按优先级取城市名
      final city = address['city'] ?? address['town'] ?? address['county']
          ?? address['state'] ?? address['province'];
      final country = address['country'] ?? '';

      final parts = <String>[];
      if (country.toString().isNotEmpty) parts.add(country.toString());
      if (city != null && city.toString().isNotEmpty) parts.add(city.toString());

      return parts.join(' ');
    } catch (e) {
      Log.w('反向地理编码失败: $e');
      return '';
    }
  }

  @override
  String? formatUiHint(Map<String, dynamic> arguments) {
    return '\n\n> 📍 获取当前位置...\n\n';
  }
}
