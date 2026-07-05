import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/companion.dart';
import 'package:xiao_p/providers/companion_providers.dart';
import 'package:xiao_p/services/personality_service.dart';

class PersonalityEditScreen extends ConsumerStatefulWidget {
  final Companion? existing;

  const PersonalityEditScreen({super.key, this.existing});

  @override
  ConsumerState<PersonalityEditScreen> createState() =>
      _PersonalityEditScreenState();
}

class _PersonalityEditScreenState extends ConsumerState<PersonalityEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final companion = widget.existing ?? ref.read(companionProvider);
    _nameController = TextEditingController(text: companion?.name ?? '');
    _descController = TextEditingController(text: companion?.description ?? '');
    _promptController = TextEditingController(text: companion?.systemPrompt ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final prompt = _promptController.text.trim();

    if (name.isEmpty || prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名字和系统提示词不能为空')),
      );
      return;
    }

    final companion = Companion(
      name: name,
      description: desc,
      systemPrompt: prompt,
      preset: CompanionPreset.custom,
    );

    await PersonalityService.saveCompanion(companion);
    ref.read(companionProvider.notifier).update(companion);
    await PersonalityService.setCurrentCompanion(companion);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? '编辑人格' : '创建人格'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: TextStyle(
                color: AppTheme.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('名字', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(hintText: '给你的伙伴起个名字'),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 20),
            Text('性格描述', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(hintText: '简单描述性格特点'),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 20),
            Text('系统提示词', style: _labelStyle),
            const SizedBox(height: 8),
            Text(
              'AI的核心人格设定，决定了说话风格和行为方式',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: '你是...\n你的特点...\n回复要求...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                alignLabelWithHint: true,
              ),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _labelStyle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      );
}
