import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/services/ai_providers.dart';

class AiConfig {
  final String provider;
  final String model;
  final String customUrl;
  final int contextLength;

  const AiConfig({
    this.provider = 'lmstudio',
    this.model = '',
    this.customUrl = '',
    this.contextLength = 20,
  });

  AiConfig copyWith({String? provider, String? model, String? customUrl, int? contextLength}) {
    return AiConfig(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      customUrl: customUrl ?? this.customUrl,
      contextLength: contextLength ?? this.contextLength,
    );
  }

  /// 获取实际生效的模型名（空则用提供商默认）
  String get effectiveModel {
    if (model.isNotEmpty) return model;
    final p = AiProviders.getByName(provider);
    return p?.defaultModel ?? '';
  }

  /// 获取实际生效的 URL（空则用提供商默认）
  String get effectiveUrl {
    if (customUrl.isNotEmpty) return customUrl;
    final p = AiProviders.getByName(provider);
    return p?.defaultBaseUrl ?? '';
  }
}

class AiConfigNotifier extends StateNotifier<AiConfig> {
  /// provider 初始化完成的 Future，外部可 await 确保状态已从磁盘加载
  late final Future<void> initialized;

  AiConfigNotifier() : super(const AiConfig()) {
    initialized = _load();
  }

  static const _keyProvider = 'ai_selected_provider';
  static const _keyContextLength = 'ai_context_length';

  /// 每个 provider 单独存储 model 和 customUrl，切换 provider 时互不覆盖
  static String _keyModel(String provider) => 'ai_model_$provider';
  static String _keyUrl(String provider) => 'ai_url_$provider';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_keyProvider) ?? 'lmstudio';
    final provider = AiProviders.getByName(providerName);

    // 一次性迁移：旧版用全局 key 存 model/url，迁移到按 provider 分开存储
    await _migrateLegacyKeys(prefs, providerName);

    state = AiConfig(
      provider: providerName,
      model: prefs.getString(_keyModel(providerName)) ?? provider?.defaultModel ?? '',
      customUrl: prefs.getString(_keyUrl(providerName)) ?? provider?.defaultBaseUrl ?? '',
      contextLength: prefs.getInt(_keyContextLength) ?? 20,
    );
  }

  /// 将旧版全局 ai_selected_model / ai_custom_url 迁移到当前 provider 的独立 key
  Future<void> _migrateLegacyKeys(SharedPreferences prefs, String providerName) async {
    const legacyModelKey = 'ai_selected_model';
    const legacyUrlKey = 'ai_custom_url';
    final migrated = prefs.getBool('ai_migrated_v1_2_7') ?? false;
    if (migrated) return;

    final legacyModel = prefs.getString(legacyModelKey);
    final legacyUrl = prefs.getString(legacyUrlKey);
    if (legacyModel != null && legacyModel.isNotEmpty) {
      await prefs.setString(_keyModel(providerName), legacyModel);
    }
    if (legacyUrl != null && legacyUrl.isNotEmpty) {
      await prefs.setString(_keyUrl(providerName), legacyUrl);
    }
    await prefs.setBool('ai_migrated_v1_2_7', true);
  }

  /// 切换 provider：加载目标 provider 已保存的 model/url，无则用默认值
  Future<void> switchProvider(String providerName) async {
    final prefs = await SharedPreferences.getInstance();
    final provider = AiProviders.getByName(providerName);
    final model = prefs.getString(_keyModel(providerName)) ?? provider?.defaultModel ?? '';
    final url = prefs.getString(_keyUrl(providerName)) ?? provider?.defaultBaseUrl ?? '';

    state = AiConfig(
      provider: providerName,
      model: model,
      customUrl: url,
      contextLength: state.contextLength,
    );
    await prefs.setString(_keyProvider, providerName);
  }

  Future<void> update({String? provider, String? model, String? customUrl, int? contextLength}) async {
    state = state.copyWith(
      provider: provider,
      model: model,
      customUrl: customUrl,
      contextLength: contextLength,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProvider, state.provider);
    // model 和 customUrl 按当前 provider 单独存储
    if (model != null) await prefs.setString(_keyModel(state.provider), model);
    if (customUrl != null) await prefs.setString(_keyUrl(state.provider), customUrl);
    if (contextLength != null) await prefs.setInt(_keyContextLength, contextLength);
  }
}

final aiConfigProvider = StateNotifierProvider<AiConfigNotifier, AiConfig>((ref) {
  return AiConfigNotifier();
});
