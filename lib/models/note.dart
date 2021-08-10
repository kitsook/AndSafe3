import 'dart:typed_data';

class Note {
  int? id;
  final int categoryId;
  final String title;
  final String body;
  final Uint8List salt;
  final Uint8List iv;
  final DateTime lastUpdate;

  Note(this.id, this.categoryId, this.title, this.body, this.salt, this.iv,
      this.lastUpdate);

  // map table columns to fields
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'cat_id': categoryId,
      'title': title,
      'body': body,
      'salt': salt,
      'iv': iv,
      'last_update': (lastUpdate.millisecondsSinceEpoch / 1000).round(),
    };
  }

  static Note fromMap(Map<String, dynamic> data) {
    return Note(
      data['_id'] /*?*/,
      data['cat_id']!,
      data['title']!,
      data['body']!,
      data['salt']!,
      data['iv']!,
      DateTime.fromMillisecondsSinceEpoch((data['last_update'] * 1000).round()),
    );
  }
}
