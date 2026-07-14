import 'package:flutter/material.dart';

enum NoteCategories {
  general,
  contacts,
  keys,
  favorites,
  lock,
  internet,
  money,
  events,
  preferences,
  files,
}

List<Widget> _categoryIcons = [
  CircleAvatar(
    backgroundColor: Color(0xff6e2366),
    child: Icon(Icons.edit_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xff0b85a1),
    child: Icon(Icons.phone_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xffff9060),
    child: Icon(Icons.vpn_key_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xff9c282c),
    child: Icon(Icons.favorite_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xff938042),
    child: Icon(Icons.lock_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xff6655ff),
    child: Icon(Icons.computer_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xff82d156),
    child: Icon(Icons.attach_money_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xffd15682),
    child: Icon(Icons.calendar_today_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xffd9dabe),
    child: Icon(Icons.settings_rounded),
  ),
  CircleAvatar(
    backgroundColor: Color(0xffdfdf03),
    child: Icon(Icons.folder_rounded),
  ),
];

Widget getIconByCategory(int categoryId) {
  if (categoryId >= 0 && categoryId < _categoryIcons.length) {
    return _categoryIcons[categoryId];
  }
  return _categoryIcons[0];
}
