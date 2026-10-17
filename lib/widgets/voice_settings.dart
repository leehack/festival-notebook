import '../festival_data.dart' as data;
import 'package:flutter/material.dart';
import '../notebook_controller.dart';
import 'village_style.dart';

class VoiceSettingsDialog extends StatelessWidget {
  const VoiceSettingsDialog({
    super.key,
    required this.model,
    required this.onSelectVoice,
    required this.onSelectLanguage,
    required this.onPreview,
    required this.onRecord,
    required this.onImport,
  });
  final NotebookController model;
  final ValueChanged<String> onSelectVoice;
  final ValueChanged<String> onSelectLanguage;
  final VoidCallback onPreview;
  final VoidCallback onRecord;
  final VoidCallback onImport;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Give Mo a voice'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('voice-${model.voiceId}-${model.referenceName}'),
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
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                if (model.speakerReference != null)
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text(model.referenceName ?? 'Your WAV'),
                  ),
              ],
              onChanged: model.busy
                  ? null
                  : (id) {
                      if (id != null && id != "custom") onSelectVoice(id);
                    },
            ),
            TextButton.icon(
              onPressed: model.busy ? null : onPreview,
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
                for (final language in data.languages.entries)
                  DropdownMenuItem(
                    value: language.key,
                    child: Text(language.value),
                  ),
              ],
              onChanged: model.busy
                  ? null
                  : (value) {
                      if (value != null) onSelectLanguage(value);
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
                  onPressed: model.busy ? null : onRecord,
                  icon: const Icon(Icons.mic_none),
                  label: const Text('Record my voice'),
                ),
                OutlinedButton.icon(
                  onPressed: model.busy ? null : onImport,
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
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
