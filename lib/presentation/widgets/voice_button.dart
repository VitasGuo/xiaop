import 'package:flutter/material.dart';
import 'package:xiao_p/core/theme.dart';

class VoiceButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  const VoiceButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onLongPressStart: (_) => widget.onLongPressStart(),
      onLongPressEnd: (_) => widget.onLongPressEnd(),
      child: PulsingBuilder(
        animation: _animation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isListening
                ? Colors.red.withValues(alpha: 0.15)
                : AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: widget.isListening
                ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                : null,
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none,
            color: widget.isListening ? Colors.red : AppTheme.accentColor,
            size: 20,
          ),
        ),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isListening ? _animation.value : 1.0,
            child: child,
          );
        },
      ),
    );
  }
}

class PulsingBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const PulsingBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
