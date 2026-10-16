import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/festival_ai.dart';

void main() {
  test('Action stays first and names become visible animal descriptions', () {
    final prompt = villageImagePrompt(
      'June and Pip rehearse their song beside the outdoor stage.',
    );
    expect(
      prompt,
      startsWith('two woolly llamas sing together beside the outdoor stage'),
    );
    expect(prompt, isNot(contains('pies')));
    expect(
      villageImagePrompt('Mo carries berry pies to the hall.'),
      startsWith('a woolly llama baker carries berry pies to the hall'),
    );
    expect(
      villageImagePrompt('Dash visits Mo.'),
      startsWith('a small blue bird visits a woolly llama baker'),
    );
  });
  test('Indoor move is visualized without reversing a negated answer', () {
    expect(
      villageImagePrompt(
        'The festival moves to the village hall when it rains.',
      ),
      contains('inside a wooden village hall'),
    );
    expect(
      villageImagePrompt('The festival does not move to the village hall.'),
      isNot(contains('inside a wooden village hall')),
    );
  });
}
