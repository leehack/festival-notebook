import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import '../tool/prepare_web.dart';
import '../tool/serve_web.dart';

void main() {
  late Directory directory;
  late Map<String, List<int>> assets;
  late List<int> manifest;
  late List<String> calls;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('festival-web-test-');
    assets = {for (final name in runtimeFiles) name: utf8.encode(name)};
    manifest = utf8.encode(
      assets.entries
          .map((entry) => '${sha256.convert(entry.value)}  ${entry.key}')
          .join('\n'),
    );
    calls = [];
  });
  tearDown(() => directory.delete(recursive: true));

  Future<List<int>> download(String name) async {
    calls.add(name);
    return name == 'sha256sums.txt' ? manifest : assets[name]!;
  }

  test('Verified cache skips downloads and corruption is repaired', () async {
    await prepareRuntime(directory, download);
    calls.clear();
    await prepareRuntime(directory, download);
    expect(calls, ['sha256sums.txt']);
    final name = runtimeFiles.first;
    final file = File.fromUri(directory.uri.resolve(name));
    await file.writeAsString('corrupt');
    await prepareRuntime(directory, download);
    expect(await file.readAsBytes(), assets[name]);
  });

  test('Missing manifest entries fail before writing assets', () async {
    manifest = utf8.encode(utf8.decode(manifest).split('\n').first);
    await expectLater(
      prepareRuntime(directory, download),
      throwsFormatException,
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('Bad checksum preserves the existing file', () async {
    final name = (runtimeFiles.toList()..sort()).first;
    final file = File.fromUri(directory.uri.resolve(name));
    await file.writeAsString('previous');
    assets[name] = utf8.encode('bad download');
    await expectLater(
      prepareRuntime(directory, download),
      throwsFormatException,
    );
    expect(await file.readAsString(), 'previous');
    expect(await File('${file.path}.partial').exists(), isFalse);
  });

  test('Server serves HTML and WASM with isolation headers', () async {
    await File.fromUri(
      directory.uri.resolve('index.html'),
    ).writeAsString('<h1>Mo</h1>');
    await File.fromUri(
      directory.uri.resolve('core.wasm'),
    ).writeAsBytes([0, 97, 115, 109]);
    final handler = webHandler(directory);
    for (final path in ['', 'core.wasm', 'missing']) {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/$path')),
      );
      expect(response.headers['cross-origin-opener-policy'], 'same-origin');
      expect(response.headers['cross-origin-embedder-policy'], 'require-corp');
      expect(response.statusCode, path == 'missing' ? 404 : 200);
      if (path == 'core.wasm') {
        expect(response.headers['content-type'], 'application/wasm');
      }
      await response.read().drain<void>();
    }
  });
}
