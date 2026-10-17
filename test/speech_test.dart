import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:festival_notebook/ai/speak.dart';

class FakeSpeech extends Fake implements TextToSpeechEngine {
  bool truncated = false;
  TextToSpeechRequest? request;
  @override
  Future<TextToSpeechResult> synthesizeOnce(TextToSpeechRequest request) async {
    this.request = request;
    return TextToSpeechResult(
      samples: Float32List(24),
      sampleRateHz: 24000,
      channelCount: 1,
      framesGenerated: 1,
      truncated: truncated,
    );
  }
}

void main() {
  test('speech preserves language and seed and returns a WAV', () async {
    final engine = FakeSpeech();
    final wav = await synthesizeSpeech(
      engine,
      'Bonjour',
      language: 'fr',
      seed: 7,
    );
    expect(engine.request!.language, 'fr');
    expect(engine.request!.seed, 7);
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');
  });
  test(
    'truncated speech is reported instead of played as a full reply',
    () async {
      final engine = FakeSpeech()..truncated = true;
      await expectLater(synthesizeSpeech(engine, 'Hello'), throwsStateError);
    },
  );
}
