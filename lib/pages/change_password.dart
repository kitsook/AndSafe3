import 'dart:async';

import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:sqflite/sqflite.dart';

class ChangePasswordPage extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return _ChangePasswordPageState();
  }
}

class _ChangePasswordPageState extends State {
  final _formKey = GlobalKey<FormState>();
  final _origPasswordController = TextEditingController();
  final _newPassword1Controller = TextEditingController();
  final _newPassword2Controller = TextEditingController();
  bool _isBusy = false;

  StreamController<int> _progressStreamController = StreamController<int>();
  late Stream<int> _progressStream = _progressStreamController.stream.asBroadcastStream();

  int _totalToReEncrypt = 0;
  int _currentlyReEncrypting = 0;

  @override
  void dispose() {
    _origPasswordController.dispose();
    _newPassword1Controller.dispose();
    _newPassword2Controller.dispose();
    _progressStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.changePasswordTitle),
        ),
        body: LoadingOverlay(
            isLoading: this._isBusy,
            progressIndicator: _buildProgressIndicator(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerticalSpacing(),
                      _buildOrigPasswordField(),
                      _buildVerticalSpacing(),
                      _buildNewPassword1Field(),
                      _buildVerticalSpacing(),
                      _buildNewPassword2Field(),
                      _buildVerticalSpacing(),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            )));
  }

  Widget _buildVerticalSpacing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
    );
  }

  Widget _buildOrigPasswordField() {
    return TextFormField(
      autofocus: false,
      controller: _origPasswordController,
      decoration: new InputDecoration(
          contentPadding:
          EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.currentPassword),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.currentPasswordCannotBeEmpty;
        }
        return null;
      },
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
    );
  }

  Widget _buildNewPassword1Field() {
    return TextFormField(
      autofocus: false,
      controller: _newPassword1Controller,
      decoration: new InputDecoration(
          contentPadding:
          EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.newPassword),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.newPasswordCannotBeEmpty;
        }
        return null;
      },
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
    );
  }

  Widget _buildNewPassword2Field() {
    return TextFormField(
      autofocus: false,
      controller: _newPassword2Controller,
      decoration: new InputDecoration(
          contentPadding:
          EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.newPassword2),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty || value != _newPassword1Controller.text) {
          return AppLocalizations.of(context)!.newPasswordsDoNotMatch;
        }
        return null;
      },
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(10.0),
      child: ElevatedButton(
        onPressed: () async {
          // validate form fields
          if (_formKey.currentState!.validate()) {
            setState(() {
              this._isBusy = true;
            });
            try {
              String currentPassword = _origPasswordController.text;
              String newPassword = _newPassword1Controller.text;

              Signature signature = await db.adapter.getSignature();
              final signatureCheck = await verifySignature(signature, currentPassword);
              if (signatureCheck) {
                List<Note> allNotes = await db.adapter.getNotes();
                this._totalToReEncrypt = allNotes.length;
                this._currentlyReEncrypting = 0;

                Signature newSignature = await createSignature(newPassword);

                // get database transaction to update everything
                Database database = await db.adapter.getDb();
                await database.transaction((txn) async {
                  await db.adapter.generateSignature(newSignature, txn);
                  for (var note in allNotes) {
                    _progressStreamController.add(++this._currentlyReEncrypting);
                    Note newNote = await createNote(
                      note.id,
                      note.categoryId,
                      note.title,
                      await getNotePlainBody(note, currentPassword),
                      newPassword,
                      note.lastUpdate);
                    await db.adapter.updateNote(newNote, txn);
                  }
                });

                Navigator.pop(context, true);
              } else {
                // current password verification failed
                displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToChangePassword);
              }
            } catch (e) {
              log.fine("Failed to change password");
              log.fine(e.toString());
              displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToChangePassword);
            } finally {
              setState(() {
                this._isBusy = false;
              });
            }
          }
        },
        child: Text(AppLocalizations.of(context)!.changePasswordButton),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      child: StreamBuilder(
          stream: _progressStream,
          initialData: 0,
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
            List<Widget> children;
            if (snapshot.hasError) {
              children = <Widget>[
                CircularProgressIndicator(),
              ];
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              children = <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text(AppLocalizations.of(context)!.verifying),
              ];
            } else if (snapshot.connectionState == ConnectionState.active &&
                _totalToReEncrypt > 0) {
              children = <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text(AppLocalizations.of(context)!.reEncrypting + ' (${snapshot.data} / $_totalToReEncrypt)'),
              ];
            } else {
              children = <Widget>[
                CircularProgressIndicator(),
              ];
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            );
          }
      ),
    );
  }
}