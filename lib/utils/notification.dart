import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> displaySnackBarMsg(
    {required BuildContext context,
    String? msg,
    Widget? content,
    SnackBarAction? action,
    bool removeCurrent = true,
    Duration duration = const Duration(seconds: 4)}) {
  if (removeCurrent) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
  }
  return ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: content ?? Text(msg ?? ''),
      action: action,
      persist: false,
      showCloseIcon: true,
      duration: duration));
}
