import 'dart:typed_data';

import 'package:festival_notebook/festival_service.dart';
import 'package:llamadart/llamadart.dart';

class FakeFestivalService extends FestivalService {
  final calls = <String>[];
  bool failSpeech = false;
  String response = 'The festival is in the village hall.';

  @override
  Future<List<NoteHit>> retrieve(
    String question, {
    ModelDownloadProgressCallback? onProgress,
  }) async {
    calls.add('retrieve:$question');
    return [(index: 0, score: 1)];
  }

  @override
  Future<String> answer(
    String question,
    List<NoteHit> hits, {
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    calls.add('answer:$language:${hits.first.index}');
    return response;
  }

  @override
  Future<String> transcribe(
    Uint8List bytes, {
    ModelDownloadProgressCallback? onProgress,
  }) async {
    calls.add('transcribe');
    return 'Where is the festival?';
  }

  @override
  Future<Uint8List> speak(
    String reply, {
    required Uint8List speakerReference,
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    calls.add('speak:$language');
    if (failSpeech) throw StateError('speech failed');
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<String> describeScene(
    String question,
    String reply, {
    required String language,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    calls.add('scene:$reply');
    return 'Llamas celebrating inside the village hall';
  }

  @override
  Future<Uint8List> illustrate({
    required bool detailed,
    required int seed,
    required String prompt,
    ModelDownloadProgressCallback? onProgress,
    void Function(String)? onPhase,
  }) async {
    calls.add('draw:$prompt');
    return Uint8List.fromList([4, 5, 6]);
  }
}
