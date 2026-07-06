import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SttService {
  static final SttService _instance = SttService._();
  factory SttService() => _instance;
  SttService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _listening = false;
  bool _hasPermission = false;

  bool get isListening => _listening;
  bool get hasPermission => _hasPermission;

  Future<bool> init() async {
    if (_initialized) return _hasPermission;

    // 请求麦克风权限
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    _hasPermission = status.isGranted;

    if (!_hasPermission) {
      _initialized = true;
      return false;
    }

    _hasPermission = await _speech.initialize(
      onError: (error) {
        _listening = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _listening = false;
        }
      },
    );
    _initialized = true;
    return _hasPermission;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    Function? onListeningComplete,
  }) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) {
        onListeningComplete?.call();
        return;
      }
    }

    if (!_hasPermission) {
      onListeningComplete?.call();
      return;
    }

    _listening = true;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          _listening = false;
          onResult(result.recognizedWords);
          onListeningComplete?.call();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'zh_CN',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: false,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _listening = false;
  }
}
