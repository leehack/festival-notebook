import 'dart:math';
import 'dart:typed_data';

/// Lightweight energy endpointing, not a neural speech detector.
/// 20 ms frames of mono 16 kHz PCM; ignores brief noises and leading silence.
class SilenceDetector {
  final double threshold;
  SilenceDetector({this.threshold = 0.015});
  int _lowByte = -1;
  int _samples = 0;
  double _squares = 0;
  int _voicedFrames = 0;
  int _quietFrames = 0;
  int _frames = 0;
  bool hasSpeech = false;
  bool ended = false;

  /// Returns true once, after 1.2 s silence following sound, or 5 s without speech.
  bool add(Uint8List bytes) {
    if (ended) return false;
    for (final byte in bytes) {
      if (_lowByte < 0) {
        _lowByte = byte;
        continue;
      }
      var sample = _lowByte | (byte << 8);
      _lowByte = -1;
      if (sample >= 32768) sample -= 65536;
      _squares += pow(sample / 32768, 2);
      if (++_samples < 320) continue;
      final audible = sqrt(_squares / _samples) >= threshold;
      _samples = 0;
      _squares = 0;
      _frames++;
      if (audible) {
        _voicedFrames++;
        _quietFrames = 0;
        if (_voicedFrames >= 13) hasSpeech = true;
      } else {
        _quietFrames++;
        if (!hasSpeech) _voicedFrames = 0;
      }
      if ((hasSpeech && _quietFrames >= 60) || (!hasSpeech && _frames >= 250)) {
        ended = true;
        return true;
      }
    }
    return false;
  }
}
