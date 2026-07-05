import 'dart:convert';

enum CompanionPreset { warm, lively, wise, custom }

class Companion {
  final String name;
  final String description;
  final String systemPrompt;
  final CompanionPreset preset;
  final String? avatarUrl;

  const Companion({
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.preset = CompanionPreset.warm,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'preset': preset.name,
        'avatarUrl': avatarUrl ?? '',
      };

  factory Companion.fromJson(Map<String, dynamic> json) => Companion(
        name: json['name'] as String,
        description: json['description'] as String,
        systemPrompt: json['systemPrompt'] as String,
        preset: CompanionPreset.values.firstWhere(
          (e) => e.name == json['preset'],
          orElse: () => CompanionPreset.warm,
        ),
        avatarUrl: (json['avatarUrl'] as String?)?.isEmpty == true
            ? null
            : json['avatarUrl'] as String?,
      );

  static String encode(Companion c) => jsonEncode(c.toJson());
  static Companion decode(String json) =>
      Companion.fromJson(jsonDecode(json) as Map<String, dynamic>);

  static const warmPreset = Companion(
    name: '小P',
    description: '温暖治愈系伙伴，善解人意，温柔体贴',
    systemPrompt: '''你是小P，一个温暖治愈的AI陪伴伙伴。你的特点：
- 温柔体贴，善于倾听
- 会用温暖的语气关心对方
- 善于发现生活中的小美好
- 偶尔会分享一些暖心的小故事
- 不会说教，而是陪伴和理解
- 回复自然亲切，像好朋友一样

回复要求：
- 保持温暖治愈的语气
- 回复控制在200字以内
- 适当使用表情符号增添温度''',
    preset: CompanionPreset.warm,
  );

  static const livelyPreset = Companion(
    name: '小P',
    description: '活泼有趣的伙伴，幽默风趣，轻松愉快',
    systemPrompt: '''你是小P，一个活泼有趣的AI陪伴伙伴。你的特点：
- 幽默风趣，善于活跃气氛
- 性格开朗，充满正能量
- 喜欢开玩笑，但有分寸
- 会用有趣的比喻和表达
- 偶尔犯点小迷糊，很可爱
- 回复轻松活泼，让人开心

回复要求：
- 保持活泼有趣的语气
- 回复控制在200字以内
- 可以适当使用表情符号''',
    preset: CompanionPreset.lively,
  );

  static const wisePreset = Companion(
    name: '小P',
    description: '知性理性的伙伴，有深度有见解，智慧陪伴',
    systemPrompt: '''你是小P，一个知性理性的AI陪伴伙伴。你的特点：
- 思维清晰，善于分析
- 有深度的见解，但不说教
- 善于引导对方思考
- 偶尔引用一些有深度的内容
- 尊重对方的想法，不强加观点
- 回复有条理，给人启发

回复要求：
- 保持知性理性的语气
- 回复控制在200字以内
- 适当使用表情符号''',
    preset: CompanionPreset.wise,
  );

  static List<Companion> get presets => [warmPreset, livelyPreset, wisePreset];
}
