/// Install the pinned browser runtime. Models use llamadart's download manager.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const runtimeBase =
    'https://cdn.jsdelivr.net/gh/leehack/llama-web-bridge-assets@v0.1.59/';
const runtimeFiles = {
  'llama_webgpu_bridge.js',
  'llama_webgpu_bridge_worker.js',
  'llama_webgpu_core.js',
  'llama_webgpu_core.wasm',
};

typedef Download = Future<List<int>> Function(String name);

Future<void> prepareRuntime(Directory destination, Download download) async {
  final manifest = <String, String>{};
  for (final line in const LineSplitter().convert(
    utf8.decode(await download('sha256sums.txt')),
  )) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) continue;
    final name = parts[1].replaceFirst(RegExp(r'^\*'), '');
    if (!runtimeFiles.contains(name)) continue;
    if (manifest.containsKey(name) ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(parts[0])) {
      throw FormatException('Invalid checksum entry: $name');
    }
    manifest[name] = parts[0].toLowerCase();
  }
  if (manifest.length != runtimeFiles.length) {
    throw const FormatException('Runtime manifest is missing required files');
  }
  await destination.create(recursive: true);
  for (final name in manifest.keys.toList()..sort()) {
    final target = File.fromUri(destination.uri.resolve(name));
    final digest = manifest[name]!;
    if (await target.exists() &&
        (await sha256.bind(target.openRead()).first).toString() == digest) {
      stdout.writeln('Cached: $name');
      continue;
    }
    final data = await download(name);
    if (sha256.convert(data).toString() != digest) {
      throw FormatException('Checksum mismatch: $name');
    }
    final temporary = File('${target.path}.partial');
    try {
      await temporary.writeAsBytes(data, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    stdout.writeln('Installed: $name');
  }
}

Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 120);
  try {
    await prepareRuntime(
      Directory.fromUri(Platform.script.resolve('../web/runtime/')),
      (name) async {
        final request = await client.getUrl(Uri.parse('$runtimeBase$name'));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('HTTP ${response.statusCode}: $name');
        }
        return response.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        );
      },
    ).timeout(const Duration(minutes: 10));
  } finally {
    client.close(force: true);
  }
}
