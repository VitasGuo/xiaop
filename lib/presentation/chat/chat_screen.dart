import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/models/chat_message.dart';
import 'package:xiao_p/providers/ai_config_provider.dart';
import 'package:xiao_p/providers/companion_providers.dart';
import 'package:xiao_p/services/chat_service.dart';
import 'package:xiao_p/services/stt_service.dart';
import 'package:xiao_p/services/tts_service.dart';
import 'package:xiao_p/presentation/widgets/chat_bubble.dart';
import 'package:xiao_p/presentation/widgets/voice_button.dart';
import 'package:xiao_p/presentation/widgets/companion_avatar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _error;
  String? _lastUserMessage;
  bool _isListening = false;

  final ChatService _chatService = ChatService();
  final SttService _sttService = SttService();
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _ttsService.init();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _chatService.getMessages(widget.conversationId);
    if (mounted) {
      setState(() => _messages = messages);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _loading) return;

    _chatController.clear();
    _lastUserMessage = text;

    await _sendMessageInternal(text);
  }

  Future<void> _sendMessageInternal(String text) async {
    final userMsg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_u',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    // 保存用户消息到数据库
    await _chatService.saveUserMessage(widget.conversationId, text);

    setState(() {
      _messages.add(userMsg);
      _loading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final companion = ref.read(companionProvider);
      final aiConfig = ref.read(aiConfigProvider);

      // 添加一个空的 assistant 消息用于流式填充
      final aiMsgId = '${DateTime.now().millisecondsSinceEpoch}_a';
      final streamingMsg = ChatMessage(
        id: aiMsgId,
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _messages.add(streamingMsg);
          _loading = true;
          _error = null;
        });
        _scrollToBottom();
      }

      final buffer = StringBuffer();
      DateTime _lastUpdate = DateTime.now();

      await _chatService.streamAiResponse(
        conversationId: widget.conversationId,
        userMessage: text,
        providerName: aiConfig.provider,
        modelName: aiConfig.model,
        customUrl: aiConfig.customUrl.isNotEmpty ? aiConfig.customUrl : null,
        companion: companion,
        onToken: (token) {
          buffer.write(token);
          // 节流：最多每50ms更新一次UI
          final now = DateTime.now();
          if (mounted && now.difference(_lastUpdate).inMilliseconds > 50) {
            _lastUpdate = now;
            final text = buffer.toString();
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == aiMsgId);
              if (idx != -1) {
                _messages[idx] = ChatMessage(
                  id: aiMsgId,
                  role: 'assistant',
                  content: text,
                  timestamp: DateTime.now(),
                );
              }
            });
            _scrollToBottom();
          }
        },
        onComplete: (fullText) async {
          // 保存完整消息到数据库
          final finalMsg = ChatMessage(
            id: aiMsgId,
            role: 'assistant',
            content: fullText.isNotEmpty ? fullText : buffer.toString(),
            timestamp: DateTime.now(),
          );
          await _chatService.addMessage(widget.conversationId, finalMsg);
          await _chatService.touchConversation(widget.conversationId);

          if (mounted) {
            setState(() {
              _loading = false;
            });
            _ttsService.speak(finalMsg.content);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _messages.removeWhere((m) => m.id == aiMsgId);
              _loading = false;
              _error = error;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _retryMessage() async {
    if (_lastUserMessage == null || _loading) return;
    await _sendMessageInternal(_lastUserMessage!);
  }

  void _startVoiceInput() async {
    if (_isListening) return;
    setState(() => _isListening = true);
    await _sttService.startListening(
      onResult: (text) {
        _chatController.text = text;
        _sendMessage();
      },
      onListeningComplete: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  void _stopVoiceInput() async {
    if (!_isListening) return;
    await _sttService.stopListening();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    final companion = ref.watch(companionProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => context.go('/conversations'),
        ),
        title: Text(companion.name),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空对话'),
                    content: const Text('确定清空所有对话记录？'),
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
                  await _chatService.clearMessages(widget.conversationId);
                  setState(() => _messages = []);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatArea()),
          if (_error != null) _buildErrorBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CompanionAvatar(size: 80, showGlow: true),
              const SizedBox(height: 20),
              Text(
                '你好呀~',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '有什么想聊的吗？',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip('今天心情怎么样？'),
                  _buildSuggestionChip('给我讲个故事吧'),
                  _buildSuggestionChip('最近有什么有趣的事？'),
                  _buildSuggestionChip('帮我分析一下心情'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _loading) {
          return _buildTypingIndicator();
        }
        return ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _chatController.text = text;
        _sendMessage();
      },
      backgroundColor: AppTheme.cardColor,
      side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      labelStyle: TextStyle(color: AppTheme.textPrimary),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                  color: Theme.of(context).dividerColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.accentColor),
                ),
                const SizedBox(width: 10),
                Text('思考中...',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
          TextButton(
            onPressed: () => _retryMessage(),
            child: const Text('重试',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child:
                const Icon(Icons.close, color: Colors.red, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
            top: BorderSide(
                color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            VoiceButton(
              isListening: _isListening,
              onPressed: () {},
              onLongPressStart: () => _startVoiceInput(),
              onLongPressEnd: () => _stopVoiceInput(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: '说点什么...',
                  hintStyle:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.primaryColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  isDense: true,
                ),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: _loading ? null : _sendMessage,
                icon: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.accentColor),
                      )
                    : Icon(Icons.send,
                        color: AppTheme.accentColor, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  backgroundColor:
                      AppTheme.accentColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
