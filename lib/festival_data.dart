typedef NoteHit = ({int index, double score});

/// The small fictional notebook and language choices used by the example.
const languages = <String, String>{
  'en': 'English',
  'ko': '한국어',
  'ja': '日本語',
  'zh': '中文',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'ru': 'Русский',
};
// This example auto-detects Hangul; choose other languages explicitly.
String questionLanguage(String text) =>
    RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ]').hasMatch(text) ? 'ko' : 'en';

const sceneContext =
    'In this fictional Llama Village scene, it is raining now. Dash is asking Mo for help with the Berry Festival. The current time and whether the festival has started are unknown. No forecast or real-world weather is available.';

const notes = [
  (
    id: 'rain',
    title: 'Rain plan',
    text:
        'If it rains, the Berry Festival moves into the village hall. The festival still starts at six in the evening.',
  ),
  (
    id: 'food',
    title: 'Bakery delivery',
    text:
        'Mo brings berry pies from the bakery to the village hall at half past five.',
  ),
  (
    id: 'music',
    title: 'Music rehearsal',
    text:
        'June and Pip rehearse their song beside the outdoor stage in the afternoon.',
  ),
];
