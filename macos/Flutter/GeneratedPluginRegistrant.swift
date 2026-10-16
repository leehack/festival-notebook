//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audioplayers_darwin
import file_selector_macos
import llamadart_llama_cpp_flutter
import llamadart_stable_diffusion_flutter
import record_macos

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  LlamadartLlamaCppPlugin.register(with: registry.registrar(forPlugin: "LlamadartLlamaCppPlugin"))
  LlamadartStableDiffusionPlugin.register(with: registry.registrar(forPlugin: "LlamadartStableDiffusionPlugin"))
  RecordMacOsPlugin.register(with: registry.registrar(forPlugin: "RecordMacOsPlugin"))
}
