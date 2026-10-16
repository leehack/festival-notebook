import 'package:flutter/material.dart';
import '../notebook_controller.dart';
import 'village_style.dart';

class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.model,
    required this.answerSection,
    required this.autoVoiceControl,
    required this.voiceSettings,
    required this.playing,
    required this.onPlay,
  });
  final NotebookController model;
  final GlobalKey answerSection;
  final Widget autoVoiceControl;
  final Widget voiceSettings;
  final bool playing;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(key: answerSection),
        label(model.reply.isEmpty ? 'MO IS READY TO HELP' : 'A WORD FROM MO'),
        if (model.reply.isNotEmpty) autoVoiceControl,
        const SizedBox(height: 14),
        if (model.reply.isEmpty) ...[
          heading('First, ask Mo about the rain.', size: 24),
          const SizedBox(height: 12),
          const Text(
            'His answer and the notes he used will appear here.',
            style: TextStyle(color: muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          voiceSettings,
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
                  onPressed: model.busy ? null : onPlay,
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
          voiceSettings,
        ],
      ],
    ),
  );
}
