import 'package:flutter/foundation.dart';

class Log {
  static const String _tag = 'XiaoP';

  static void d(String message) {
    debugPrint('[$_tag] $message');
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$_tag] ERROR: $message');
    if (error != null) debugPrint('[$_tag] error detail: $error');
  }

  static void w(String message) {
    debugPrint('[$_tag] WARN: $message');
  }
}
