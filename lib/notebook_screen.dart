import 'dart:async';

import 'package:flutter/services.dart';

import 'microphone.dart';
import 'voice_recorder.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';

import 'notebook_controller.dart';
import 'audio_source.dart';
import 'widgets/village_style.dart';
import 'widgets/answer_card.dart';
import 'widgets/notebook_notes.dart';
import 'widgets/question_recording_controls.dart';
import 'widgets/illustration_card.dart';
import 'widgets/question_card.dart';
import 'widgets/voice_settings.dart';

import 'festival_service.dart';

final captureKey = GlobalKey();

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key, this.service});
  final FestivalService? service;
  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen>
    with WidgetsBindingObserver {
  late final model = NotebookController(service: widget.service);
  final input = TextEditingController(
    text: 'It is raining. Where is the Berry Festival now?',
  );
  final player = AudioPlayer();
  bool voiceMode = false;
  bool autoSpeak = true;
  int answerTurn = 0;
  bool autoStop = true;
  final answerSection = GlobalKey();
  bool playing = false;
  bool playingDash = false;
  bool recording = false;
  bool holdingMic = false;
  int? micPointer;
  int recordingSeconds = 0;
  bool stoppingRecording = false;
  final microphone = Microphone();
  Timer? recordingLimit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          playing = false;
          playingDash = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recordingLimit?.cancel();
    unawaited(microphone.dispose());
    model.dispose();
    input.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> ask() async {
    if (model.busy) return;
    final turn = ++answerTurn;
    await player.stop();
    if (!mounted) return;
    setState(() {
      playing = false;
      playingDash = false;
    });
    await model.ask(input.text);
    if (mounted && model.reply.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = answerSection.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 350),
            alignment: .15,
          );
        }
      });
      if (autoSpeak && model.error == null) {
        await model.speak();
        if (mounted &&
            turn == answerTurn &&
            autoSpeak &&
            model.error == null &&
            model.audioBytes != null) {
          await audio();
        }
      }
    }
  }

  Future<void> listen({bool file = false}) async {
    try {
      Uint8List? bytes;
      if (file) {
        final chosen = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(label: 'WAV audio', extensions: ['wav']),
          ],
        );
        if (chosen == null) return;
        bytes = await chosen.readAsBytes();
      }
      final text = await model.listen(bytes: bytes);
      if (mounted && text != null) {
        input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcript ready. Check it, then ask Mo.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open audio: $e')));
      }
    }
  }

  Future<void> playDash() async {
    if (model.busy) return;
    if (!model.beginInput('Dash is asking Mo')) return;
    StreamSubscription<void>? completion;
    try {
      await player.stop();
      final data = await rootBundle.load('assets/question.wav');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final finished = Completer<void>();
      completion = player.onPlayerComplete.listen((_) {
        if (!finished.isCompleted) finished.complete();
      });
      await player.play(await audioSource(bytes));
      if (!mounted) return;
      setState(() {
        playingDash = true;
        playing = false;
      });
      await finished.future.timeout(const Duration(seconds: 30));
      if (!mounted) return;
      model.endInput();
      final text = await model.listen(bytes: bytes);
      if (!mounted || text == null || text.trim().isEmpty) return;
      input.text = text;
      await ask();
    } catch (e) {
      if (mounted) model.reportError('Could not complete Dash’s question: $e');
    } finally {
      await completion?.cancel();
      if (mounted) {
        model.endInput();
        setState(() => playingDash = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && holdingMic) {
      endHold(cancelled: true);
    }
  }

  void beginHold() {
    if (model.busy || holdingMic || stoppingRecording) return;
    holdingMic = true;
    unawaited(recordQuestion());
  }

  void endHold({bool cancelled = false}) {
    holdingMic = false;
    micPointer = null;
    if (recording) unawaited(recordQuestion(submit: !cancelled));
  }

  Future<void> recordQuestion({bool submit = true}) async {
    if (stoppingRecording) return;
    if (recording) {
      recordingLimit?.cancel();
      stoppingRecording = true;
      try {
        final bytes = await microphone.stop(discard: !submit);
        model.endInput();
        if (!mounted) return;
        setState(() => recording = false);
        if (!submit) return;
        final text = await model.listen(bytes: bytes);
        if (mounted && text != null) {
          input.text = text;
          if (text.trim().isNotEmpty) await ask();
        }
      } catch (e) {
        model.reportError('$e');
      } finally {
        model.endInput();
        stoppingRecording = false;
        holdingMic = false;
        if (mounted) setState(() => recording = false);
      }
      return;
    }
    if (!model.beginInput('Preparing the microphone')) return;
    try {
      await player.stop();
      await microphone.start(
        onSilence: autoStop
            ? (hasSpeech) {
                if (!mounted || !recording || stoppingRecording) return;
                if (!hasSpeech) {
                  model.reportError(
                    'No speech detected. Try again or switch to hold-to-talk in a noisy room.',
                  );
                }
                endHold(cancelled: !hasSpeech);
              }
            : null,
      );
      if (!mounted) {
        await microphone.dispose();
        return;
      }
      if (!holdingMic) {
        await microphone.stop(discard: true);
        model.endInput();
        return;
      }
      setState(() {
        recordingSeconds = 0;
        recording = true;
        playing = false;
        playingDash = false;
      });
      model.inputStatus(
        autoStop
            ? 'Listening · a pause sends your question'
            : 'Recording · release to send',
      );
      recordingLimit = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => recordingSeconds++);
        if (recordingSeconds >= 20) endHold();
      });
    } catch (e) {
      model.endInput();
      model.reportError('$e');
    }
  }

  Future<void> previewVoice() async {
    if (model.busy) return;
    try {
      final bytes = await model.voiceReference();
      if (!mounted || model.busy) return;
      await player.stop();
      await player.play(await audioSource(bytes));
      if (mounted) {
        setState(() {
          playing = false;
          playingDash = false;
        });
      }
    } catch (e) {
      model.reportError('Could not preview this voice: $e');
    }
  }

  Future<void> chooseVoice() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Reference voice WAV', extensions: ['wav']),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 10 * 1024 * 1024) {
        throw StateError('Choose a short WAV under 10 MB.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await player.stop();
      model.useReference(bytes, file.name);
      setState(() {
        playing = false;
        playingDash = false;
      });
    } catch (e) {
      model.reportError('Could not use reference voice: $e');
    }
  }

  Future<void> audio() async {
    try {
      if (playing) {
        await player.stop();
      } else {
        await player.stop();
        playingDash = false;
        await player.play(await audioSource(model.audioBytes!));
      }
      if (mounted) setState(() => playing = !playing);
    } catch (e) {
      if (mounted) {
        model.reportError('Playback failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: captureKey,
    child: Scaffold(
      bottomNavigationBar: AnimatedBuilder(
        animation: model,
        builder: (context, _) => model.busy
            ? SafeArea(
                top: false,
                child: Material(
                  color: ink,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: model.progress,
                            strokeWidth: 2,
                            color: const Color(0xffead9b2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            model.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (recording)
                          TextButton(
                            onPressed: stoppingRecording
                                ? null
                                : recordQuestion,
                            child: const Text(
                              'Stop',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: model,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 900;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1250),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 36 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.spa_outlined, color: ink),
                              const SizedBox(width: 10),
                              Expanded(child: label('LLAMA VILLAGE')),

                              const Icon(
                                Icons.cloud_outlined,
                                size: 18,
                                color: muted,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'A rainy festival day',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                SizedBox(
                                  height: wide ? 220 : 210,
                                  width: double.infinity,
                                  child: Image.asset(
                                    'assets/festival-cover.png',
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0, -.15),
                                  ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withValues(alpha: .66),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 28,
                                  bottom: 25,
                                  right: 20,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DASH NEEDS YOUR HELP',
                                        style: TextStyle(
                                          color: Color(0xffead9b2),
                                          fontSize: 10,
                                          letterSpacing: 2.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Rain at the festival.\nLet’s get everyone indoors.',
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontSize: wide ? 34 : 26,
                                          height: 1.12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Mo has the notebook. Help Dash find the rain plan.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 20,
                            runSpacing: 10,
                            children: [
                              storyStep('1', 'Ask Mo', model.reply.isNotEmpty),
                              storyStep(
                                '2',
                                'Find the rain plan',
                                model.hits.isNotEmpty,
                              ),
                              storyStep(
                                '3',
                                'Hear or draw the plan',
                                model.audioBytes != null ||
                                    model.imageBytes != null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: conversation()),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 4,
                                  child: NotebookNotes(model: model),
                                ),
                              ],
                            )
                          else ...[
                            conversation(),
                            const SizedBox(height: 20),
                            NotebookNotes(model: model),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Local AI with llamadart · Models download on first use · A standalone Llama Village example',
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget storyStep(String number, String title, bool done) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: done ? ink : const Color(0xffe1dccd),
        child: done
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : Text(number, style: const TextStyle(fontSize: 12, color: ink)),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 12, color: ink)),
    ],
  );
  Widget autoVoiceControl() => Row(
    children: [
      Switch(
        value: autoSpeak,
        onChanged: (value) async {
          setState(() => autoSpeak = value);
          if (!value) {
            await player.stop();
            if (mounted) {
              setState(() {
                playing = false;
                playingDash = false;
              });
            }
          }
        },
      ),
      const Expanded(
        child: Text(
          'Mo answers aloud',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
  Widget questionCard() => QuestionCard(
    model: model,
    input: input,
    autoVoiceControl: autoVoiceControl(),
    voiceControls: QuestionRecordingControls(
      model: model,
      recording: recording,
      autoStop: autoStop,
      holdingMic: holdingMic,
      stoppingRecording: stoppingRecording,
      playingDash: playingDash,
      recordingSeconds: recordingSeconds,
      beginHold: beginHold,
      endHold: endHold,
      onPlayDash: playDash,
      onOpenWav: () => listen(file: true),
      onAutoStopChanged: (value) => setState(() => autoStop = value),
      onPointerDown: (pointer) {
        if (!model.busy && micPointer == null) {
          micPointer = pointer;
          beginHold();
        }
      },
      onPointerUp: (pointer) {
        if (micPointer == pointer) endHold();
      },
      onPointerCancel: (pointer) {
        if (micPointer == pointer) endHold(cancelled: true);
      },
    ),
    autoSpeak: autoSpeak,
    voiceMode: voiceMode,
    onVoiceModeChanged: (value) => setState(() => voiceMode = value),
    onAsk: ask,
  );

  Widget answerCard() => AnswerCard(
    model: model,
    answerSection: answerSection,
    autoVoiceControl: autoVoiceControl(),
    voiceSettings: voiceSettingsTile(),
    playing: playing,
    onPlay: audio,
  );

  Widget conversation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.reply.isNotEmpty) ...[
        answerCard(),
        const SizedBox(height: 18),
        IllustrationCard(model: model),
        const SizedBox(height: 18),
        ExpansionTile(
          key: ValueKey(model.question),
          title: const Text('Ask another question'),
          subtitle: Text(
            model.question,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [questionCard()],
        ),
      ] else ...[
        questionCard(),
        const SizedBox(height: 18),
        answerCard(),
      ],
      if (model.reply.isNotEmpty && model.error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            model.error!,
            style: const TextStyle(color: berry),
          ),
        ),
    ],
  );
  Widget voiceSettingsTile() => Material(
    color: const Color(0xffedf0e3),
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      key: const Key('voice-settings'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: const Icon(Icons.record_voice_over_outlined),
      title: const Text(
        'Mo’s voice',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(model.voiceLabel, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.tune, size: 20),
      onTap: model.busy ? null : openVoiceSettings,
    ),
  );

  Future<void> openVoiceSettings() => showDialog<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: model,
      builder: (_, _) => VoiceSettingsDialog(
        model: model,
        onSelectVoice: (id) => changeVoice(() => model.selectVoice(id)),
        onSelectLanguage: (language) =>
            changeVoice(() => model.setSpeechLanguage(language)),
        onPreview: previewVoice,
        onRecord: recordVoiceReference,
        onImport: chooseVoice,
      ),
    ),
  );

  Future<void> changeVoice(VoidCallback change) async {
    await player.stop();
    if (!mounted) return;
    change();
    setState(() {
      playing = false;
      playingDash = false;
    });
  }

  Future<void> recordVoiceReference() async {
    if (model.busy) return;
    await player.stop();
    if (!mounted) return;
    setState(() {
      playing = false;
      playingDash = false;
    });
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecorderDialog(),
    );
    if (!mounted || bytes == null) return;
    model.useReference(bytes, 'My recorded voice');
  }
}
