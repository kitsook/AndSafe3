import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/category_icons.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:flutter/material.dart';
import 'package:loading_overlay/loading_overlay.dart';

class NoteEditPage extends StatelessWidget {
  final String id;
  final Key? noteEditKey;

  NoteEditPage(this.id, {this.noteEditKey});

  @override
  Widget build(BuildContext context) {
    var arguments = ModalRoute.of(context)!.settings.arguments as Map;
    Uint8List password = arguments['password']!;
    return NoteEdit(
      key: noteEditKey,
      id: int.tryParse(this.id),
      password: password,
    );
  }
}

class NoteEdit extends StatefulWidget {
  final int? id;
  final Uint8List password;
  final ValueChanged<int?>? onNoteSaved;
  final ValueChanged<int?>? onNoteDeleted;
  final VoidCallback? onNoteCancelled;

  NoteEdit(
      {Key? key,
      this.id,
      required this.password,
      this.onNoteSaved,
      this.onNoteDeleted,
      this.onNoteCancelled})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return NoteEditState();
  }
}

class NoteEditState extends State<NoteEdit> {
  final _formKey = GlobalKey<FormState>();

  final titleFieldController = TextEditingController();
  final bodyFieldController = TextEditingController();

  late Future<bool> _loadNoteFuture;
  bool _isBusy = false;

  int _selectedCategory = 0;

  String _originalTitle = "";
  String _originalBody = "";
  int _originalCategory = 0;
  bool _hasStartedEditing = false;
  bool _isUndoSnackbarShowing = false;
  bool _forcePop = false;

  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    this._loadNoteFuture = _loadTheNote();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void didUpdateWidget(NoteEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      this._loadNoteFuture = _loadTheNote();
    }
  }

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    titleFieldController.dispose();
    bodyFieldController.dispose();
    super.dispose();
  }

  Future<bool> _loadTheNote() async {
    if (widget.id != null) {
      Note? note = await db.adapter.getNote(widget.id!);
      if (note != null) {
        titleFieldController.text = note.title;
        bodyFieldController.text =
            await getNotePlainBody(note, widget.password);
        _selectedCategory = note.categoryId;
        
        _originalTitle = note.title;
        _originalBody = bodyFieldController.text;
        _originalCategory = note.categoryId;
        _hasStartedEditing = false;
        
        return true;
      }
    } else {
      _originalTitle = "";
      _originalBody = "";
      _originalCategory = 0;
      _hasStartedEditing = false;
      return true;
    }
    return false;
  }

  bool _hasChanges() {
    return titleFieldController.text != _originalTitle ||
           bodyFieldController.text != _originalBody ||
           _selectedCategory != _originalCategory;
  }

  void _onFieldChanged() {
    bool hasChanges = _hasChanges();
    if (hasChanges && !_isUndoSnackbarShowing) {
      _isUndoSnackbarShowing = true;
      _hasStartedEditing = true;
      var controller = displaySnackBarMsg(
        context: context,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.undo),
              onPressed: () {
                _undoChanges();
              },
            ),
          ],
        ),
        duration: Duration(days: 365), // persist
      );
      
      controller.closed.then((reason) {
        if (mounted) {
          _isUndoSnackbarShowing = false;
        }
      });
    } else if (!hasChanges && _isUndoSnackbarShowing) {
      _isUndoSnackbarShowing = false;
      _scaffoldMessenger?.hideCurrentSnackBar();
    }
  }

  void _undoChanges() {
    setState(() {
      titleFieldController.text = _originalTitle;
      bodyFieldController.text = _originalBody;
      _selectedCategory = _originalCategory;
      _hasStartedEditing = false;
      _isUndoSnackbarShowing = false;
    });
    _scaffoldMessenger?.hideCurrentSnackBar();
  }

  Future<int?> _autoSave() async {
    final currentTitle = titleFieldController.text.trim().isEmpty ? "Untitled Note" : titleFieldController.text;
    final currentBody = bodyFieldController.text.isEmpty ? "\n" : bodyFieldController.text;
    try {
      Note theNote = await createNote(
        widget.id,
        _selectedCategory,
        currentTitle,
        currentBody,
        widget.password,
      );
      int? newId = widget.id;
      if (widget.id == null) {
        newId = await db.adapter.insertNote(theNote);
      } else {
        await db.adapter.updateNote(theNote);
      }
      return newId;
    } catch (e) {
      log.severe("Failed to auto-save the note");
      log.severe(e.toString());
      displaySnackBarMsg(
          context: context,
          msg: AppLocalizations.of(context)!.failedToSaveTheNote);
      return null;
    }
  }

  Future<void> _handleNavigateAway({bool isPopInvoked = false, bool isCancelAction = false}) async {
    if (_hasStartedEditing && _hasChanges()) {
      int? newId = await _autoSave();
      if (mounted) {
        setState(() {
          this._forcePop = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isPopInvoked) {
             Navigator.pop(context, newId);
          } else {
             if (isCancelAction) {
               if (widget.onNoteCancelled != null) {
                 widget.onNoteCancelled!();
               } else {
                 Navigator.pop(context); // Note: pop might not pass newId back here, but it's a cancel
               }
             } else {
               if (widget.onNoteSaved != null) {
                 widget.onNoteSaved!(newId);
               } else {
                 Navigator.pop(context, newId);
               }
             }
          }
        });
      }
    } else {
      setState(() {
        this._forcePop = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isPopInvoked) {
           Navigator.pop(context);
        } else {
           if (widget.onNoteCancelled != null) {
             widget.onNoteCancelled!();
           } else {
             Navigator.pop(context);
           }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _forcePop || !_hasChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleNavigateAway(isPopInvoked: true);
      },
      child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                await _handleNavigateAway(isPopInvoked: false, isCancelAction: true);
              },
            ),
            title: Text(widget.id == null
                ? AppLocalizations.of(context)!.createNoteTitle
                : AppLocalizations.of(context)!.editNoteTitle),
            actions: _buildTitleActionButtons(widget.id),
          ),
          body: LoadingOverlay(
            isLoading: this._isBusy,
            child: Container(
              child: FutureBuilder(
                future: _loadNoteFuture,
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.hasError) {
                    log.severe("Problem loading the note ${widget.id}");
                    log.severe(snapshot.error.toString());
                    return Container(
                        child: Center(
                            child: Text(
                                AppLocalizations.of(context)!.errorLoadingNote)));
                  }
                  if (snapshot.data == null) {
                    return Container(
                        child: Center(child: CircularProgressIndicator()));
                  } else if (snapshot.data! ||
                      (!snapshot.data! && widget.id == null)) {
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
                          ],
                        ),
                      ),
                    );
                  }
  
                  // Normally shouldn't reach here
                  log.severe("Problem loading the note ${widget.id}");
                  return Container(
                      child: Center(
                          child: Text(
                              AppLocalizations.of(context)!.errorLoadingNote)));
                },
              ),
            ),
          )),
    );
  }

  List<Widget> _buildTitleActionButtons(int? id) {
    return [
      if (id != null)
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: Icon(Icons.delete_rounded),
            tooltip: "Delete",
            onPressed: () {
              setState(() {
                this._forcePop = true;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.onNoteDeleted != null) {
                  widget.onNoteDeleted!(id);
                } else {
                  Navigator.pop(context, 'doDelete');
                }
              });
            },
          ),
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
            autofocus: widget.id == null,
            controller: titleFieldController,
            onChanged: (value) => _onFieldChanged(),
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
              items: List<int>.generate(noteCategories.values.length, (i) => i)
                  .map((int value) {
                return new DropdownMenuItem<int>(
                  value: value,
                  child: getIconByCategory(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value ?? 0;
                  _onFieldChanged();
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
      onChanged: (value) => _onFieldChanged(),
      keyboardType: TextInputType.multiline,
      minLines: 5,
      maxLines: null,
      autocorrect: false,
      decoration: new InputDecoration(
          contentPadding:
              EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.textToBeEncrypted),
    );
  }
}
