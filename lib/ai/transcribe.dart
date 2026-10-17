import 'dart:typed_data';

import 'package:llamadart/llamadart.dart';

import 'models.dart';

/// Turn a WAV recording into text. The caller decides when to send it to Mo.
Future<String> transcribe(
  Uint8List bytes, {
  ModelDownloadProgressCallback? onProgress,
}) async {
  final engine = await SpeechToTextEngine.load(
    transcriptionModel,
    params: textParams,
    onProgress: onProgress,
  );
  try {
    final result = await engine.transcribeOnce(
      SpeechToTextRequest(
        audio: SpeechAudioBytesInput(
          bytes,
          format: const SpeechAudioFormat(
            encoding: 'wav',
            mimeType: 'audio/wav',
          ),
        ),
        contextPrompt: 'Dash, Mo, Berry Festival, village hall',
      ),
    );
    if (result.text.trim().isEmpty) throw StateError('No speech recognized');
    return result.text.trim();
  } finally {
    await engine.dispose();
  }
}
