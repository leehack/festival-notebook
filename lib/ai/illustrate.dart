import 'dart:typed_data';

import 'package:llamadart/llamadart.dart';

import 'models.dart';

/// Draw the supplied scene using SDXS, or SD-Turbo for more detail.
Future<Uint8List> illustrate({
  bool detailed = false,
  required String prompt,
  int seed = 42,
  ModelDownloadProgressCallback? onProgress,
  void Function(String)? onPhase,
}) async {
  final runtime = await ImageGenerationEngine.checkRuntime();
  if (!runtime.isSupported) throw StateError('${runtime.unsupportedReason}');
  final engine = await ImageGenerationEngine.load(
    detailed ? detailedImageModel : fastImageModel,
    onProgress: onProgress,
  );
  try {
    final task = await engine.generate(
      ImageGenerationRequest(
        prompt: prompt,
        width: 512,
        height: 512,
        steps: detailed ? 4 : 1,
        guidanceScale: 1,
        seed: seed,
      ),
    );
    final sub = task.events.listen((event) {
      if (event case ImageGenerationProgressEvent(
        :final phase,
        :final step,
        :final steps,
      )) {
        onPhase?.call('${phase.name} $step/$steps');
      }
    });
    try {
      final result = await task.result;
      return result.images.first.toPng();
    } finally {
      await sub.cancel();
    }
  } finally {
    await engine.dispose();
  }
}
