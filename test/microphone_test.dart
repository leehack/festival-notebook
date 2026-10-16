import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/microphone.dart';

void main() {
  test('Microphone PCM becomes a mono 16 kHz WAV with intact samples', () {
    final pcm = Uint8List.fromList([0, 0, 255, 127, 0, 128, 1]);
    final wav = pcm16Wav(pcm);
    final header = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), wav.length - 8);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(40, Endian.little), 6);
    expect(wav.sublist(44), pcm.sublist(0, 6));
  });
}
