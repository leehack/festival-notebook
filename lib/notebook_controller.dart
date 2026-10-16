import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';

import 'festival_ai.dart' as ai;
import 'festival_service.dart';

/// UI state lives here; the model calls live in festival_ai.dart.
class NotebookController extends ChangeNotifier {
  NotebookController({FestivalService? service})
    : _service = service ?? FestivalService();
  final FestivalService _service;

  bool _busy = false;
  bool _closed = false;
  bool _inputActive = false;
  String? _languageOverride;
  String _replyLanguage = 'en';
  bool _textUsed = false;
  bool _speechUsed = false;
  bool _imageUsed = false;
  int? _lastImageSeed;
  String? _imagePrompt;
  String _question = '';
  String _reply = '';
  String _status = '';
  String? _error;
  static const voices = {
    'original': 'Mo · Original',
    'alternate': 'Mo · Alternate',
  };
  String _voiceId = 'original';
  String get voiceLabel => _referenceName ?? voices[_voiceId]!;

  bool get busy => _busy;
  String? get languageOverride => _languageOverride;
  String get replyLanguage => _replyLanguage;
  bool get textUsed => _textUsed;
  bool get speechUsed => _speechUsed;
  bool get imageUsed => _imageUsed;
  int? get lastImageSeed => _lastImageSeed;
  String? get imagePrompt => _imagePrompt;
  String get question => _question;
  String get reply => _reply;
  String get status => _status;
  String? get error => _error;
  String get voiceId => _voiceId;
  Uint8List? get speakerReference => _speakerReference;
  String? get referenceName => _referenceName;
  Uint8List? get audioBytes => _audioBytes;
  Uint8List? get imageBytes => _imageBytes;
  double? get progress => _progress;
  List<({int index, double score})> get hits => List.unmodifiable(_hits);
  bool get detailedImages => _detailedImages;
  bool? get lastImageDetailed => _lastImageDetailed;

  bool beginInput(String message) {
    if (_busy || _closed) return false;
    _inputActive = true;
    _busy = true;
    _error = null;
    _status = message;
    _update();
    return true;
  }

  void endInput() {
    if (!_inputActive) return;
    _inputActive = false;
    _busy = false;
    _status = '';
    _update();
  }

  void reportError(String? message) {
    _error = message;
    _update();
  }

  void inputStatus(String message) {
    if (!_inputActive || _closed) return;
    _status = message;
    _update();
  }

  void setAnswerLanguage(String? value) {
    if (_busy || _closed) return;
    _languageOverride = value;
    _update();
  }

  void setSpeechLanguage(String value) {
    if (_busy || _closed) return;
    _replyLanguage = value;
    _audioBytes = null;
    _update();
  }

  void setDetailedImages(bool value) {
    if (_busy || _closed) return;
    _detailedImages = value;
    _update();
  }

  void useReference(Uint8List bytes, String name) {
    if (_busy || _closed) return;
    _speakerReference = bytes;
    _referenceName = name;
    _audioBytes = null;
    _update();
  }

  void selectVoice(String id) {
    if (_busy || _closed || !voices.containsKey(id)) return;
    _voiceId = id;
    _speakerReference = null;
    _referenceName = null;
    _audioBytes = null;
    _update();
  }

  Future<Uint8List> voiceReference() async {
    if (_speakerReference != null) return _speakerReference!;
    final data = await rootBundle.load('assets/mo-$_voiceId.wav');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Uint8List? _speakerReference;
  String? _referenceName;
  Uint8List? _audioBytes;
  Uint8List? _imageBytes;
  double? _progress;
  List<({int index, double score})> _hits = [];
  Map<String, int> get times => Map.unmodifiable(_times);
  final _times = <String, int>{};

  void _update() {
    if (!_closed) notifyListeners();
  }

  void download(ModelDownloadProgress p) {
    _progress = p.fraction;
    _status = p.totalBytes == null
        ? 'Preparing the local model…'
        : 'Downloading ${(p.receivedBytes / 1e6).toStringAsFixed(0)} / ${(p.totalBytes! / 1e6).toStringAsFixed(0)} MB';
    _update();
  }

  Future<T> stage<T>(String name, Future<T> Function() action) async {
    _status = name;
    _progress = null;
    _update();
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      _times[name] = watch.elapsedMilliseconds;
    }
  }

  Future<void> work(Future<void> Function() action) async {
    if (_busy || _closed) return;
    _busy = true;
    _error = null;
    _update();
    try {
      await action();
    } catch (e) {
      _error =
          'Something interrupted this step. Your notebook is still here.\n$e';
    } finally {
      _busy = false;
      _progress = null;
      _status = '';
      _update();
    }
  }

  Future<void> ask(String text) => work(() async {
    if (text.trim().isEmpty) return;
    _question = text.trim();
    _replyLanguage = _languageOverride ?? ai.questionLanguage(_question);
    _reply = '';
    _hits = [];
    _audioBytes = null;
    _imageBytes = null;
    _imagePrompt = null;
    _times.clear();
    _hits = await stage(
      'Finding the right notes',
      () => _service.retrieve(_question, onProgress: download),
    );
    if (_closed) return;
    _reply = await stage(
      'Mo is writing an answer',
      () => _service.answer(
        _question,
        _hits,
        language: _replyLanguage,
        onProgress: download,
      ),
    );
    _textUsed = true;
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
        () => _service.transcribe(bytes!, onProgress: download),
      );
    });
    return transcript;
  }

  Future<void> speak() => work(() async {
    if (_reply.isEmpty) return;
    final reference = await voiceReference();
    if (_closed) return;
    _audioBytes = await stage(
      'Giving Mo a voice',
      () => _service.speak(
        _reply.replaceAll(RegExp(r'\[[^\]]+\]'), ''),
        speakerReference: reference,
        language: _replyLanguage,
        onProgress: download,
      ),
    );
    _speechUsed = true;
  });
  bool _detailedImages = false;
  bool? _lastImageDetailed;

  Future<void> illustrate() => work(() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Image generation is available in the native app.',
      );
    }
    if (_reply.isEmpty) return;
    final prompt = await stage(
      'Imagining your conversation',
      () => _service.describeScene(
        _question,
        _reply,
        language: _replyLanguage,
        onProgress: download,
      ),
    );
    if (_closed) return;
    final seed = Random().nextInt(0x7fffffff);
    _imageBytes = await stage(
      'Drawing your conversation',
      () => _service.illustrate(
        detailed: _detailedImages,
        seed: seed,
        prompt: prompt,
        onProgress: download,
        onPhase: (phase) {
          _status = 'Drawing · $phase';
          _update();
        },
      ),
    );
    _imageUsed = true;
    _lastImageDetailed = _detailedImages;
    _lastImageSeed = seed;
    _imagePrompt = prompt;
  });
  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
