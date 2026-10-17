import 'package:llamadart/llamadart.dart';

import 'generate_text.dart';

/// Image models need an English scene. English answers skip translation.
Future<String> describeScene(
  String reply, {
  required String language,
  ModelDownloadProgressCallback? onProgress,
}) async {
  if (language == 'en') return villageImagePrompt(reply);
  final translation = await generateText(
    system:
        'You translate text into English. Output only the English translation. '
        'Preserve the meaning. Do not output Korean. Do not explain.',
    prompt:
        'Translate into English:\n${reply.replaceAll('베리 축제', 'Berry Festival').replaceAll('마을 회관', 'village hall')}',
    maxTokens: 120,
    onProgress: onProgress,
  );
  return villageImagePrompt(translation);
}

/// Keep the action first: the image model has a short text-conditioning window.
/// Names alone carry no visual identity for an untrained image model.
String villageImagePrompt(String scene) {
  var visual = scene.trim().replaceAll(RegExp(r'[.!]+$'), '');
  visual = visual.replaceAll(
    RegExp(r'June and Pip', caseSensitive: false),
    'two woolly llamas',
  );
  visual = visual
      .replaceAllMapped(
        RegExp(r'\b(June|Pip|Mo|Bramble|Clover)\b', caseSensitive: false),
        (m) => m[0]!.toLowerCase() == 'mo'
            ? 'a woolly llama baker'
            : 'a woolly llama',
      )
      .replaceAll(
        RegExp(r'\bDash\b', caseSensitive: false),
        'a small blue bird',
      );
  visual = visual.replaceAll(
    RegExp(r'rehearse their song', caseSensitive: false),
    'sing together',
  );
  // Render a stated move indoors as an interior, not an exterior of the hall.
  // Only apply this to affirmative descriptions of the move or its rain plan.
  final lower = visual.toLowerCase();
  if (lower.contains('festival') &&
      lower.contains('rain') &&
      lower.contains('village hall') &&
      RegExp(r'\b(move|moved|moves|moving)\b').hasMatch(lower) &&
      !RegExp(r"\b(not|never|unknown)\b|don't|do not").hasMatch(lower)) {
    return 'Woolly llama villagers inside a wooden village hall, '
        'rain outside the windows. '
        'Colorful storybook illustration';
  }
  return '$visual. Colorful storybook illustration';
}
