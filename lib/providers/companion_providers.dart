import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiao_p/models/companion.dart';
import 'package:xiao_p/services/personality_service.dart';

final companionProvider =
    StateNotifierProvider<CompanionNotifier, Companion>((ref) {
  return CompanionNotifier();
});

class CompanionNotifier extends StateNotifier<Companion> {
  CompanionNotifier() : super(Companion.warmPreset) {
    _load();
  }

  Future<void> _load() async {
    state = await PersonalityService.getCurrentCompanion();
  }

  Future<void> update(Companion companion) async {
    state = companion;
    await PersonalityService.setCurrentCompanion(companion);
  }
}
