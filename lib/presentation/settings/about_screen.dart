import 'package:flutter/material.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          // Logo
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B8EC4), Color(0xFFE8A0BF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '小P',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'AI 情感陪伴助手',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'v$_version+$_buildNumber',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 40),

          // 版本信息
          _buildSection('版本信息', [
            _buildInfoRow('版本号', 'v$_version'),
            _buildInfoRow('构建号', _buildNumber),
            _buildInfoRow('框架', 'Flutter'),
          ]),

          const SizedBox(height: 24),

          // 功能特性
          _buildSection('功能特性', [
            _buildFeatureItem('多AI提供商', 'SenseNova + LM Studio + DeepSeek + Qwen + Kimi + GLM + MiMo + 文心 + 混元 + 豆包 + 自定义'),
            _buildFeatureItem('流式对话', 'SSE 流式输出，AI回复逐字显示'),
            _buildFeatureItem('思考模式', '支持 reasoning/thinking，聊天气泡内折叠展示'),
            _buildFeatureItem('分层记忆', 'L0-L4 五层记忆系统，SQLite 存储'),
            _buildFeatureItem('人格系统', '3种预设风格 + 无限自定义人格，可绑定语音'),
            _buildFeatureItem('对话管理', '多对话、置顶、重命名、搜索、滑动删除'),
            _buildFeatureItem('语音交互', 'STT 语音输入 + TTS 语音朗读，可选音色和语速'),
            _buildFeatureItem('联网搜索', 'DuckDuckGo 搜索，可开关'),
            _buildFeatureItem('消息操作', '复制、重新生成'),
            _buildFeatureItem('上下文长度', '可调节 2-50 条消息'),
            _buildFeatureItem('欢迎引导', '首次打开 APP 引导页'),
            _buildFeatureItem('连通测试', '设置页一键测试 AI 连接'),
          ]),

          const SizedBox(height: 24),

          // 技术信息
          _buildSection('技术栈', [
            _buildInfoRow('状态管理', 'Riverpod'),
            _buildInfoRow('路由', 'GoRouter'),
            _buildInfoRow('网络', 'Dio'),
            _buildInfoRow('开源协议', 'MIT'),
          ]),

          const SizedBox(height: 32),

          Center(
            child: Text(
              'Made with ❤️ by VitasGuo',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$title  ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: desc,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
