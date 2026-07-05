import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/companion.dart';
import 'package:xiao_p/providers/companion_providers.dart';
import 'package:xiao_p/services/personality_service.dart';
import 'package:go_router/go_router.dart';

class PersonalityScreen extends ConsumerStatefulWidget {
  const PersonalityScreen({super.key});

  @override
  ConsumerState<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends ConsumerState<PersonalityScreen> {
  List<Companion> _savedCompanions = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final list = await PersonalityService.getAllCompanions();
    if (mounted) {
      setState(() => _savedCompanions = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companion = ref.watch(companionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('人格设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('预设风格'),
          ...Companion.presets.map((preset) => _buildPresetCard(
                preset,
                isActive: companion.preset == preset.preset &&
                    companion.name == preset.name,
              )),
          if (_savedCompanions.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('已保存的自定义人格'),
            ..._savedCompanions.map((c) => _buildSavedCard(
                  c,
                  isActive: companion.name == c.name &&
                      companion.preset == CompanionPreset.custom &&
                      companion.systemPrompt == c.systemPrompt,
                )),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle('自定义人格'),
          _buildCreateCard(),
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

  Widget _buildPresetCard(Companion preset, {required bool isActive}) {
    return GestureDetector(
      onTap: () async {
        ref.read(companionProvider.notifier).update(preset);
        await PersonalityService.setCurrentCompanion(preset);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentColor.withValues(alpha: 0.1)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.accentColor : Theme.of(context).dividerColor,
            width: isActive ? 2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B8EC4), Color(0xFFE8A0BF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                  Text(preset.description,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: AppTheme.accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard(Companion saved, {required bool isActive}) {
    return GestureDetector(
      onTap: () async {
        ref.read(companionProvider.notifier).update(saved);
        await PersonalityService.setCurrentCompanion(saved);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentColor.withValues(alpha: 0.1)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.accentColor : Theme.of(context).dividerColor,
            width: isActive ? 2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit, color: AppTheme.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(saved.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                  Text(saved.description,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: AppTheme.accentColor, size: 20),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
              onPressed: () async {
                await context.push('/personality/edit', extra: saved);
                await _loadSaved();
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除人格'),
                    content: Text('确定删除「${saved.name}」？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await PersonalityService.deleteCompanion(saved.name);
                  await _loadSaved();
                  // 如果删除的是当前使用的，切回默认
                  if (isActive) {
                    ref.read(companionProvider.notifier).update(Companion.warmPreset);
                    await PersonalityService.setCurrentCompanion(Companion.warmPreset);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return GestureDetector(
      onTap: () async {
        await context.push('/personality/edit');
        await _loadSaved();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add, color: AppTheme.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('创建新人格',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                  Text('自定义名字、性格和说话风格',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
