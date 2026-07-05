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
  AiConfigNotifier() : super(const AiConfig()) {
    _load();
  }

  static const _keyProvider = 'ai_selected_provider';
  static const _keyModel = 'ai_selected_model';
  static const _keyCustomUrl = 'ai_custom_url';
  static const _keyContextLength = 'ai_context_length';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_keyProvider) ?? 'lmstudio';
    final provider = AiProviders.getByName(providerName);

    state = AiConfig(
      provider: providerName,
      model: prefs.getString(_keyModel) ?? provider?.defaultModel ?? '',
      customUrl: prefs.getString(_keyCustomUrl) ?? provider?.defaultBaseUrl ?? '',
      contextLength: prefs.getInt(_keyContextLength) ?? 20,
    );
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
    await prefs.setString(_keyModel, state.model);
    await prefs.setString(_keyCustomUrl, state.customUrl);
    await prefs.setInt(_keyContextLength, state.contextLength);
  }
}

final aiConfigProvider = StateNotifierProvider<AiConfigNotifier, AiConfig>((ref) {
  return AiConfigNotifier();
});
