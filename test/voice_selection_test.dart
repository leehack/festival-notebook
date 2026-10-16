import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/notebook_controller.dart';
import 'support/fake_festival_service.dart';

void main() {
  test('Changing voice clears stale audio and custom reference', () async {
    final model = NotebookController(service: FakeFestivalService());
    model.useReference(Uint8List.fromList([1]), 'custom.wav');
    await model.ask('Where is the festival?');
    await model.speak();
    expect(model.audioBytes, isNotNull);
    model.selectVoice('alternate');
    expect(model.voiceId, 'alternate');
    expect(model.speakerReference, isNull);
    expect(model.audioBytes, isNull);
    expect(model.voiceLabel, 'Mo · Alternate');
    model.beginInput('Recording');
    model.selectVoice('original');
    expect(model.voiceId, 'alternate');
    model.endInput();
    model.dispose();
  });
}
