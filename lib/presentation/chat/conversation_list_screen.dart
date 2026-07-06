import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/conversation.dart';
import 'package:xiao_p/services/chat_service.dart';
import 'package:intl/intl.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final ChatService _chatService = ChatService();
  List<Conversation> _conversations = [];
  bool _loading = true;
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final conversations = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = List.from(conversations)
          ..sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
        _loading = false;
      });
    }
  }

  Future<void> _createConversation() async {
    final conversation = await _chatService.createConversation();
    if (mounted) {
      await context.push('/chat/${conversation.id}');
      _loadConversations();
    }
  }

  void _deleteConversation(Conversation conversation) async {
    await _chatService.deleteConversation(conversation.id);
    _loadConversations();
  }

  Future<void> _renameConversation(Conversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入新名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await _chatService.updateConversationTitle(conversation.id, newTitle);
      await _loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索对话...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('对话历史'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search, size: 20),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildConversationList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('还没有对话', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('点击右下角按钮开始新对话',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    final filtered = _searchQuery.isEmpty
        ? _conversations
        : _conversations
            .where((c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? '还没有对话' : '没有匹配的对话',
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildConversationItem(filtered[index]),
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    final timeStr = _formatTime(conversation.updatedAt);

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        _deleteConversation(conversation);
        return false;
      },
      child: GestureDetector(
        onTap: () async {
          await context.push('/chat/${conversation.id}');
          _loadConversations();
        },
        onLongPress: () => _renameConversation(conversation),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: conversation.isPinned
                  ? AppTheme.accentColor.withValues(alpha: 0.4)
                  : Theme.of(context).dividerColor,
              width: conversation.isPinned ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              if (conversation.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 13, color: AppTheme.accentColor),
                ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B8EC4), Color(0xFFE8A0BF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conversation.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('$timeStr · ${conversation.messageCount}条消息',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              // 置顶按钮
              GestureDetector(
                onTap: () async {
                  await _chatService.togglePin(conversation.id);
                  _loadConversations();
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                    color: conversation.isPinned ? AppTheme.accentColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(time);
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM-dd').format(time);
  }
}
