import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/notebook_controller.dart';

void main() {
  test('Changing voice clears stale audio and custom reference', () {
    final model = NotebookController();
    model.speakerReference = Uint8List.fromList([1]);
    model.referenceName = 'custom.wav';
    model.audioBytes = Uint8List.fromList([2]);
    model.selectVoice('alternate');
    expect(model.voiceId, 'alternate');
    expect(model.speakerReference, isNull);
    expect(model.audioBytes, isNull);
    expect(model.voiceLabel, 'Mo · Alternate');
    model.busy = true;
    model.selectVoice('original');
    expect(model.voiceId, 'alternate');
    model.dispose();
  });
}
