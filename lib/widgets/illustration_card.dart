import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../notebook_controller.dart';
import 'village_style.dart';

class IllustrationCard extends StatelessWidget {
  const IllustrationCard({super.key, required this.model});
  final NotebookController model;
  @override
  Widget build(BuildContext context) => card(
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
                  model.setDetailedImages(value);
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
}
