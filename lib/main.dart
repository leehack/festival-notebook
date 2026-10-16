import 'dart:async';

import 'package:flutter/services.dart';

import 'microphone.dart';
import 'voice_recorder.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';

import 'festival_ai.dart' as ai;
import 'notebook_controller.dart';
import 'audio_source.dart';

const ink = Color(0xff23433a);
const paper = Color(0xfff5efe2);
const berry = Color(0xffa84d50);
const muted = Color(0xff68796d);
final captureKey = GlobalKey();
void main() => runApp(const FestivalApp());

class FestivalApp extends StatelessWidget {
  const FestivalApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Llama Village · Festival notebook',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        surface: const Color(0xfffffcf5),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffd8dccc)),
        ),
      ),
    ),
    home: const NotebookScreen(),
  );
}

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});
  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen>
    with WidgetsBindingObserver {
  final model = NotebookController();
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
    model.busy = true;
    model.error = null;
    model.status = 'Dash is asking Mo';
    model.update();
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
      model.busy = false;
      final text = await model.listen(bytes: bytes);
      if (!mounted || text == null || text.trim().isEmpty) return;
      input.text = text;
      await ask();
    } catch (e) {
      if (mounted) model.error = 'Could not complete Dash’s question: $e';
    } finally {
      await completion?.cancel();
      if (mounted) {
        model.busy = false;
        model.status = '';
        setState(() => playingDash = false);
        model.update();
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
        model.busy = false;
        if (!mounted) return;
        setState(() => recording = false);
        if (!submit) return;
        final text = await model.listen(bytes: bytes);
        if (mounted && text != null) {
          input.text = text;
          if (text.trim().isNotEmpty) await ask();
        }
      } catch (e) {
        model.error = '$e';
      } finally {
        model.busy = false;
        model.status = '';
        stoppingRecording = false;
        holdingMic = false;
        if (mounted) setState(() => recording = false);
        model.update();
      }
      return;
    }
    model.busy = true;
    model.error = null;
    model.status = 'Preparing the microphone';
    model.update();
    try {
      await player.stop();
      await microphone.start(
        onSilence: autoStop
            ? (hasSpeech) {
                if (!mounted || !recording || stoppingRecording) return;
                if (!hasSpeech) {
                  model.error =
                      'No speech detected. Try again or switch to hold-to-talk in a noisy room.';
                  model.update();
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
        model.busy = false;
        model.status = '';
        model.update();
        return;
      }
      setState(() {
        recordingSeconds = 0;
        recording = true;
        playing = false;
        playingDash = false;
      });
      model.status = autoStop
          ? 'Listening · a pause sends your question'
          : 'Recording · release to send';
      model.update();
      recordingLimit = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => recordingSeconds++);
        if (recordingSeconds >= 20) endHold();
      });
    } catch (e) {
      model.busy = false;
      model.status = '';
      model.error = '$e';
      model.update();
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
      model.error = 'Could not preview this voice: $e';
      model.update();
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
      model.speakerReference = bytes;
      model.referenceName = file.name;
      model.audioBytes = null;
      model.update();
      setState(() {
        playing = false;
        playingDash = false;
      });
    } catch (e) {
      model.error = 'Could not use reference voice: $e';
      model.update();
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
        model.error = 'Playback failed: $e';
        model.update();
      }
    }
  }

  Widget label(String s) => Text(
    s,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: muted,
    ),
  );
  Widget heading(String s, {double size = 28}) => Text(
    s,
    style: TextStyle(
      fontFamily: 'Georgia',
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
  );
  Widget card(Widget child) => Material(
    color: const Color(0xfffffcf5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xffe1dccd)),
    ),
    child: Padding(padding: const EdgeInsets.all(26), child: child),
  );
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
                                Expanded(flex: 4, child: notebook()),
                              ],
                            )
                          else ...[
                            conversation(),
                            const SizedBox(height: 20),
                            notebook(),
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
  Widget conversation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.reply.isNotEmpty) ...[
        answerCard(),
        const SizedBox(height: 18),
        illustrationCard(),
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
  Widget questionCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = heading('What should we do, Mo?', size: 26);
            final badge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffe6ecdf),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Village baker',
                style: TextStyle(color: ink, fontSize: 11),
              ),
            );
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 8), badge],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                badge,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Ask about the rain plan, the pies, or tonight’s music.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        autoVoiceControl(),
        if (autoSpeak && !model.speechUsed)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Voice generates after the text · First download: 762 MB',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Type a question'),
              icon: Icon(Icons.edit_outlined, size: 18),
            ),
            ButtonSegment(
              value: true,
              label: Text('Speak as Dash'),
              icon: Icon(Icons.mic_none, size: 18),
            ),
          ],
          selected: {voiceMode},
          showSelectedIcon: false,
          onSelectionChanged: model.busy
              ? null
              : (values) => setState(() => voiceMode = values.single),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 18),
        if (voiceMode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffedf0e3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording
                      ? 'Listening · ${recordingSeconds}s / 20s'
                      : 'Your voice, Dash’s question',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your question goes to Mo automatically after transcription. You can edit the transcript afterward.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: autoStop,
                      onChanged: model.busy
                          ? null
                          : (value) => setState(() => autoStop = value),
                    ),
                    const Expanded(
                      child: Text(
                        'Stop when I finish speaking',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (autoStop)
                  FilledButton.icon(
                    key: const Key('record-question'),
                    onPressed: stoppingRecording || (model.busy && !recording)
                        ? null
                        : () {
                            if (recording) {
                              endHold();
                            } else {
                              beginHold();
                            }
                          },
                    icon: Icon(recording ? Icons.stop : Icons.mic_none),
                    label: Text(recording ? 'Send now' : 'Start speaking'),
                  )
                else
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event.logicalKey != LogicalKeyboardKey.space &&
                          event.logicalKey != LogicalKeyboardKey.enter) {
                        return KeyEventResult.ignored;
                      }
                      if (event is KeyDownEvent) beginHold();
                      if (event is KeyUpEvent) endHold();
                      return KeyEventResult.handled;
                    },
                    onFocusChange: (focused) {
                      if (!focused && holdingMic) endHold(cancelled: true);
                    },
                    child: Semantics(
                      button: true,
                      label: recording
                          ? 'Stop recording and send to Mo'
                          : 'Hold to talk. Keyboard: hold Space. Accessibility: activate to start, activate again to send.',
                      onTap: () {
                        if (recording) {
                          endHold();
                        } else {
                          beginHold();
                        }
                      },
                      child: Listener(
                        key: const Key('record-question'),
                        onPointerDown: (event) {
                          if (!model.busy && micPointer == null) {
                            micPointer = event.pointer;
                            beginHold();
                          }
                        },
                        onPointerUp: (event) {
                          if (micPointer == event.pointer) endHold();
                        },
                        onPointerCancel: (event) {
                          if (micPointer == event.pointer) {
                            endHold(cancelled: true);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: recording ? berry : ink,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                recording ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  recording
                                      ? 'Recording ${recordingSeconds}s · Release to send'
                                      : 'Hold to talk',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'Auto-stop after a 1.2-second pause · 20-second limit · Voice download: 1.02 GB',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: const Key('play-dash'),
                onPressed: model.busy ? null : playDash,
                icon: Icon(
                  playingDash ? Icons.stop : Icons.play_arrow,
                  size: 18,
                ),
                label: const Text('Try Dash’s question'),
              ),
              TextButton(
                onPressed: model.busy ? null : () => listen(file: true),
                child: const Text('Open WAV'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Play Dash’s sample, transcribe it, and ask Mo automatically. Uses local speech and text models.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
        TextField(
          key: const Key('question'),
          controller: input,
          enabled: !model.busy,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Ask about the festival…',
            labelText: 'Question for Mo',
          ),
          onSubmitted: (_) => ask(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: model.languageOverride ?? 'auto',
          decoration: const InputDecoration(
            labelText: 'Answer language',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
              value: 'auto',
              child: Text('Auto · Korean / English'),
            ),
            for (final language in ai.languages.entries)
              DropdownMenuItem(
                value: language.key,
                child: Text(language.value),
              ),
          ],
          onChanged: model.busy
              ? null
              : (value) {
                  model.languageOverride = value == 'auto' ? null : value;
                  model.update();
                },
        ),
        const SizedBox(height: 12),
        if (!voiceMode)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in [
                'Where do we go if it rains?',
                'When do the pies arrive?',
                'Who won last year?',
              ])
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 11)),
                  onPressed: model.busy
                      ? null
                      : () {
                          input.text = q;
                        },
                ),
            ],
          ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('ask'),
              onPressed: model.busy ? null : ask,
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: Text(
                model.reply.isEmpty
                    ? 'Help Dash plan the festival'
                    : 'Ask Mo again',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          model.textUsed
              ? 'Text models used this session · Runs locally'
              : 'First use downloads about 0.9 GB. After that, ask offline.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        if (model.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xffffebe5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: berry, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    model.error!,
                    style: const TextStyle(
                      color: berry,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss message',
                  onPressed: () {
                    model.error = null;
                    model.update();
                  },
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
  Widget answerCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(key: answerSection),
        label(model.reply.isEmpty ? 'MO IS READY TO HELP' : 'A WORD FROM MO'),
        if (model.reply.isNotEmpty) autoVoiceControl(),
        const SizedBox(height: 14),
        if (model.reply.isEmpty) ...[
          heading('First, ask Mo about the rain.', size: 24),
          const SizedBox(height: 12),
          const Text(
            'His answer and the notes he used will appear here.',
            style: TextStyle(color: muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          voiceSettingsTile(),
        ] else ...[
          SelectableText(
            model.reply,
            key: const Key('answer'),
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 23,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('speak'),
                onPressed: model.busy ? null : () => model.speak(),
                icon: const Icon(Icons.record_voice_over, size: 18),
                label: Text(
                  model.audioBytes == null
                      ? 'Generate Mo’s voice'
                      : 'Generate again',
                ),
              ),
              if (model.audioBytes != null)
                FilledButton.tonalIcon(
                  key: const Key('play'),
                  onPressed: model.busy ? null : audio,
                  icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                  label: Text(playing ? 'Stop' : 'Hear Mo’s answer'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            model.speechUsed
                ? 'Speech model used this session · Audio stays on this device'
                : 'Optional voice · First download: 762 MB',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          voiceSettingsTile(),
        ],
      ],
    ),
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

  Future<void> openVoiceSettings() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: model,
        builder: (_, _) => AlertDialog(
          title: const Text('Give Mo a voice'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'voice-${model.voiceId}-${model.referenceName}',
                    ),
                    initialValue: model.speakerReference == null
                        ? model.voiceId
                        : 'custom',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Voice',
                      isDense: true,
                    ),
                    items: [
                      for (final entry in NotebookController.voices.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      if (model.speakerReference != null)
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text(model.referenceName ?? 'Your WAV'),
                        ),
                    ],
                    onChanged: model.busy
                        ? null
                        : (id) async {
                            if (id == null || id == 'custom') return;
                            await player.stop();
                            if (!mounted) return;
                            model.selectVoice(id);
                            setState(() {
                              playing = false;
                              playingDash = false;
                            });
                          },
                  ),
                  TextButton.icon(
                    onPressed: model.busy ? null : previewVoice,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview selected voice'),
                  ),
                  const Text(
                    'The same reference guides every reply. Delivery can still vary with the words and language.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: model.replyLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Speech language',
                      isDense: true,
                    ),
                    items: [
                      for (final language in ai.languages.entries)
                        DropdownMenuItem(
                          value: language.key,
                          child: Text(language.value),
                        ),
                    ],
                    onChanged: model.busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            await player.stop();
                            model.replyLanguage = value;
                            model.audioBytes = null;
                            model.update();
                            if (mounted) {
                              setState(() {
                                playing = false;
                                playingDash = false;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Make it your own: record a short sample, or import a clean WAV.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const Key('open-voice-recorder'),
                        onPressed: model.busy ? null : recordVoiceReference,
                        icon: const Icon(Icons.mic_none),
                        label: const Text('Record my voice'),
                      ),
                      OutlinedButton.icon(
                        onPressed: model.busy ? null : chooseVoice,
                        icon: const Icon(Icons.audio_file_outlined, size: 18),
                        label: const Text('Import WAV'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
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
    model.speakerReference = bytes;
    model.referenceName = 'My recorded voice';
    model.audioBytes = null;
    model.update();
  }

  Widget illustrationCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('3 · PICTURE THE PLAN'),
        const SizedBox(height: 10),
        heading('Mo’s illustration', size: 24),
        const SizedBox(height: 10),
        const Text(
          'An AI illustration of your conversation, not a gameplay capture. The small image model may miss character details.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 14),
        if (model.imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              model.imageBytes!,
              key: const Key('illustration'),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (model.imagePrompt != null)
          ExpansionTile(
            title: const Text(
              'Scene sent to the image model',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  model.imagePrompt!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('More scene detail'),
          subtitle: Text(
            model.detailedImages
                ? 'SD-Turbo · 4 steps · about 2.03 GB download'
                : 'SDXS · 1 step · about 683 MB download',
          ),
          value: model.detailedImages,
          onChanged: model.busy || kIsWeb
              ? null
              : (value) {
                  model.detailedImages = value;
                  model.update();
                },
        ),
        OutlinedButton.icon(
          key: const Key('illustrate'),
          onPressed: model.busy || kIsWeb ? null : () => model.illustrate(),
          icon: const Icon(Icons.auto_awesome_outlined, size: 17),
          label: Text(
            model.imageBytes == null
                ? 'Draw this conversation'
                : 'Draw another version',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? 'Image generation is available in the native app. The notebook still works here.'
              : model.imageUsed
              ? 'Last image: ${model.lastImageDetailed == true ? 'SD-Turbo' : 'SDXS'} · Generated locally'
              : 'Choose a model above, then draw locally',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget notebook() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.umbrella_outlined, size: 18, color: muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Story context: it is raining now.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 18),
              child: Text(
                'This is the village scenario, not live weather. Mo receives this context with the notes.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
            label(
              model.hits.isEmpty ? 'MO’S FESTIVAL NOTEBOOK' : 'NOTES MO FOUND',
            ),
            const SizedBox(height: 10),
            heading(
              model.hits.isEmpty
                  ? 'Where Mo looks for answers'
                  : 'Check the source',
              size: 24,
            ),
            const SizedBox(height: 14),
            Text(
              model.hits.isEmpty
                  ? 'Mo searches these three notes when you ask a question.'
                  : 'These are the closest matching notes, shown exactly as written.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final i
                in (model.hits.isEmpty
                    ? [0, 1, 2]
                    : model.hits.take(2).map((h) => h.index)))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? const Color(0xffedf0e3)
                        : const Color(0xfff4eee2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            i == 0
                                ? Icons.umbrella_outlined
                                : i == 1
                                ? Icons.bakery_dining_outlined
                                : Icons.music_note,
                            size: 17,
                            color: muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ai.notes[i].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ai.notes[i].text,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            const Text(
              'If the notes don’t say, Mo should say he doesn’t know.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
      ...[
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text(
            'How this works with llamadart',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            for (final step in [
              (
                'Find the rain plan',
                'EmbeddingEngine compares Dash’s question with the three notes.\nfestival_ai.dart → retrieve()',
              ),
              (
                'Write Mo’s answer',
                'LlamaEngine answers using the selected notes.\nfestival_ai.dart → answer()',
              ),
              (
                'Optional voice input',
                'SpeechToTextEngine turns a WAV recording into editable text.\nfestival_ai.dart → transcribe()',
              ),
              (
                'Optional spoken answer',
                'TextToSpeechEngine makes a WAV you can replay.\nfestival_ai.dart → speak()',
              ),
              (
                'Optional illustration',
                'LlamaEngine describes the exchange; ImageGenerationEngine draws that prompt on native platforms.\nfestival_ai.dart → illustrate()',
              ),
            ])
              ListTile(
                title: Text(step.$1, style: const TextStyle(fontSize: 13)),
                subtitle: Text(step.$2, style: const TextStyle(fontSize: 12)),
              ),
            for (final e in model.times.entries)
              ListTile(
                dense: true,
                title: Text(e.key, style: const TextStyle(fontSize: 11)),
                trailing: Text('${(e.value / 1000).toStringAsFixed(2)} s'),
              ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Includes model loading and disposal. First runs may include downloads.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
