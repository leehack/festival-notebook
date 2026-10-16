import 'dart:typed_data';

import 'package:llamadart/llamadart.dart';

import 'festival_ai.dart' as ai;

typedef NoteHit = ({int index, double score});

/// Injectable boundary for the controller. The SDK examples stay in festival_ai.
class FestivalService {
  final _notes = ai.NoteEmbeddingCache();

  Future<List<NoteHit>> retrieve(
    String question, {
    ModelDownloadProgressCallback? onProgress,
  }) => ai.retrieve(question, cache: _notes, onProgress: onProgress);

  Future<String> answer(
    String question,
    List<NoteHit> hits, {
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) => ai.answer(question, hits, language: language, onProgress: onProgress);

  Future<String> transcribe(
    Uint8List bytes, {
    ModelDownloadProgressCallback? onProgress,
  }) => ai.transcribe(bytes, onProgress: onProgress);

  Future<Uint8List> speak(
    String reply, {
    required Uint8List speakerReference,
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) => ai.speak(
    reply,
    speakerReference: speakerReference,
    language: language,
    onProgress: onProgress,
  );

  Future<String> describeScene(
    String question,
    String reply, {
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) => ai.describeScene(
    question,
    reply,
    language: language,
    onProgress: onProgress,
  );

  Future<Uint8List> illustrate({
    required bool detailed,
    required int seed,
    required String prompt,
    ModelDownloadProgressCallback? onProgress,
    void Function(String)? onPhase,
  }) => ai.illustrate(
    detailed: detailed,
    seed: seed,
    prompt: prompt,
    onProgress: onProgress,
    onPhase: onPhase,
  );
}
