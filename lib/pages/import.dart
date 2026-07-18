import 'dart:async';
import 'dart:convert';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/note_service.dart';
import 'package:andsafe/utils/services/export_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:provider/provider.dart';

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as Map?;
    final Uint8List password = arguments!['password'];
    return _ImportPageInternal(password);
  }
}

class _ImportPageInternal extends StatefulWidget {
  final Uint8List _password;

  const _ImportPageInternal(this._password);

  @override
  State<StatefulWidget> createState() => _ImportPageState();
}

class _ImportPageState extends State<_ImportPageInternal> {
  String? _importFullPath;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _fileNameController = TextEditingController();
  bool _isBusy = false;
  bool _obscurePassword = true;

  final StreamController<int> _importProgressStreamController =
      StreamController<int>();
  late final Stream<int> _importProgressStream =
      _importProgressStreamController.stream.asBroadcastStream();

  int _totalToImport = 0;
  int _currentlyImporting = 0;

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
            isLoading: _isBusy,
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
    return StreamBuilder(
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
              Text('${AppLocalizations.of(context)!.importing} (${snapshot.data} / $_totalToImport)'),
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
        });
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
      decoration: InputDecoration(
          contentPadding:
              EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText:
              AppLocalizations.of(context)!.passwordToDecryptImportedNotes,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          )),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.importPasswordCannotBeEmpty;
        }
        return null;
      },
      obscureText: _obscurePassword,
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
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xml'],
        );
        if (result != null && result.files.single.path != null) {
          _importFullPath = result.files.single.path;
          _fileNameController.text = result.files.single.name;
        }
      },
    );
  }

  Widget _buildFilenameField() {
    return TextFormField(
      autofocus: false,
      enabled: false,
      controller: _fileNameController,
      decoration: InputDecoration(
        contentPadding:
            EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
        hintText: AppLocalizations.of(context)!.clickToChooseImportFile,
        errorStyle: TextStyle(
          color: Theme.of(context).highlightColor, // or any other color
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
              _isBusy = true;
            });
            Uint8List? importPasswordBytes;
            try {
              log.fine('Importing from ${_importFullPath!}');
              final imported = parseNotesFromFile(_importFullPath!);
              importPasswordBytes =
                  Uint8List.fromList(utf8.encode(_passwordController.text));

              final verifyResult =
                  await verifySignature(imported.item1, importPasswordBytes);
              log.fine("Verify import password result: $verifyResult");
              if (!verifyResult) {
                if (!mounted) return;
                displaySnackBarMsg(
                    context: context,
                    msg: AppLocalizations.of(context)!.incorrectImportPassword);
              } else {
                _totalToImport = imported.item2.length;
                _currentlyImporting = 0;

                // Prepare all notes first (crypto + progress reporting)
                final notesToInsert = <Note>[];
                for (var importedNote in imported.item2) {
                  // show progress on screen
                  _importProgressStreamController.add(++_currentlyImporting);

                  if (listEquals(widget._password, importPasswordBytes) &&
                      imported.item1.ver == currentSignatureVer) {
                    // app password is same as import password and same version.
                    // just import it with a new id
                    importedNote.id = null;
                    notesToInsert.add(importedNote);
                  } else {
                    // different password or different version. re-encrypt
                    final decryptedBody = await getNotePlainBody(
                        importedNote, importPasswordBytes,
                        version: imported.item1.ver);
                    if (!mounted) return;
                    final newNote = await createNote(
                        null,
                        importedNote.categoryId,
                        importedNote.title,
                        decryptedBody,
                        widget._password,
                        version: currentSignatureVer,
                        lastUpdated: importedNote.lastUpdate);
                    if (!mounted) return;
                    notesToInsert.add(newNote);
                  }
                }

                if (!mounted) return;
                // Insert all notes atomically in a single transaction
                final noteService = Provider.of<NoteService>(context, listen: false);
                final database = noteService.db;
                await database.transaction((txn) async {
                  for (var note in notesToInsert) {
                    await noteService.insertNote(note, txn);
                  }
                });

                if (!mounted) return;
                Navigator.pop(context);
              }
            } catch (e) {
              log.fine("Failed to import notes");
              log.fine(e.toString());
              if (!mounted) return;
              displaySnackBarMsg(
                  context: context,
                  msg: AppLocalizations.of(context)!.failedToImport);
            } finally {
              importPasswordBytes?.fillRange(0, importPasswordBytes.length, 0);
              if (mounted) {
                setState(() {
                  _isBusy = false;
                });
              }
            }
          }
        },
        child: Text(AppLocalizations.of(context)!.importButton),
      ),
    );
  }
}
