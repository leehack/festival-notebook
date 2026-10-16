import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'audio_source.dart';
import 'microphone.dart';
import 'silence_detector.dart';

/// Record, review, then explicitly apply a voice. Never sends it as a question.
class VoiceRecorderDialog extends StatefulWidget {
  const VoiceRecorderDialog({super.key, this.microphone});
  final Microphone? microphone;
  @override
  State<VoiceRecorderDialog> createState() => _VoiceRecorderDialogState();
}

class _VoiceRecorderDialogState extends State<VoiceRecorderDialog>
    with WidgetsBindingObserver {
  late final mic = widget.microphone ?? Microphone();
  final player = AudioPlayer();
  Timer? timer;
  bool recording = false, working = false, playing = false;
  int seconds = 0;
  Uint8List? take;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && recording) {
      unawaited(stop(discard: true));
    }
  }

  Future<void> start() async {
    if (working || recording) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await player.stop();
      await mic.start();
      if (!mounted) {
        await mic.stop(discard: true);
        return;
      }
      setState(() {
        recording = true;
        playing = false;
        seconds = 0;
        take = null;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => seconds++);
        if (seconds >= 12) unawaited(stop());
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> stop({bool discard = false}) async {
    if (!recording || working) return;
    timer?.cancel();
    setState(() {
      recording = false;
      working = true;
    });
    try {
      final bytes = await mic.stop(discard: discard);
      if (!mounted) return;
      if (discard) {
        setState(
          () =>
              error = 'Recording canceled when the app lost focus. Try again.',
        );
        return;
      }
      final validation = validateVoiceTake(bytes);
      setState(() {
        error = validation;
        take = validation == null ? bytes : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> preview() async {
    try {
      await player.stop();
      if (!playing) await player.play(await audioSource(take!));
      if (mounted) setState(() => playing = !playing);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not play recording: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    unawaited(mic.dispose());
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !working,
    child: AlertDialog(
      title: const Text('Lend Mo your voice'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Speak naturally for 5–12 seconds in a quiet place. Use the voice you would like Mo to follow.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xffedf0e3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '“Hello, welcome to the village. Come inside, and we can plan the festival together.”',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Or say something in your own language. Recording stays on this device. Tone may vary in generated speech.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (recording) ...[
                Text(
                  'Recording · ${seconds}s / 12s',
                  semanticsLabel: 'Recording, $seconds seconds',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: seconds / 12),
                const SizedBox(height: 12),
              ],
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('record-reference'),
                    onPressed: working
                        ? null
                        : recording
                        ? () => stop()
                        : start,
                    icon: Icon(recording ? Icons.stop : Icons.mic),
                    label: Text(
                      recording
                          ? 'Stop recording'
                          : take == null
                          ? 'Start recording'
                          : 'Record again',
                    ),
                  ),
                  if (take != null)
                    OutlinedButton.icon(
                      key: const Key('preview-reference'),
                      onPressed: working ? null : preview,
                      icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        playing ? 'Stop playback' : 'Listen to recording',
                      ),
                    ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: working ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('use-recorded-voice'),
          onPressed: working || recording || take == null
              ? null
              : () => Navigator.pop(context, take),
          child: const Text('Use this voice'),
        ),
      ],
    ),
  );
}

/// Input is the mono 16 kHz PCM WAV created by Microphone, not an arbitrary WAV.
String? validateVoiceTake(Uint8List bytes) {
  if (bytes.length < 44 + 32000 * 3) {
    return 'Please record at least three seconds of speech.';
  }
  final detector = SilenceDetector();
  detector.add(Uint8List.sublistView(bytes, 44));
  if (!detector.hasSpeech) {
    return 'No clear voice detected. Move closer to the microphone and try again.';
  }
  return null;
}
