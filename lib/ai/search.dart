import 'package:llamadart/llamadart.dart';

import '../festival_data.dart';
import 'models.dart';

Future<List<NoteHit>> retrieve(
  String question, {
  NoteEmbeddingCache? cache,
  ModelDownloadProgressCallback? onProgress,
}) async {
  final engine = await LlamaEngine.load(
    embeddingModel,
    params: textParams,
    onProgress: onProgress,
  );
  try {
    Future<List<List<double>>> embedNotes() => engine.embedBatch(
      notes.map((n) => 'title: ${n.title} | text: ${n.text}').toList(),
      normalize: true,
    );
    final docs = await (cache == null
        ? embedNotes()
        : cache.getOrLoad(embedNotes));
    final query = await engine.embed(
      'task: search result | query: $question',
      normalize: true,
    );
    return [
      for (var i = 0; i < notes.length; i++)
        (index: i, score: _dot(query, docs[i])),
    ]..sort((a, b) => b.score.compareTo(a.score));
  } finally {
    await engine.dispose();
  }
}

double _dot(List<double> a, List<double> b) {
  if (a.length != b.length) throw StateError('Embedding dimensions differ');
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

/// Keeps only the fixed note vectors, never a model or native engine.
class NoteEmbeddingCache {
  Future<List<List<double>>>? _vectors;

  Future<List<List<double>>> getOrLoad(
    Future<List<List<double>>> Function() load,
  ) async {
    try {
      return await (_vectors ??= load());
    } catch (_) {
      _vectors = null;
      rethrow;
    }
  }
}
