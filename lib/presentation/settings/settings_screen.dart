import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/main.dart';
import 'package:xiao_p/providers/ai_config_provider.dart';
import 'package:xiao_p/services/ai_providers.dart';
import 'package:xiao_p/services/api_key_service.dart';
import 'package:xiao_p/services/tts_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _ttsEnabled = true;
  bool _webSearchEnabled = true;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final tts = TtsService();
    final aiConfig = ref.read(aiConfigProvider);
    final apiKey = await ApiKeyService.getApiKey(aiConfig.provider);
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ttsEnabled = tts.isEnabled;
        _webSearchEnabled = prefs.getBool('web_search_enabled') ?? true;
        _apiKeyController.text = apiKey ?? '';
        _modelController.text = aiConfig.effectiveModel;
        _urlController.text = aiConfig.effectiveUrl;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiConfig = ref.watch(aiConfigProvider);
    final currentTheme = ref.watch(themeModeProvider);
    final provider = AiProviders.getByName(aiConfig.provider);
    final isLocalOrCustom = provider?.showUrlAndModel == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('AI 提供商'),
          _buildProviderSelector(aiConfig),
          const SizedBox(height: 8),

          // 本地/自定义提供商：显示 URL 和模型输入框
          if (isLocalOrCustom) ...[
            _buildUrlField(aiConfig),
            const SizedBox(height: 8),
            _buildModelInputField(aiConfig),
          ] else ...[
            _buildModelSelector(aiConfig),
          ],
          const SizedBox(height: 8),
          _buildApiKeyField(aiConfig),
          const SizedBox(height: 8),
          _buildTestButton(aiConfig),
          const SizedBox(height: 16),
          _buildContextLengthSlider(aiConfig),
          const SizedBox(height: 8),
          _buildWebSearchToggle(),
          const SizedBox(height: 24),
          _buildSectionTitle('语音设置'),
          _buildTtsToggle(),
          if (_ttsEnabled) ...[
            const SizedBox(height: 8),
            _buildVoiceSelector(),
            const SizedBox(height: 8),
            _buildSpeechRateSlider(),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle('外观'),
          _buildThemeSelector(currentTheme),
          const SizedBox(height: 8),
          _buildAccentColorPicker(),
          const SizedBox(height: 24),
          _buildSectionTitle('关于'),
          _buildAboutButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildProviderSelector(AiConfig aiConfig) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: aiConfig.provider,
          isExpanded: true,
          dropdownColor: AppTheme.cardColor,
          style: TextStyle(color: AppTheme.textPrimary),
          items: AiProviders.all.map((p) {
            return DropdownMenuItem(
              value: p.type.name,
              child: Text(p.displayName),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              final provider = AiProviders.getByName(value);
              ref.read(aiConfigProvider.notifier).update(
                    provider: value,
                    model: provider?.defaultModel ?? '',
                    customUrl: provider?.defaultBaseUrl ?? '',
                  );
              _reloadApiKey(value);
              setState(() {
                _modelController.text = provider?.defaultModel ?? '';
                _urlController.text = provider?.defaultBaseUrl ?? '';
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildUrlField(AiConfig aiConfig) {
    if (!_loaded) return const SizedBox(height: 48);

    final provider = AiProviders.getByName(aiConfig.provider);
    final defaultUrl = provider?.defaultBaseUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: '输入 API 地址',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_urlController.text != defaultUrl && defaultUrl.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: '恢复默认',
                    onPressed: () {
                      setState(() => _urlController.text = defaultUrl);
                      ref.read(aiConfigProvider.notifier).update(customUrl: defaultUrl);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.save, size: 18),
                  onPressed: () {
                    ref.read(aiConfigProvider.notifier).update(customUrl: _urlController.text);
                    _showSaved();
                  },
                ),
              ],
            ),
          ),
          style: TextStyle(color: AppTheme.textPrimary),
          onSubmitted: (_) {
            ref.read(aiConfigProvider.notifier).update(customUrl: _urlController.text);
          },
        ),
        if (defaultUrl.isNotEmpty && _urlController.text != defaultUrl)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '默认: $defaultUrl',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildModelInputField(AiConfig aiConfig) {
    if (!_loaded) return const SizedBox(height: 48);

    final provider = AiProviders.getByName(aiConfig.provider);
    final defaultModel = provider?.defaultModel ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _modelController,
          decoration: InputDecoration(
            hintText: '输入模型名称',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_modelController.text != defaultModel && defaultModel.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: '恢复默认',
                    onPressed: () {
                      setState(() => _modelController.text = defaultModel);
                      ref.read(aiConfigProvider.notifier).update(model: defaultModel);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.save, size: 18),
                  onPressed: () {
                    ref.read(aiConfigProvider.notifier).update(model: _modelController.text);
                    _showSaved();
                  },
                ),
              ],
            ),
          ),
          style: TextStyle(color: AppTheme.textPrimary),
          onSubmitted: (_) {
            ref.read(aiConfigProvider.notifier).update(model: _modelController.text);
          },
        ),
        if (defaultModel.isNotEmpty && _modelController.text != defaultModel)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '默认: $defaultModel',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildModelSelector(AiConfig aiConfig) {
    final provider = AiProviders.getByName(aiConfig.provider);
    final models = provider?.availableModels ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: models.contains(aiConfig.model) ? aiConfig.model : null,
          isExpanded: true,
          hint: Text('选择模型', style: TextStyle(color: AppTheme.textSecondary)),
          dropdownColor: AppTheme.cardColor,
          style: TextStyle(color: AppTheme.textPrimary),
          items: models.map((m) {
            return DropdownMenuItem(value: m, child: Text(m));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(aiConfigProvider.notifier).update(model: value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildApiKeyField(AiConfig aiConfig) {
    final provider = AiProviders.getByName(aiConfig.provider);

    // 不需要 API Key 的提供商
    if (provider?.needsApiKey == false) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi, color: AppTheme.accentColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '本地模型无需 API Key',
                style: TextStyle(color: AppTheme.accentColor, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (provider?.hasPresetKey == true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              '已内置 API Key，无需配置',
              style: TextStyle(color: AppTheme.accentColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!_loaded) {
      return const SizedBox(height: 48);
    }

    final isLmStudio = aiConfig.provider == 'lmstudio';

    return TextField(
      controller: _apiKeyController,
      decoration: InputDecoration(
        hintText: isLmStudio ? '输入 LM Studio Token' : '输入 API Key',
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        suffixIcon: IconButton(
          icon: const Icon(Icons.save, size: 18),
          onPressed: () async {
            await ApiKeyService.setApiKey(aiConfig.provider, _apiKeyController.text);
            _showSaved();
          },
        ),
      ),
      style: TextStyle(color: AppTheme.textPrimary),
      obscureText: true,
    );
  }

  void _showSaved() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Widget _buildAboutButton() {
    return GestureDetector(
      onTap: () => context.push('/about'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('关于小P', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
            ),
            Text('v1.2.6', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _reloadApiKey(String provider) async {
    final apiKey = await ApiKeyService.getApiKey(provider);
    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
      });
    }
  }

  bool _testing = false;

  Widget _buildTestButton(AiConfig aiConfig) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _testing ? null : () => _testConnection(aiConfig),
        icon: _testing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_find, size: 18),
        label: Text(_testing ? '测试中...' : '测试连通性'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accentColor,
          side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _testConnection(AiConfig aiConfig) async {
    setState(() => _testing = true);

    try {
      final provider = AiProviders.getByName(aiConfig.provider);

      // 优先用用户填写的URL，否则用提供商默认
      final baseUrl = aiConfig.customUrl.isNotEmpty
          ? aiConfig.customUrl
          : provider?.defaultBaseUrl ?? '';

      if (baseUrl.isEmpty) {
        _showTestError('请先填写API地址');
        return;
      }

      // 获取 API Key
      String? apiKey;
      if (provider?.hasPresetKey == true) {
        apiKey = provider?.presetApiKey;
      } else if (provider?.needsApiKey != false) {
        apiKey = _apiKeyController.text.isNotEmpty ? _apiKeyController.text : null;
      }

      final url = '$baseUrl/chat/completions';
      final hasToken = apiKey != null && apiKey.isNotEmpty;

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (hasToken) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post(
        url,
        options: Options(headers: headers),
        data: {
          if (aiConfig.effectiveModel.isNotEmpty) 'model': aiConfig.effectiveModel,
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ],
          'max_tokens': 5,
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('连接成功\n$url'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          _showTestError('返回 ${response.statusCode}\n$url');
        }
      }
    } catch (e) {
      String msg = '连接失败';
      if (e is DioException) {
        final url = e.requestOptions.uri.toString();
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          msg = '超时: $url';
        } else if (e.type == DioExceptionType.connectionError) {
          msg = '无法连接: $url\n请确认LM Studio已启动并开启局域网访问';
        } else if (e.response != null) {
          msg = '错误 ${e.response?.statusCode}: $url\n${e.response?.data?.toString().substring(0, (e.response?.data?.toString().length ?? 0) > 200 ? 200 : (e.response?.data?.toString().length ?? 0)) ?? ''}';
        } else {
          msg = '请求失败: $url\n${e.message ?? ''}';
        }
      }
      _showTestError(msg);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showTestError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildContextLengthSlider(AiConfig aiConfig) {
    final value = aiConfig.contextLength.toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('上下文长度', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${aiConfig.contextLength} 条消息',
                  style: TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '每次对话发送给AI的历史消息数量，越多上下文越完整但消耗更多token',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          Slider(
            value: value.clamp(2, 50),
            min: 2,
            max: 50,
            divisions: 48,
            activeColor: AppTheme.accentColor,
            onChanged: (v) {
              ref.read(aiConfigProvider.notifier).update(contextLength: v.round());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWebSearchToggle() {
    return SwitchListTile(
      title: Text('联网搜索', style: TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text('对话时自动搜索相关信息',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      value: _webSearchEnabled,
      onChanged: (value) async {
        setState(() => _webSearchEnabled = value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('web_search_enabled', value);
      },
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppTheme.accentColor;
        return null;
      }),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTtsToggle() {
    return SwitchListTile(
      title: Text(
        '语音朗读',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        'AI回复时自动朗读',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      value: _ttsEnabled,
      onChanged: (value) {
        setState(() => _ttsEnabled = value);
        TtsService().setEnabled(value);
      },
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTheme.accentColor;
        }
        return null;
      }),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildVoiceSelector() {
    return FutureBuilder<List<Map<String, String>>>(
      future: TtsService().getAvailableVoices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final voices = snapshot.data!;
        final currentVoice = TtsService().voiceName;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: voices.any((v) => v['name'] == currentVoice) ? currentVoice : null,
              isExpanded: true,
              hint: Text('选择语音', style: TextStyle(color: AppTheme.textSecondary)),
              dropdownColor: AppTheme.cardColor,
              style: TextStyle(color: AppTheme.textPrimary),
              items: voices.map((v) {
                return DropdownMenuItem(
                  value: v['name'],
                  child: Text('${v['name']} (${v['locale']})', style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  TtsService().setVoice(value);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeechRateSlider() {
    final rate = TtsService().speechRate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('语速', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              Text('${rate.toStringAsFixed(1)}x', style: TextStyle(
                fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: rate.clamp(0.1, 2.0),
            min: 0.1,
            max: 2.0,
            divisions: 19,
            activeColor: AppTheme.accentColor,
            onChanged: (v) {
              setState(() {});
              TtsService().setSpeechRate(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccentColorPicker() {
    final colors = [
      {'name': '薰衣草紫', 'color': const Color(0xFF9B8EC4)},
      {'name': '海洋蓝', 'color': const Color(0xFF5B9BD5)},
      {'name': '森林绿', 'color': const Color(0xFF6BAF6D)},
      {'name': '珊瑚红', 'color': const Color(0xFFE8735A)},
      {'name': '琥珀橙', 'color': const Color(0xFFE8A44C)},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('主题色', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: colors.map((c) {
              return GestureDetector(
                onTap: () async {
                  await ThemeService.setAccentColor(c['color'] as Color);
                  setState(() {}); // 触发重建
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('主题色已更新')),
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c['color'] as Color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(AppThemeMode currentTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppThemeMode>(
          value: currentTheme,
          isExpanded: true,
          dropdownColor: AppTheme.cardColor,
          style: TextStyle(color: AppTheme.textPrimary),
          items: const [
            DropdownMenuItem(value: AppThemeMode.dark, child: Text('深色模式')),
            DropdownMenuItem(value: AppThemeMode.light, child: Text('浅色模式')),
            DropdownMenuItem(value: AppThemeMode.system, child: Text('跟随系统')),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(themeModeProvider.notifier).state = value;
              ThemeService.setThemeMode(value);
            }
          },
        ),
      ),
    );
  }
}
