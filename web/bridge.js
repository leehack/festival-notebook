// Keep the browser runtime pinned alongside pubspec.lock.
const base = new URL('./runtime/', window.location.href).href;
window.__llamadartBridgeReadyPromise = (async () => {
  try {
    const mod = await import(base + 'llama_webgpu_bridge.js');
    window.LlamaWebGpuBridge = mod.LlamaWebGpuBridge;
    window.__llamadartBridgeModuleUrl = base + 'llama_webgpu_bridge.js';
    window.__llamadartBridgeCoreModuleUrl = base + 'llama_webgpu_core.js';
    window.__llamadartBridgeWasmUrl = base + 'llama_webgpu_core.wasm';
    // The pinned official runtime includes typed Qwen3-ASR support.
    window.__llamadartBridgeSpeechToTextSupported = true;
    window.__llamadartBridgeReady = true;
  } catch (error) {
    window.__llamadartBridgeLoadError = String(error);
    throw error;
  }
})();
window.__llamadartBridgeReadyPromise.catch(() => {});
