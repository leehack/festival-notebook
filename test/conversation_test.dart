import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/notebook_controller.dart';
import 'package:festival_notebook/festival_ai.dart';
import 'support/fake_festival_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Transcript, answer, speech and illustration use the current turn',
    () async {
      final service = FakeFestivalService();
      final model = NotebookController(service: service);
      model.useReference(Uint8List.fromList([1]), 'reference.wav');
      final transcript = await model.listen(bytes: Uint8List.fromList([2]));
      await model.ask(transcript!);
      await model.speak();
      await model.illustrate();
      expect(service.calls, [
        'transcribe',
        'retrieve:Where is the festival?',
        'answer:en:0',
        'speak:en',
        'scene:The festival is in the village hall.',
        'draw:Llamas celebrating inside the village hall',
      ]);
      expect(model.audioBytes, isNotNull);
      expect(model.imageBytes, isNotNull);
      await model.ask('And the pies?');
      expect(model.audioBytes, isNull);
      expect(model.imageBytes, isNull);
      expect(model.imagePrompt, isNull);
      expect(model.busy, isFalse);
      model.dispose();
    },
  );

  test('Speech failure preserves the answer and can be retried', () async {
    final service = FakeFestivalService()..failSpeech = true;
    final model = NotebookController(service: service);
    model.useReference(Uint8List.fromList([1]), 'reference.wav');
    await model.ask('Where?');
    await model.speak();
    expect(model.reply, service.response);
    expect(model.error, contains('speech failed'));
    expect(model.busy, isFalse);
    service.failSpeech = false;
    await model.speak();
    expect(model.error, isNull);
    expect(model.audioBytes, isNotNull);
    model.dispose();
  });

  test('Bundled Dash sample resolves through the asset bundle', () async {
    final model = NotebookController(service: FakeFestivalService());
    expect(await model.listen(), 'Where is the festival?');
    expect(model.error, isNull);
    model.dispose();
  });

  test('Note embeddings are cached and a failed load can retry', () async {
    final cache = NoteEmbeddingCache();
    var loads = 0;
    Future<List<List<double>>> load() async {
      loads++;
      if (loads == 1) throw StateError('interrupted');
      return [
        [1, 0],
        [0, 1],
      ];
    }

    await expectLater(cache.getOrLoad(load), throwsStateError);
    final vectors = await cache.getOrLoad(load);
    expect(await cache.getOrLoad(load), same(vectors));
    expect(loads, 2);
  });
}
