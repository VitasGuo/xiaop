import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/services/ai_providers.dart';

class ApiKeyService {
  static const String _prefix = 'api_key_';

  static Future<String> getEffectiveApiKey(AiProviderConfig provider) async {
    if (provider.presetApiKey != null) return provider.presetApiKey!;
    final savedKey = await getApiKey(provider.type.name);
    if (savedKey != null && savedKey.isNotEmpty) return savedKey;
    return provider.defaultApiKey ?? '';
  }

  static Future<String?> getApiKey(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$provider');
  }

  static Future<void> setApiKey(String provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$provider', apiKey);
  }

  static Future<void> removeApiKey(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$provider');
  }

  static Future<bool> hasApiKey(String provider) async {
    final key = await getApiKey(provider);
    return key != null && key.isNotEmpty;
  }
}
