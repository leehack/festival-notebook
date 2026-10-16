import 'package:flutter_test/flutter_test.dart';
import 'package:festival_notebook/festival_ai.dart';

void main() {
  test('Hangul selects Korean while English keeps the English default', () {
    expect(questionLanguage('비 온다는데 어떻게?'), 'ko');
    expect(questionLanguage('Where should Dash go?'), 'en');
    expect(questionLanguage('Dash, 비가 와요'), 'ko');
  });
}
