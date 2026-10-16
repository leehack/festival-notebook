import '../festival_ai.dart' as ai;
import 'package:flutter/material.dart';
import '../notebook_controller.dart';
import 'village_style.dart';

class NotebookNotes extends StatelessWidget {
  const NotebookNotes({super.key, required this.model});
  final NotebookController model;
  @override
  Widget build(BuildContext context) => Column(
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
