import 'package:andsafe/models/note.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/category_icons.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:loading_overlay/loading_overlay.dart';

class NoteEditPage extends StatelessWidget {
  final String id;

  NoteEditPage(this.id);

  @override
  Widget build(BuildContext context) {
    var arguments = ModalRoute.of(context)!.settings.arguments as Map;
    String password = arguments['password']!;
    return _NoteEdit(int.tryParse(this.id), password);
  }
}

class _NoteEdit extends StatefulWidget {
  final int? id;
  final String password;

  _NoteEdit(this.id, this.password);

  @override
  State<StatefulWidget> createState() {
    return _NoteEditState(this.id, this.password);
  }
}

class _NoteEditState extends State<_NoteEdit> {
  final int? id;
  final String password;
  final _formKey = GlobalKey<FormState>();

  final titleFieldController = TextEditingController();
  final bodyFieldController = TextEditingController();

  late Future<bool> _loadNoteFuture;
  bool _isBusy = false;

  int _selectedCategory = 0;

  _NoteEditState(this.id, this.password);

  @override
  void initState() {
    super.initState();
    this._loadNoteFuture = _loadTheNote();
  }

  @override
  void dispose() {
    titleFieldController.dispose();
    bodyFieldController.dispose();
    super.dispose();
  }

  Future<bool> _loadTheNote() async {
    if (id != null) {
      Note? note = await db.adapter.getNote(id!);
      if (note != null) {
        titleFieldController.text = note.title;
        bodyFieldController.text = await getNotePlainBody(note, password);
        _selectedCategory = note.categoryId;
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(id == null ?
            AppLocalizations.of(context)!.createNoteTitle :
            AppLocalizations.of(context)!.editNoteTitle),
          actions: _buildTitleActionButtons(id),
        ),
        body: LoadingOverlay(
          isLoading: this._isBusy,
          child: Container(
            child: FutureBuilder(
              future: _loadNoteFuture,
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                if (snapshot.hasError) {
                  log.severe("Problem loading the note $id");
                  log.severe(snapshot.error.toString());
                  return Container(
                      child: Center(child: Text(AppLocalizations.of(context)!.errorLoadingNote)));
                }
                if (snapshot.data == null) {
                  return Container(
                      child: Center(child: CircularProgressIndicator()));
                } else if (snapshot.data! || (!snapshot.data! && id == null)) {
                  return Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildVerticalSpacing(),
                          _buildTitleFiled(),
                          _buildVerticalSpacing(),
                          _buildBodyField(),
                          _buildVerticalSpacing(),
                          _buildActionButtons()
                        ],
                      ),
                    ),
                  );
                }

                // Normally shouldn't reach here
                log.severe("Problem loading the note $id");
                return Container(
                    child: Center(child: Text(AppLocalizations.of(context)!.errorLoadingNote)));
              },
            ),
          ),
        ));
  }

  List<Widget> _buildTitleActionButtons(int? id) {
    if (id == null) {
      return [];
    }
    return [
      IconButton(
        icon: Icon(Icons.delete_rounded),
        onPressed: () {
          Navigator.pop(context, 'doDelete');
        },
      ),
    ];
  }

  Widget _buildVerticalSpacing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
    );
  }

  Widget _buildTitleFiled() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            autofocus: id == null,
            controller: titleFieldController,
            decoration: new InputDecoration(
                contentPadding:
                EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
                hintText: AppLocalizations.of(context)!.titleHint),
            // The validator receives the text that the user has entered.
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppLocalizations.of(context)!.titleCannotBeEmpty;
              }
              return null;
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton<int>(
              value: _selectedCategory,
              items: List<int>.generate(noteCategories.values.length, (i) => i).map((int value) {
                return new DropdownMenuItem<int>(
                  value: value,
                  child: getIconByCategory(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value ?? 0;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyField() {
    return TextFormField(
      controller: bodyFieldController,
      keyboardType: TextInputType.multiline,
      minLines: 5,
      maxLines: null,
      enableSuggestions: false,
      autocorrect: false,
      decoration: new InputDecoration(
          contentPadding:
              EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.textToBeEncrypted),
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
              Note theNote = await createNote(
                id,
                _selectedCategory,
                titleFieldController.text,
                // cannot encrypt empty block. add an empty line if there is nothing
                bodyFieldController.text.length == 0
                    ? "\n"
                    : bodyFieldController.text,
                password,
              );
              if (id == null) {
                await db.adapter.insertNote(theNote);
              } else {
                await db.adapter.updateNote(theNote);
              }
              Navigator.pop(context);
            } catch (e) {
              log.severe("Failed to save the note");
              log.severe(e.toString());
              displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToSaveTheNote);
            } finally {
              setState(() {
                this._isBusy = false;
              });
            }
          }
        },
        child: Text(AppLocalizations.of(context)!.saveButton),
      ),
    );
  }
}
