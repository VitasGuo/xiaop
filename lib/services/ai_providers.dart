enum AiProviderType {
  lmstudio,
  deepseek,
  qwen,
  kimi,
  zhipu,
  mimo,
  ernie,
  hunyuan,
  doubao,
  custom,
}

class AiProviderConfig {
  final AiProviderType type;
  final String displayName;
  final String defaultBaseUrl;
  final String defaultModel;
  final List<String> availableModels;
  final String? presetApiKey;
  final String? defaultApiKey;
  final bool isCustom;
  final bool needsApiKey;
  final bool showUrlAndModel;

  const AiProviderConfig({
    required this.type,
    required this.displayName,
    required this.defaultBaseUrl,
    required this.defaultModel,
    required this.availableModels,
    this.presetApiKey,
    this.defaultApiKey,
    this.isCustom = false,
    this.needsApiKey = true,
    this.showUrlAndModel = false,
  });

  bool get hasPresetKey => presetApiKey != null && presetApiKey!.isNotEmpty;
  bool get hasDefaultKey => defaultApiKey != null && defaultApiKey!.isNotEmpty;
}

class AiProviders {
  static const List<AiProviderConfig> all = [
    lmstudio,
    deepseek,
    qwen,
    kimi,
    zhipu,
    mimo,
    ernie,
    hunyuan,
    doubao,
    custom,
  ];

  static const lmstudio = AiProviderConfig(
    type: AiProviderType.lmstudio,
    displayName: 'LM Studio (本地)',
    defaultBaseUrl: 'http://192.168.1.10:1234/v1',
    defaultModel: 'google/gemma-4-12b-qat',
    availableModels: [],
    needsApiKey: true,
    showUrlAndModel: true,
  );

  static const deepseek = AiProviderConfig(
    type: AiProviderType.deepseek,
    displayName: 'DeepSeek',
    defaultBaseUrl: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-v4-flash',
    availableModels: [
      'deepseek-v4-flash',
      'deepseek-v4-pro',
    ],
  );

  static const qwen = AiProviderConfig(
    type: AiProviderType.qwen,
    displayName: '通义千问 Qwen',
    defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen3.7-max',
    availableModels: [
      'qwen3.7-max',
      'qwen3.7-plus',
      'qwen3.6-flash',
    ],
  );

  static const kimi = AiProviderConfig(
    type: AiProviderType.kimi,
    displayName: 'Kimi (月之暗面)',
    defaultBaseUrl: 'https://api.moonshot.cn/v1',
    defaultModel: 'kimi-k2.5',
    availableModels: [
      'kimi-k2.5',
      'kimi-k2',
    ],
  );

  static const zhipu = AiProviderConfig(
    type: AiProviderType.zhipu,
    displayName: '智谱AI (GLM)',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-5.2',
    availableModels: [
      'glm-5.2',
      'glm-4.7',
      'glm-4.7-flash',
      'glm-4.5-air',
    ],
  );

  static const mimo = AiProviderConfig(
    type: AiProviderType.mimo,
    displayName: '小米MiMo',
    defaultBaseUrl: 'https://api.xiaomimimo.com/v1',
    defaultModel: 'mimo-v2.5-flash',
    availableModels: [
      'mimo-v2.5',
      'mimo-v2.5-pro',
      'mimo-v2.5-flash',
    ],
  );

  static const ernie = AiProviderConfig(
    type: AiProviderType.ernie,
    displayName: '文心一言 ERNIE',
    defaultBaseUrl: 'https://qianfan.baidubce.com/v2',
    defaultModel: 'ernie-4.5-turbo-8k',
    availableModels: [
      'ernie-4.5-turbo-8k',
      'ernie-4.0-turbo-8k',
      'ernie-speed-128k',
    ],
  );

  static const hunyuan = AiProviderConfig(
    type: AiProviderType.hunyuan,
    displayName: '腾讯混元 Hunyuan',
    defaultBaseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
    defaultModel: 'hunyuan-turbo',
    availableModels: [
      'hunyuan-turbo',
      'hunyuan-pro',
      'hunyuan-large',
    ],
  );

  static const doubao = AiProviderConfig(
    type: AiProviderType.doubao,
    displayName: '字节豆包 Doubao',
    defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModel: 'doubao-1.5-pro-32k',
    availableModels: [
      'doubao-1.5-pro-32k',
      'doubao-1.5-pro-256k',
      'doubao-1.5-lite-32k',
    ],
  );

  static const custom = AiProviderConfig(
    type: AiProviderType.custom,
    displayName: '自定义接口',
    defaultBaseUrl: '',
    defaultModel: '',
    availableModels: [],
    isCustom: true,
    showUrlAndModel: true,
  );

  static AiProviderConfig? getByName(String name) {
    try {
      return all.firstWhere((p) => p.type.name == name);
    } catch (e) {
      return null;
    }
  }
}
