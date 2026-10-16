import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/microphone.dart';
import 'package:festival_notebook/voice_recorder.dart';

void main() {
  test('Reference rejects short takes and silence', () {
    expect(
      validateVoiceTake(pcm16Wav(Uint8List(32000))),
      contains('three seconds'),
    );
    expect(
      validateVoiceTake(pcm16Wav(Uint8List(32000 * 4))),
      contains('No clear voice'),
    );
    final pcm = Uint8List(32000 * 4);
    final samples = ByteData.sublistView(pcm);
    for (var i = 0; i < pcm.length; i += 2) {
      samples.setInt16(i, (i % 80 < 40) ? 4000 : -4000, Endian.little);
    }
    expect(validateVoiceTake(pcm16Wav(pcm)), isNull);
  });
}
