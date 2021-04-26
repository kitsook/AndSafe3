import 'package:andsafe/pages/change_password.dart';
import 'package:andsafe/pages/home.dart';
import 'package:andsafe/pages/import.dart';
import 'package:andsafe/pages/note_edit.dart';
import 'package:andsafe/pages/settings.dart';
import 'package:andsafe/pages/signature_setup.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

Handler signatureSetupHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) =>
        SignatureSetupPage());

Handler homeHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) =>
        HomePage());

Handler editNoteHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) =>
        NoteEditPage(params['id'][0]));

Handler changeSettingsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) =>
        ChangeSettingsPage());

Handler changePasswordHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) =>
        ChangePasswordPage());

Handler importHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) =>
        ImportPage(params['password'][0]));
