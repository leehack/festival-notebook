import 'package:llamadart/llamadart.dart';

import 'models.dart';

/// Shared by Mo's answer and the optional image-prompt translation.
Future<String> generateText({
  required String system,
  required String prompt,
  required int maxTokens,
  ModelDownloadProgressCallback? onProgress,
}) async {
  final engine = await LlamaEngine.load(
    dialogueModel,
    params: textParams,
    onProgress: onProgress,
  );
  try {
    final output = StringBuffer();
    await for (final chunk in engine.create(
      [
        LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt),
      ],
      enableThinking: false,
      params: GenerationParams(maxTokens: maxTokens, temp: 0, seed: 42),
    )) {
      output.write(chunk.text);
    }
    final text = output.toString().trim();
    if (text.isEmpty) throw StateError('The model returned no text');
    return text;
  } finally {
    await engine.dispose();
  }
}
