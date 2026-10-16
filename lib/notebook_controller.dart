import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';

import 'festival_ai.dart' as ai;

/// UI state lives here; the model calls live in festival_ai.dart.
class NotebookController extends ChangeNotifier {
  bool busy = false;
  bool _closed = false;
  String? languageOverride;
  String replyLanguage = 'en';
  bool textUsed = false;
  bool speechUsed = false;
  bool imageUsed = false;
  int? lastImageSeed;
  String? imagePrompt;
  String question = '';
  String reply = '';
  String status = '';
  String? error;
  static const voices = {
    'original': 'Mo · Original',
    'alternate': 'Mo · Alternate',
  };
  String voiceId = 'original';
  String get voiceLabel => referenceName ?? voices[voiceId]!;

  void selectVoice(String id) {
    if (busy || !voices.containsKey(id)) return;
    voiceId = id;
    speakerReference = null;
    referenceName = null;
    audioBytes = null;
    update();
  }

  Future<Uint8List> voiceReference() async {
    if (speakerReference != null) return speakerReference!;
    final data = await rootBundle.load('assets/mo-$voiceId.wav');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Uint8List? speakerReference;
  String? referenceName;
  Uint8List? audioBytes;
  Uint8List? imageBytes;
  double? progress;
  List<({int index, double score})> hits = [];
  final times = <String, int>{};

  void update() {
    if (!_closed) notifyListeners();
  }

  void download(ModelDownloadProgress p) {
    progress = p.fraction;
    status = p.totalBytes == null
        ? 'Preparing the local model…'
        : 'Downloading ${(p.receivedBytes / 1e6).toStringAsFixed(0)} / ${(p.totalBytes! / 1e6).toStringAsFixed(0)} MB';
    update();
  }

  Future<T> stage<T>(String name, Future<T> Function() action) async {
    status = name;
    progress = null;
    update();
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      times[name] = watch.elapsedMilliseconds;
    }
  }

  Future<void> work(Future<void> Function() action) async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    update();
    try {
      await action();
    } catch (e) {
      error =
          'Something interrupted this step. Your notebook is still here.\n$e';
    } finally {
      busy = false;
      progress = null;
      status = '';
      update();
    }
  }

  Future<void> ask(String text) => work(() async {
    if (text.trim().isEmpty) return;
    question = text.trim();
    replyLanguage = languageOverride ?? ai.questionLanguage(question);
    reply = '';
    hits = [];
    audioBytes = null;
    imageBytes = null;
    imagePrompt = null;
    times.clear();
    hits = await stage(
      'Finding the right notes',
      () => ai.retrieve(question, onProgress: download),
    );
    if (_closed) return;
    reply = await stage(
      'Mo is writing an answer',
      () => ai.answer(
        question,
        hits,
        language: replyLanguage,
        onProgress: download,
      ),
    );
    textUsed = true;
  });
  Future<String?> listen({Uint8List? bytes}) async {
    String? transcript;
    await work(() async {
      if (bytes == null) {
        final data = await rootBundle.load('assets/question.wav');
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      transcript = await stage(
        'Listening to Dash',
        () => ai.transcribe(bytes!, onProgress: download),
      );
    });
    return transcript;
  }

  Future<void> speak() => work(() async {
    if (reply.isEmpty) return;
    final reference = await voiceReference();
    if (_closed) return;
    audioBytes = await stage(
      'Giving Mo a voice',
      () => ai.speak(
        reply.replaceAll(RegExp(r'\[[^\]]+\]'), ''),
        speakerReference: reference,
        language: replyLanguage,
        onProgress: download,
      ),
    );
    speechUsed = true;
  });
  bool detailedImages = false;
  bool? lastImageDetailed;

  Future<void> illustrate() => work(() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Image generation is available in the native app.',
      );
    }
    if (reply.isEmpty) return;
    final prompt = await stage(
      'Imagining your conversation',
      () => ai.describeScene(
        question,
        reply,
        language: replyLanguage,
        onProgress: download,
      ),
    );
    if (_closed) return;
    final seed = Random().nextInt(0x7fffffff);
    imageBytes = await stage(
      'Drawing your conversation',
      () => ai.illustrate(
        detailed: detailedImages,
        seed: seed,
        prompt: prompt,
        onProgress: download,
        onPhase: (phase) {
          status = 'Drawing · $phase';
          update();
        },
      ),
    );
    imageUsed = true;
    lastImageDetailed = detailedImages;
    lastImageSeed = seed;
    imagePrompt = prompt;
  });
  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
