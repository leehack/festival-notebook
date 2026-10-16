import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

// Keep a WAV extension for native media decoders; overwrite one temporary file.
Future<Source> audioSource(Uint8List bytes) async {
  final directory = await getTemporaryDirectory();
  await directory.create(recursive: true);
  final file = File('${directory.path}/festival-reply.wav');
  await file.writeAsBytes(bytes, flush: true);
  return DeviceFileSource(file.path, mimeType: 'audio/wav');
}
