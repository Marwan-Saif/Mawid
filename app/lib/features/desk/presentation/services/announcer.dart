import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks a call out loud on the waiting-room device ("رقم ٤، أبو سامي، اتفضل على غرفة ١"),
/// twice, after a short chime, like a person at the desk would.
class Announcer {
  Announcer({FlutterTts? tts}) : _tts = tts;

  FlutterTts? _tts;
  bool enabled = false;

  Future<void> say(String text, {required String language}) async {
    if (!enabled) return;
    await SystemSound.play(SystemSoundType.alert);
    try {
      final tts = _tts ??= FlutterTts();
      await tts.setLanguage(language);
      await tts.setSpeechRate(0.45);
      await tts.awaitSpeakCompletion(true);
      await tts.speak(text);
      await Future<void>.delayed(const Duration(seconds: 2));
      await tts.speak(text);
    } on Object {
      // No speech engine on this device: the screen still flashes the call.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } on Object {
      // nothing to stop
    }
  }
}
