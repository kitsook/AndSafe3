import 'dart:typed_data';

import 'package:convert/convert.dart';

String bytesToHexString(Uint8List bytes) {
  return hex.encode(bytes).toUpperCase();
}

Uint8List hexStringToBytes(String str) {
  return Uint8List.fromList(hex.decode(str));
}
