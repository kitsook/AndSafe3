import 'dart:typed_data';

const currentSignatureVer = 3;
const signatureKeyCheckValueLengthInByte = 3;

class Signature {
  final int? id;
  final String plain;
  final String payload;
  final Uint8List salt;
  final Uint8List iv;
  final int ver;

  Signature(this.id, this.plain, this.payload, this.salt, this.iv, this.ver);

  // map table columns to fields
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'plain': plain,
      'payload': payload,
      'salt': salt,
      'iv': iv,
      'ver': ver,
    };
  }

  static Signature fromMap(Map<String, dynamic> data) {
    return Signature(
      data['_id'],
      data['plain']!,
      data['payload']!,
      data['salt']!,
      data['iv']!,
      data['ver']!,
    );
  }
}
