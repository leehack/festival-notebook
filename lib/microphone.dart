import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'silence_detector.dart';

/// Capture bounded mono PCM in memory. Recognition still runs in llamadart.
class Microphone {
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  final _pcm = BytesBuilder(copy: false);
  Completer<void>? _done;
  Object? _error;
  int _length = 0;
  static const maxBytes = 16000 * 2 * 20;

  Future<void> start({void Function(bool hasSpeech)? onSilence}) async {
    final detector = SilenceDetector();
    if (!await _recorder.hasPermission()) {
      throw StateError(
        'Microphone access was denied. Enable it in system settings or use Dash’s sample.',
      );
    }
    _pcm.clear();
    _length = 0;
    _error = null;
    _done = Completer<void>();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _subscription = stream.listen(
      (bytes) {
        final remaining = maxBytes - _length;
        if (remaining <= 0) return;
        final take = bytes.length < remaining ? bytes.length : remaining;
        _pcm.add(Uint8List.sublistView(bytes, 0, take));
        _length += take;
        if (onSilence != null && detector.add(bytes)) {
          scheduleMicrotask(() => onSilence(detector.hasSpeech));
        }
      },
      onError: (Object error) {
        _error = error;
      },
      onDone: () {
        if (!_done!.isCompleted) _done!.complete();
      },
    );
  }

  Future<Uint8List> stop({bool discard = false}) async {
    try {
      await _recorder.stop();
      await _done?.future.timeout(const Duration(seconds: 3));
      if (discard) {
        _pcm.clear();
        return Uint8List(0);
      }
      if (_error != null) throw StateError('Recording failed: $_error');
      final pcm = _pcm.takeBytes();
      if (pcm.length < 3200) {
        throw StateError(
          'Recording was too short. Try speaking for a few seconds.',
        );
      }
      return pcm16Wav(pcm);
    } finally {
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _recorder.dispose();
    _pcm.clear();
  }
}

Uint8List pcm16Wav(Uint8List pcm) {
  final length = pcm.length - pcm.length % 2;
  final bytes = Uint8List(44 + length);
  final header = ByteData.sublistView(bytes);
  void tag(int offset, String text) =>
      bytes.setRange(offset, offset + text.length, text.codeUnits);
  tag(0, 'RIFF');
  header.setUint32(4, 36 + length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, length, Endian.little);
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}
