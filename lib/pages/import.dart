import 'dart:async';

import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:andsafe/utils/services/export_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:loading_overlay/loading_overlay.dart';

class ImportPage extends StatefulWidget {
  final String _password;

  ImportPage(this._password);

  @override
  State<StatefulWidget> createState() {
    return _ImportPageState(this._password);
  }
}

class _ImportPageState extends State {
  final _password;
  String? _importFullPath;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _fileNameController = TextEditingController();
  bool _isBusy = false;

  StreamController<int> _importProgressStreamController = StreamController<int>();
  late Stream<int> _importProgressStream = _importProgressStreamController.stream.asBroadcastStream();

  int _totalToImport = 0;
  int _currentlyImporting = 0;

  _ImportPageState(this._password);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _importProgressStreamController.close();
    _passwordController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.importNotesTitle),
        ),
        body: LoadingOverlay(
            isLoading: this._isBusy,
            progressIndicator: _buildImportProgressIndicator(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerticalSpacing(),
                      _buildFileChooserField(),
                      _buildVerticalSpacing(),
                      _buildPasswordField(),
                      _buildVerticalSpacing(),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            )));
  }

  Widget _buildImportProgressIndicator() {
    return Container(
      child: StreamBuilder(
        stream: _importProgressStream,
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
              _totalToImport > 0) {
            children = <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text(AppLocalizations.of(context)!.importing + ' (${snapshot.data} / $_totalToImport)'),
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

  Widget _buildVerticalSpacing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      autofocus: false,
      controller: _passwordController,
      decoration: new InputDecoration(
          contentPadding:
              EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.passwordToDecryptImportedNotes),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.importPasswordCannotBeEmpty;
        }
        return null;
      },
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
    );
  }

  Widget _buildFileChooserField() {
    return GestureDetector(
      child: Row(
        children: [
          Expanded(flex: 1, child: Icon(Icons.insert_drive_file_rounded)),
          Expanded(flex: 8, child: _buildFilenameField()),
        ],
      ),
      onTap: () async {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xml'],
        );
        if (result != null &&
            result.files.single.path != null &&
            result.files.single.name != null) {
          _importFullPath = result.files.single.path;
          _fileNameController.text = result.files.single.name!;
        }
      },
    );
  }

  Widget _buildFilenameField() {
    return TextFormField(
      autofocus: false,
      enabled: false,
      controller: _fileNameController,
      decoration: new InputDecoration(
        contentPadding:
            EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
        hintText: AppLocalizations.of(context)!.clickToChooseImportFile,
        errorStyle: TextStyle(
          color: Theme.of(context).errorColor, // or any other color
        ),
      ),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.pleaseSelectFileToImport;
        }
        return null;
      },
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
          if (_formKey.currentState!.validate() && _importFullPath != null) {
            setState(() {
              this._isBusy = true;
            });
            try {
              log.fine('Importing from ${_importFullPath!}');
              final imported = parseNotesFromFile(_importFullPath!);

              final verifyResult = await verifySignature(
                  imported.item1, _passwordController.text);
              log.fine("Verify import password result: $verifyResult");
              if (!verifyResult) {
                displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.incorrectImportPassword);
              } else {
                _totalToImport = imported.item2.length;
                _currentlyImporting = 0;

                for (var importedNote in imported.item2) {
                  // show progress on screen
                  _importProgressStreamController.add(++_currentlyImporting);

                  if (this._password == _passwordController.text) {
                    // app password is same as import password. just import it with a new id
                    importedNote.id = null;
                    await db.adapter.insertNote(importedNote);
                  } else {
                    final decryptedBody = await getNotePlainBody(
                        importedNote, _passwordController.text);
                    final newNote = await createNote(
                        null,
                        importedNote.categoryId,
                        importedNote.title,
                        decryptedBody,
                        this._password!,
                        importedNote.lastUpdate);
                    await db.adapter.insertNote(newNote);
                  }
                }

                Navigator.pop(context);
              }
            } catch (e) {
              log.fine("Failed to import notes");
              log.fine(e.toString());
              displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToImport);
            } finally {
              setState(() {
                this._isBusy = false;
              });
            }
          }
        },
        child: Text(AppLocalizations.of(context)!.importButton),
      ),
    );
  }
}
