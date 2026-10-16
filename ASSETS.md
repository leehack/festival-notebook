# Asset credits

- `assets/festival-cover.png`: AI-generated illustration created for the Llama Village article/example. It is artwork, not a game screenshot.
- `assets/question.wav`: synthetic Dash question generated locally with Qwen3-TTS 0.6B.
- `assets/mo-original.wav` and `assets/mo-alternate.wav`: synthetic voice references generated with the pinned Qwen3-TTS model, not recordings of real people.
- Platform launcher icons: Flutter template assets. Flutter and Dash are associated with the Flutter project; this community example is not an official Flutter product.

The original illustration and synthetic audio are included under the repository’s MIT license. Template and third-party assets retain their upstream terms. User recordings and generated model outputs are not committed to this repository.

Model identifiers and immutable revisions are in `lib/festival_ai.dart`. Each model is downloaded from its provider on demand; consult that provider’s model card and license. A code license does not change a model’s license.

`docs/screenshot.png` is an actual macOS integration-test capture from this example, showing a model-generated reply.
