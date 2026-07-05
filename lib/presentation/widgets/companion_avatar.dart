import 'package:flutter/material.dart';
import 'package:xiao_p/core/theme.dart';

class CompanionAvatar extends StatelessWidget {
  final double size;
  final bool showGlow;

  const CompanionAvatar({
    super.key,
    this.size = 80,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF9B8EC4), Color(0xFFE8A0BF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.favorite,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }
}
