import 'package:flutter/material.dart';

enum noteCategories {
  CATEGORY_ICON_GENERAL,
  CATEGORY_ICON_CONTACTS,
  CATEGORY_ICON_KEYS,
  CATEGORY_ICON_FAVORITES,
  CATEGORY_ICON_LOCK,
  CATEGORY_ICON_INTERNET,
  CATEGORY_ICON_MONEY,
  CATEGORY_ICON_EVENTS,
  CATEGORY_ICON_PREFERENCES,
  CATEGORY_ICON_FILES,
}

List<Widget> _categoryIcons = [
  CircleAvatar(
    child: Icon(Icons.edit_rounded),
    backgroundColor: Color(0xff6e2366),
  ),
  CircleAvatar(
    child: Icon(Icons.phone_rounded),
    backgroundColor: Color(0xff0b85a1),
  ),
  CircleAvatar(
    child: Icon(Icons.vpn_key_rounded),
    backgroundColor: Color(0xffff9060),
  ),
  CircleAvatar(
    child: Icon(Icons.favorite_rounded),
    backgroundColor: Color(0xff9c282c),
  ),
  CircleAvatar(
    child: Icon(Icons.lock_rounded),
    backgroundColor: Color(0xff938042),
  ),
  CircleAvatar(
    child: Icon(Icons.computer_rounded),
    backgroundColor: Color(0xff6655ff),
  ),
  CircleAvatar(
    child: Icon(Icons.attach_money_rounded),
    backgroundColor: Color(0xff82d156),
  ),
  CircleAvatar(
    child: Icon(Icons.calendar_today_rounded),
    backgroundColor: Color(0xffd15682),
  ),
  CircleAvatar(
    child: Icon(Icons.settings_rounded),
    backgroundColor: Color(0xffd9dabe),
  ),
  CircleAvatar(
    child: Icon(Icons.folder_rounded),
    backgroundColor: Color(0xffdfdf03),
  ),
];

Widget getIconByCategory(int categoryId) {
  if (categoryId >= 0 && categoryId < _categoryIcons.length) {
    return _categoryIcons[categoryId];
  }
  return _categoryIcons[0];
}