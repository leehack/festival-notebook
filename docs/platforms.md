# Platforms and performance

The source targets macOS, Android, iOS and web. Shared Dart orchestration does not mean every backend has identical capabilities or performance.

| Platform | Example behavior |
| --- | --- |
| macOS | Local text, transcription, speech and image generation |
| Android | Same features; CPU is the safe speech default |
| iOS | Same native APIs; configure your own signing and test device memory |
| Web | Text and speech through the pinned WebGPU bridge; no image generation |

Windows and Linux host projects are not included or qualified by this example. Flutter desktop support alone does not establish native model/runtime compatibility.

## Recorded device evidence

Development testing included macOS on M4 Max, Chrome on macOS, an Android arm64 emulator, physical Pixel 8 Pro / Pixel 11 Pro and iPhone 16 Pro. Those observations used specific model/runtime versions; they are not guarantees for arbitrary devices.

On Pixel 11 Pro, an experimental native Vulkan speech workaround passed five requests with correct ASR transcripts and identical repeated WAVs. Replies still took 53–68 seconds. The workaround is private and is **not included** in this repository. See [llamadart #322](https://github.com/leehack/llamadart/issues/322#issuecomment-6225729793) for exact models, artifact hashes, failed controls and remaining qualification.

The public sample pins published llamadart 0.12.2 and compatible Flutter companion packages. It creates a new speech engine for each request to avoid the known repeated-session problem in that runtime. It does not silently enable experimental Vulkan settings or rely on patched local libraries.

## Running locally

Use `flutter doctor` to check the relevant toolchain. macOS targets macOS 14 or later. For iOS, select your own development team in Xcode; no signing identity is supplied. Android release builds use the local debug signing configuration for developer convenience; configure your own signing before distributing an app.

A fresh native checkout regenerates local Flutter/Gradle files during `flutter pub get` and the first build. Model files are downloaded separately by llamadart.

## Browser hosting

Run `tool/prepare_web.dart` before building the web app. It installs a pinned runtime only after checking the manifest and each SHA-256 digest. Existing matching files are reused. Never commit the runtime or model caches.

Serve the built app with COOP/COEP response headers, on HTTPS or localhost. The development server defaults to localhost port 8765. WebGPU, microphone permissions and memory limits depend on the browser/device. Browser caches can be evicted.

## Measuring responsibly

Separate model download, cached loading, synthesis and playback. A complete-audio timing is not time to first streamed audio. Process RSS is not total GPU memory. A successful transcription of generated speech checks its words, not voice naturalness or speaker similarity.

For phones, start with text, then enable one optional modality at a time. This example releases models between stages rather than keeping several large engines resident.

## GitHub Pages

The public demo is https://leehack.github.io/festival-notebook/. The Pages workflow builds with `/festival-notebook/` as its base path and deploys the static output. Models remain on their upstream hosts and download on demand.

GitHub Pages does not support our custom response headers. The bundled MIT-licensed `coi-serviceworker` (upstream commit `7b1d2a092d0d2dd2b7270b6f12f13605de26f214`) adds isolation through a service worker and may reload the first visit. It is scoped to this app directory and does not cache responses. Flutter offline service-worker generation is disabled to avoid competing workers. Browsers that disable service workers or lack WebGPU cannot run this demo.
