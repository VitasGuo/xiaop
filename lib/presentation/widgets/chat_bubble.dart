import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRegenerate;

  const ChatBubble({super.key, required this.message, this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isUser)
                  _buildUserContent(context)
                else
                  _buildAssistantContent(context),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    if (!isUser) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copyMessage(context),
                        child: Icon(Icons.copy_outlined, size: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildUserContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.6),
      ),
    );
  }

  Widget _buildAssistantContent(BuildContext context) {
    final content = message.content;

    final thinkingRegex = RegExp(r'<think>([\s\S]*?)</think>', dotAll: true);
    final thinkingMatch = thinkingRegex.firstMatch(content);

    Widget contentWidget;
    if (thinkingMatch != null) {
      final thinkingText = thinkingMatch.group(1) ?? '';
      final afterThinking = content.substring(thinkingMatch.end).trim();

      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thinkingText.isNotEmpty)
            _ThinkingBlock(thinkingText: thinkingText),
          if (afterThinking.isNotEmpty)
            _buildMarkdownContent(afterThinking),
        ],
      );
    } else {
      contentWidget = _buildMarkdownContent(content);
    }

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: contentWidget,
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(context);
              },
            ),
            if (onRegenerate != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新生成'),
                onTap: () {
                  Navigator.pop(ctx);
                  onRegenerate!();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownContent(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.6),
          h1: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          h2: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          h3: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          code: TextStyle(
            backgroundColor: AppTheme.primaryColor,
            color: AppTheme.textPrimary,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
          codeblockDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
          listBullet: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          strong: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          em: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
          blockquote: TextStyle(color: AppTheme.textSecondary),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppTheme.accentColor, width: 3)),
            color: AppTheme.primaryColor,
          ),
          a: TextStyle(color: AppTheme.accentColor, decoration: TextDecoration.underline),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B8EC4), Color(0xFFE8A0BF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.favorite, size: 16, color: Colors.white),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.person, size: 16, color: AppTheme.accentColor),
    );
  }

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  }
}

// thinking 可折叠块
class _ThinkingBlock extends StatefulWidget {
  final String thinkingText;
  const _ThinkingBlock({required this.thinkingText});

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '思考过程',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                widget.thinkingText,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
