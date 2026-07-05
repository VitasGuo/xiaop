import 'package:flutter/material.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/memory_entry.dart';
import 'package:xiao_p/services/memory_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<MemoryEntry> _memories = [];
  bool _loading = true;
  int _selectedLevel = -1; // -1 = 全部

  final Map<int, String> _levelLabels = {
    -1: '全部',
    0: 'L0 身份',
    1: 'L1 长期',
    2: 'L2 热记忆',
    3: 'L3 温记忆',
    4: 'L4 归档',
  };

  final Map<int, Color> _levelColors = {
    0: Colors.purple,
    1: Colors.blue,
    2: Colors.green,
    3: Colors.orange,
    4: Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _loading = true);
    final memories = await MemoryService.getAllMemories();
    if (mounted) {
      setState(() {
        _memories = memories;
        _loading = false;
      });
    }
  }

  Future<void> _deleteMemory(int id) async {
    await MemoryService.deleteMemory(id);
    await _loadMemories();
  }

  List<MemoryEntry> get _filteredMemories {
    if (_selectedLevel == -1) return _memories;
    return _memories.where((m) => m.level.index == _selectedLevel).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: '添加记忆',
            onPressed: _showAddDialog,
          ),
          if (_memories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空所有记忆'),
                    content: const Text('此操作不可恢复。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await MemoryService.clearAll();
                  await _loadMemories();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildLevelFilter(),
          _buildStats(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMemories.isEmpty
                    ? _buildEmptyState()
                    : _buildMemoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelFilter() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _levelLabels.entries.map((entry) {
          final isSelected = _selectedLevel == entry.key;
          final color = entry.key == -1 ? AppTheme.accentColor : (_levelColors[entry.key] ?? AppTheme.textSecondary);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(entry.value, style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedLevel = entry.key);
              },
              selectedColor: color,
              backgroundColor: AppTheme.cardColor,
              side: BorderSide(color: color.withValues(alpha: 0.3)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStats() {
    final counts = <int, int>{};
    for (final m in _memories) {
      counts[m.level.index] = (counts[m.level.index] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('共 ${_memories.length} 条记忆', style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          )),
          const Spacer(),
          ...counts.entries.map((e) => Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _levelColors[e.key],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('L${e.key}: ${e.value}', style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                )),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.memory_outlined, size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('还没有记忆', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('和小P聊天时会自动记录', style: TextStyle(
              fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('手动添加'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredMemories.length,
      itemBuilder: (context, index) {
        return _buildMemoryItem(_filteredMemories[index]);
      },
    );
  }

  Widget _buildMemoryItem(MemoryEntry memory) {
    final levelColor = _levelColors[memory.level.index] ?? Colors.grey;
    final importanceColor = memory.importance >= 3
        ? Colors.orange
        : memory.importance >= 2
            ? Colors.blue
            : AppTheme.textSecondary;

    return Dismissible(
      key: Key('memory_${memory.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        if (memory.id != null) _deleteMemory(memory.id!);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('L${memory.level.index}', style: TextStyle(
                    fontSize: 10,
                    color: levelColor,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: importanceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(memory.category, style: TextStyle(
                    fontSize: 10,
                    color: importanceColor,
                  )),
                ),
                const Spacer(),
                Text(
                  '${memory.updatedAt.month}/${memory.updatedAt.day}',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(memory.key, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            )),
            const SizedBox(height: 2),
            Text(memory.value, style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    final categoryController = TextEditingController(text: 'fact');
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    int importance = 2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('添加记忆', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: keyController, decoration: InputDecoration(hintText: '键名（如：用户名字）')),
            const SizedBox(height: 8),
            TextField(controller: valueController, decoration: InputDecoration(hintText: '内容'), maxLines: 2),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('重要性: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ...List.generate(5, (i) => GestureDetector(
                  onTap: () => setState(() => importance = i + 1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: importance == i + 1 ? AppTheme.accentColor : AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${i + 1}', style: TextStyle(
                      fontSize: 12,
                      color: importance == i + 1 ? Colors.white : AppTheme.textPrimary,
                    )),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (keyController.text.isNotEmpty && valueController.text.isNotEmpty) {
                    await MemoryService.upsertMemory(
                      categoryController.text,
                      keyController.text.trim(),
                      valueController.text.trim(),
                      importance: importance,
                    );
                    Navigator.pop(ctx);
                    await _loadMemories();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
                child: const Text('保存', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
