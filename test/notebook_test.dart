import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/main.dart';

void main() {
  for (final width in [1200.0, 390.0]) {
    testWidgets('Notebook fits a $width pixel window', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const FestivalApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('question')), findsOneWidget);
      expect(find.text('First, ask Mo about the rain.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Who won last year?'));
      await tester.tap(find.text('Who won last year?'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('question')))
            .controller!
            .text,
        'Who won last year?',
      );
      await tester.ensureVisible(find.text('Speak as Dash'));
      await tester.tap(find.text('Speak as Dash'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-dash')), findsOneWidget);
      expect(find.byKey(const Key('record-question')), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('Transcribe sample'), findsNothing);
      final dynamic screen = tester.state(find.byType(NotebookScreen));
      screen.model.reply = 'June and Pip are rehearsing beside the stage.';
      screen.model.update();
      await tester.pumpAndSettle();
      final answer = tester.getTopLeft(find.text('A WORD FROM MO'));
      final illustration = tester.getTopLeft(find.text('Mo’s illustration'));
      expect(illustration.dx, closeTo(answer.dx, 1));
      expect(illustration.dy, greaterThan(answer.dy));
      await tester.ensureVisible(find.byKey(const Key('voice-settings')));
      await tester.tap(find.byKey(const Key('voice-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Give Mo a voice'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('open-voice-recorder')));
      expect(
        tester.getRect(find.byType(AlertDialog)).width,
        lessThanOrEqualTo(width),
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
