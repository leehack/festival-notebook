import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:festival_notebook/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('The shared text flow finds the festival hall', (tester) async {
    await tester.pumpWidget(const FestivalApp());
    await tester.pumpAndSettle();
    final dynamic screen = tester.state(find.byType(NotebookScreen));
    screen.autoSpeak = false;
    await tester.ensureVisible(find.byKey(const Key('ask')));
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pump(const Duration(seconds: 1));
    final deadline = DateTime.now().add(const Duration(minutes: 15));
    while (screen.model.busy as bool) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Model step timed out');
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.ensureVisible(find.byKey(const Key('answer')));
    final answer = tester
        .widget<SelectableText>(find.byKey(const Key('answer')))
        .data!;
    expect(answer.toLowerCase(), contains('village hall'));
    expect(answer.length, lessThan(200));
    expect(answer.toLowerCase(), isNot(contains("hasn't started")));
    expect(answer.toLowerCase(), isNot(contains('half past five')));

    // A second turn uses the cached note vectors with a fresh engine.
    await screen.model.ask('It is raining. Where is the Berry Festival now?');
    expect(screen.model.error, isNull);
    expect(screen.model.reply.toLowerCase(), contains('village hall'));
    expect(screen.model.hits.first.index, 0);
  });
}
