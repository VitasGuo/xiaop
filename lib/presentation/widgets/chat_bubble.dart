import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppTheme.accentColor.withValues(alpha: 0.12)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppTheme.accentColor.withValues(alpha: 0.2)
                          : Theme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                  child: isUser
                      ? Text(
                          message.content,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14, height: 1.6),
                            h1: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            h2: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            h3: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
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
                            strong: TextStyle(
                                fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            em: TextStyle(
                                fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
                            blockquote: TextStyle(color: AppTheme.textSecondary),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                  left: BorderSide(color: AppTheme.accentColor, width: 3)),
                              color: AppTheme.primaryColor,
                            ),
                            a: TextStyle(
                                color: AppTheme.accentColor,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                ),
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

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B8EC4), Color(0xFFE8A0BF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.favorite, size: 16, color: Colors.white),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
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
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
