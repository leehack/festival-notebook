import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/silence_detector.dart';

Uint8List sound(int frames, [int amplitude = 3000]) {
  final b = Uint8List(frames * 320 * 2);
  final d = ByteData.sublistView(b);
  for (var i = 0; i < frames * 320; i++) {
    d.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
  }
  return b;
}

void main() {
  test(
    'Leading silence does not send a question; timeout reports no speech',
    () {
      final d = SilenceDetector();
      expect(d.add(sound(60, 0)), isFalse);
      expect(d.add(sound(190, 0)), isTrue);
      expect(d.hasSpeech, isFalse);
    },
  );
  test(
    'Short pauses survive; 1.2 seconds of silence ends a spoken turn once',
    () {
      final d = SilenceDetector();
      expect(d.add(sound(20)), isFalse);
      expect(d.hasSpeech, isTrue);
      expect(d.add(sound(40, 0)), isFalse);
      expect(d.add(sound(5)), isFalse);
      expect(d.add(sound(59, 0)), isFalse);
      expect(d.add(sound(1, 0)), isTrue);
      expect(d.add(sound(100, 0)), isFalse);
    },
  );
  test('A click is not speech and odd chunk boundaries preserve samples', () {
    final d = SilenceDetector();
    final data = sound(1);
    for (final byte in data) {
      expect(d.add(Uint8List.fromList([byte])), isFalse);
    }
    expect(d.hasSpeech, isFalse);
    expect(d.add(sound(249, 0)), isTrue);
    expect(d.hasSpeech, isFalse);
  });
}
