import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

Future<Source> audioSource(Uint8List bytes) async =>
    BytesSource(bytes, mimeType: 'audio/wav');
