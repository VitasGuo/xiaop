import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  String _voiceName = '';
  double _speechRate = 0.5;
  static const _keyTtsEnabled = 'tts_enabled';
  static const _keyTtsVoice = 'tts_voice';
  static const _keyTtsRate = 'tts_rate';

  bool get isEnabled => _enabled;
  String get voiceName => _voiceName;
  double get speechRate => _speechRate;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyTtsEnabled) ?? true;
    _voiceName = prefs.getString(_keyTtsVoice) ?? '';
    _speechRate = prefs.getDouble(_keyTtsRate) ?? 0.5;
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    if (_voiceName.isNotEmpty) {
      await _tts.setVoice({'name': _voiceName, 'locale': 'zh-CN'});
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTtsEnabled, enabled);
    if (!enabled) {
      await _tts.stop();
    }
  }

  Future<void> setVoice(String voiceName) async {
    _voiceName = voiceName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTtsVoice, voiceName);
    if (voiceName.isNotEmpty) {
      await _tts.setVoice({'name': voiceName, 'locale': 'zh-CN'});
    }
  }

  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final voices = await _tts.getVoices;
      final zhVoices = voices
          .where((v) => (v['locale'] as String?)?.startsWith('zh') == true)
          .map((v) => {
                'name': v['name'] as String? ?? '',
                'locale': v['locale'] as String? ?? '',
              })
          .toList();
      return zhVoices;
    } catch (_) {
      return [];
    }
  }

  Future<void> speak(String text) async {
    if (!_enabled || text.isEmpty) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTtsRate, rate);
    await _tts.setSpeechRate(rate);
  }
}
