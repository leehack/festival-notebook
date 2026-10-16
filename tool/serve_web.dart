/// Serve a release web build with the isolation headers required by WASM.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

Handler webHandler(Directory directory) {
  final serve = createStaticHandler(
    directory.path,
    defaultDocument: 'index.html',
  );
  return (request) async => (await serve(request)).change(
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  );
}

Future<void> main(List<String> args) async {
  final port = args.isEmpty
      ? 8765
      : args.length == 2 && args.first == '--port'
      ? int.tryParse(args.last)
      : null;
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('Usage: dart run tool/serve_web.dart [--port 8765]');
    exitCode = 64;
    return;
  }
  final directory = Directory.fromUri(Platform.script.resolve('../build/web/'));
  if (!File.fromUri(directory.uri.resolve('index.html')).existsSync()) {
    stderr.writeln('Run flutter build web --release first');
    exitCode = 1;
    return;
  }
  final server = await shelf_io.serve(webHandler(directory), '127.0.0.1', port);
  stdout.writeln('Festival Notebook: http://127.0.0.1:${server.port}');
  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
}
