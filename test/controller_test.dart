import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/notebook_controller.dart';

import 'support/fake_festival_service.dart';

void main() {
  test(
    'An optional-step failure preserves the answer and releases busy state',
    () async {
      final model = NotebookController(service: FakeFestivalService());
      await model.ask('Where is the festival?');
      await model.work(() async {
        throw StateError('test failure');
      });
      expect(model.reply, 'The festival is in the village hall.');
      expect(model.error, contains('test failure'));
      expect(model.busy, isFalse);
      model.dispose();
    },
  );
  test(
    'Ending an old input does not unlock an active model operation',
    () async {
      final model = NotebookController();
      expect(model.beginInput('Recording'), isTrue);
      expect(model.beginInput('Another recording'), isFalse);
      model.endInput();
      final gate = Completer<void>();
      final work = model.work(() => gate.future);
      model.endInput();
      expect(model.busy, isTrue);
      gate.complete();
      await work;
      expect(model.busy, isFalse);
      model.dispose();
    },
  );

  test('Only one operation runs at a time', () async {
    final model = NotebookController();
    final gate = Completer<void>();
    var secondRan = false;
    final first = model.work(() => gate.future);
    await model.work(() async {
      secondRan = true;
    });
    expect(secondRan, isFalse);
    gate.complete();
    await first;
    expect(model.busy, isFalse);
    model.dispose();
  });
  test(
    'Finishing work after disposal does not notify removed listeners',
    () async {
      final model = NotebookController();
      final gate = Completer<void>();
      var count = 0;
      model.addListener(() => count++);
      final work = model.work(() => gate.future);
      expect(count, 1);
      model.dispose();
      gate.complete();
      await work;
      expect(count, 1);
    },
  );
}
