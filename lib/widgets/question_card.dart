import '../festival_ai.dart' as ai;
import 'package:flutter/material.dart';
import '../notebook_controller.dart';
import 'village_style.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.model,
    required this.input,
    required this.autoVoiceControl,
    required this.voiceControls,
    required this.autoSpeak,
    required this.voiceMode,
    required this.onVoiceModeChanged,
    required this.onAsk,
  });
  final NotebookController model;
  final TextEditingController input;
  final Widget autoVoiceControl;
  final Widget voiceControls;
  final bool autoSpeak;
  final bool voiceMode;
  final ValueChanged<bool> onVoiceModeChanged;
  final VoidCallback onAsk;
  @override
  Widget build(BuildContext context) => card(
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
        autoVoiceControl,
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
              : (values) => onVoiceModeChanged(values.single),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 18),
        if (voiceMode) voiceControls,
        TextField(
          key: const Key('question'),
          controller: input,
          enabled: !model.busy,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Ask about the festival…',
            labelText: 'Question for Mo',
          ),
          onSubmitted: (_) => onAsk(),
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
                  model.setAnswerLanguage(value == 'auto' ? null : value);
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
              onPressed: model.busy ? null : onAsk,
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
                    model.reportError(null);
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
}
