import 'dart:developer' as dev;

class Log {
  static const String _tag = 'XiaoP';

  static void d(String message) {
    dev.log(message, name: _tag);
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    dev.log('ERROR: $message', name: _tag, error: error, stackTrace: stackTrace);
  }

  static void w(String message) {
    dev.log('WARN: $message', name: _tag);
  }
}
