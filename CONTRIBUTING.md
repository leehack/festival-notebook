# Contributing

Keep the example small and the model calls readable. Put AI orchestration in
`lib/festival_ai.dart`, application state in the controller, and presentation in
the UI. Avoid introducing a backend service for a feature that can run locally.

Run the checks in the README before opening a pull request. Unit/widget CI must
not download models. Real-model tests are opt-in and should state the model,
runtime, device and backend actually used.

Do not commit model weights, generated runtime bundles, raw device logs,
recordings, signing material or local SDK paths. Preserve the current platform
capability limits in the UI and documentation.
