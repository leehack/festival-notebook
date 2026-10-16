import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../notebook_controller.dart';
import 'village_style.dart';

class QuestionRecordingControls extends StatelessWidget {
  const QuestionRecordingControls({
    super.key,
    required this.model,
    required this.recording,
    required this.autoStop,
    required this.holdingMic,
    required this.stoppingRecording,
    required this.playingDash,
    required this.recordingSeconds,
    required this.beginHold,
    required this.onPlayDash,
    required this.onOpenWav,
    required this.endHold,
    required this.onAutoStopChanged,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
  });
  final NotebookController model;
  final bool recording;
  final bool autoStop;
  final bool holdingMic;
  final bool stoppingRecording;
  final bool playingDash;
  final int recordingSeconds;
  final VoidCallback beginHold;
  final VoidCallback onPlayDash;
  final VoidCallback onOpenWav;
  final void Function({bool cancelled}) endHold;
  final ValueChanged<bool> onAutoStopChanged;
  final ValueChanged<int> onPointerDown;
  final ValueChanged<int> onPointerUp;
  final ValueChanged<int> onPointerCancel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
                  onChanged: model.busy ? null : onAutoStopChanged,
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
                    onPointerDown: (event) => onPointerDown(event.pointer),
                    onPointerUp: (event) => onPointerUp(event.pointer),
                    onPointerCancel: (event) => onPointerCancel(event.pointer),
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
            onPressed: model.busy ? null : onPlayDash,
            icon: Icon(playingDash ? Icons.stop : Icons.play_arrow, size: 18),
            label: const Text('Try Dash’s question'),
          ),
          TextButton(
            onPressed: model.busy ? null : onOpenWav,
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
  );
}
