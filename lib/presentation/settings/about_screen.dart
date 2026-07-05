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
            _buildFeatureItem('多AI提供商', '支持 LM Studio、DeepSeek、Qwen、Kimi、GLM 等'),
            _buildFeatureItem('流式对话', 'AI回复逐字显示，体验更流畅'),
            _buildFeatureItem('分层记忆', 'L0-L4 五层记忆系统，AI 自动提取整合'),
            _buildFeatureItem('人格系统', '3种预设风格 + 无限自定义人格'),
            _buildFeatureItem('对话管理', '多对话支持，置顶/重命名/删除'),
            _buildFeatureItem('语音交互', '语音输入 + 语音朗读回复'),
            _buildFeatureItem('联网搜索', '自动搜索相关信息辅助回答'),
            _buildFeatureItem('深度记忆', 'AI 自动记忆用户偏好、情绪、习惯'),
          ]),

          const SizedBox(height: 24),

          // 开源信息
          _buildSection('开源', [
            _buildInfoRow('基于', 'Stock-King + The-hacker-world'),
            _buildInfoRow('状态管理', 'Riverpod'),
            _buildInfoRow('路由', 'GoRouter'),
            _buildInfoRow('网络', 'Dio'),
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
