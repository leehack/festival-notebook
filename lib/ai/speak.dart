import 'dart:typed_data';

import 'package:llamadart/llamadart.dart';

import 'models.dart';

/// Generate one reply, then release the speech engine.
Future<Uint8List> speak(
  String text, {
  Uint8List? speakerReference,
  int seed = 42,
  String language = 'en',
  ModelDownloadProgressCallback? onProgress,
}) async {
  final engine = await TextToSpeechEngine.load(
    speechModel,
    params: speechParams,
    onProgress: onProgress,
  );
  try {
    return await synthesizeSpeech(
      engine,
      text,
      speakerReference: speakerReference,
      seed: seed,
      language: language,
    );
  } finally {
    await engine.dispose();
  }
}

Future<Uint8List> synthesizeSpeech(
  TextToSpeechEngine engine,
  String text, {
  Uint8List? speakerReference,
  int seed = 42,
  String language = 'en',
}) async {
  if (speakerReference != null &&
      !(await engine.capabilities).supportsSpeakerReference) {
    throw UnsupportedError(
      'This model/runtime cannot use a reference voice. Choose the default voice.',
    );
  }
  final result = await engine.synthesizeOnce(
    TextToSpeechRequest(
      text: text,
      language: language,
      seed: seed,
      promptBatchSize: 64,
      speakerReference: speakerReference == null
          ? null
          : SpeechAudioBytesInput(
              speakerReference,
              format: const SpeechAudioFormat(
                encoding: 'wav',
                mimeType: 'audio/wav',
              ),
            ),
    ),
  );
  if (result.truncated) {
    throw StateError('Speech reached its length limit. Try a shorter reply.');
  }
  final wav = result.toWavBytes();
  if (wav.length <= 44) throw StateError('Empty audio');
  return wav;
}
