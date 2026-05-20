import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> displaySnackBarMsg(
    {required BuildContext context,
    String? msg,
    Widget? content,
    SnackBarAction? action,
    bool removeCurrent = true,
    SnackBarBehavior? behavior,
    double? width,
    EdgeInsetsGeometry? margin,
    bool showCloseIcon = true,
    Duration duration = const Duration(seconds: 4)}) {
  if (removeCurrent) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
  return ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: content ?? Text(msg ?? ''),
      action: action,
      behavior: behavior,
      width: width,
      margin: margin,
      showCloseIcon: showCloseIcon,
      duration: duration));
}
