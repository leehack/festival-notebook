import 'dart:typed_data';

import 'package:llamadart/llamadart.dart';

import 'ai/answer.dart' as chat;
import 'ai/image_prompt.dart' as scenes;
import 'ai/illustrate.dart' as images;
import 'ai/search.dart' as search;
import 'ai/speak.dart' as speech;
import 'ai/transcribe.dart' as transcription;

import 'festival_data.dart';

/// The controller uses this small boundary; each SDK example lives in ai/.
class FestivalService {
  final _notes = search.NoteEmbeddingCache();

  Future<List<NoteHit>> retrieve(
    String question, {
    ModelDownloadProgressCallback? onProgress,
  }) => search.retrieve(question, cache: _notes, onProgress: onProgress);

  Future<String> answer(
    String question,
    List<NoteHit> hits, {
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) => chat.answer(question, hits, language: language, onProgress: onProgress);

  Future<String> transcribe(
    Uint8List bytes, {
    ModelDownloadProgressCallback? onProgress,
  }) => transcription.transcribe(bytes, onProgress: onProgress);

  Future<Uint8List> speak(
    String reply, {
    required Uint8List speakerReference,
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) => speech.speak(
    reply,
    speakerReference: speakerReference,
    language: language,
    onProgress: onProgress,
  );

  Future<String> describeScene(
    String reply, {
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) => scenes.describeScene(reply, language: language, onProgress: onProgress);

  Future<Uint8List> illustrate({
    required bool detailed,
    required int seed,
    required String prompt,
    ModelDownloadProgressCallback? onProgress,
    void Function(String)? onPhase,
  }) => images.illustrate(
    detailed: detailed,
    seed: seed,
    prompt: prompt,
    onProgress: onProgress,
    onPhase: onPhase,
  );
}
