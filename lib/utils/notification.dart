
import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  displaySnackBarMsg({required BuildContext context, required String msg, SnackBarAction? action, bool removeCurrent = true}) {
  if (removeCurrent) {
    ScaffoldMessenger.of(context)
        .removeCurrentSnackBar();
  }
  return ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), action: action));
}

