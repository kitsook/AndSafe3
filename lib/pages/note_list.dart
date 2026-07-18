import 'dart:async';
import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/utils/category_icons.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/note_service.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NoteList extends StatefulWidget {
  final Uint8List? password;
  final Widget? drawer;
  final ValueChanged<int>? onNoteSelected;
  final VoidCallback? onNewNoteRequested;
  final VoidCallback? onPasswordRequested;
  final VoidCallback? onRefreshRequested;
  final int refreshCounter;
  final bool authFlowCompleted;

  const NoteList({
    super.key,
    this.password,
    this.drawer,
    this.onNoteSelected,
    this.onNewNoteRequested,
    this.onPasswordRequested,
    this.onRefreshRequested,
    this.refreshCounter = 0,
    this.authFlowCompleted = true,
  });

  @override
  NoteListState createState() => NoteListState();
}

class NoteListState extends State<NoteList> {
  List<Note> _notes = [];
  final _searchFieldController = TextEditingController();
  final _notesScrollController = ScrollController();
  int? _scrollTo;
  bool _showTitle = true;
  Timer? _titleTimer;

  @override
  void initState() {
    super.initState();
    if (widget.authFlowCompleted) {
      _startTitleTimer();
    }
  }

  @override
  void didUpdateWidget(covariant NoteList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.authFlowCompleted && widget.authFlowCompleted) {
      _startTitleTimer();
    }
  }

  void _startTitleTimer() {
    if (_titleTimer == null && _showTitle) {
      _titleTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showTitle = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _searchFieldController.dispose();
    _notesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          child: _showTitle
              ? Text('AndSafe', key: ValueKey('title'))
              : _buildSearchField(context),
        ),
        centerTitle: false,
        actions: <Widget>[
          _buildSortByIconButton(
            key: prefSortKeyTitle,
            icon: Icons.sort_by_alpha_rounded,
            onPressed: () async {
              Prefs.setSortBy(prefSortKeyTitle);
              Prefs.setSortAscending(!await Prefs.isSortAscending());
              setState(() {});
            },
          ),
          _buildSortByIconButton(
            key: prefSortKeyLastUpdate,
            icon: Icons.timer_rounded,
            onPressed: () async {
              Prefs.setSortBy(prefSortKeyLastUpdate);
              Prefs.setSortAscending(!await Prefs.isSortAscending());
              setState(() {});
            },
          ),
        ],
      ),
      drawer: widget.drawer,
      body: SizedBox.expand(
        child: FutureBuilder(
          future: Future.wait([_reloadNotes(), Prefs.getSwipeToDelete()]),
          builder:
              (BuildContext context, AsyncSnapshot<List<Object>> snapshot) {
            if (snapshot.hasError) {
              log.severe("Problem loading notes");
              log.severe(snapshot.error.toString());
              return Center(
                  child: Text(
                      AppLocalizations.of(context)!.problemLoadingNotes));
            }

            if (snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_notesScrollController.hasClients && _scrollTo != null) {
                  final int pos =
                      _notes.takeWhile((note) => note.id != _scrollTo).length;
                  _notesScrollController.animateTo(pos * 80,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.ease);
                  _scrollTo = null;
                }
              });
            }

            if (snapshot.data == null) {
              return Center(child: CircularProgressIndicator());
            } else {
              return _buildNoteList(snapshot.data![1] as bool);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          if (widget.password != null) {
            FocusScope.of(context).unfocus();
            if (widget.onNewNoteRequested != null) {
              widget.onNewNoteRequested!();
            } else {
              Navigator.pushNamed(context, 'note/new',
                  arguments: {'password': widget.password}).then((value) {
                if (value is int) {
                  _scrollTo = value;
                }
              }).whenComplete(() {
                if (widget.onRefreshRequested != null) {
                  widget.onRefreshRequested!();
                } else {
                  setState(() {});
                }
              });
            }
          } else {
            if (widget.onPasswordRequested != null) {
              widget.onPasswordRequested!();
            }
          }
        },
      ),
    );
  }

  Future<int> _reloadNotes() async {
    final noteService = Provider.of<NoteService>(context, listen: false);
    if (_searchFieldController.text.isEmpty) {
      _notes = await noteService.getNotes();
      return _notes.length;
    }
    Set<int> ids =
        await noteService.searchNotes('${_searchFieldController.text}*');
    if (ids.isEmpty) {
      _notes = <Note>[];
      return 0;
    }
    _notes = await noteService.getNotes(ids);
    return _notes.length;
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      key: const ValueKey('search_field'),
      autofocus: false,
      controller: _searchFieldController,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.searchTitle,
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        suffixIcon: _searchFieldController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _searchFieldController.clear();
                  });
                },
                icon: const Icon(Icons.clear_rounded),
              )
            : null,
      ),
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  IconButton _buildSortByIconButton(
      {required String key,
      required IconData icon,
      required void Function()? onPressed}) {
    return IconButton(
      icon: FutureBuilder(
        future: Future.wait([Prefs.getSortBy(), Prefs.isSortAscending()]),
        builder: (BuildContext context, AsyncSnapshot<List<Object>> snapshot) {
          bool isSelected = false;
          bool isAscending = false;

          if (snapshot.hasData && snapshot.data != null) {
            isSelected = snapshot.data![0] == key;
            if (isSelected) {
              isAscending = snapshot.data![1] as bool;
            }
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon),
              SizedBox(
                width: 18,
                child: isSelected
                    ? Icon(
                        isAscending
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        size: 18,
                      )
                    : null,
              ),
            ],
          );
        },
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildNoteList(bool swipeToDelete) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final List<Note> notes = _notes;

    return Scrollbar(
      controller: _notesScrollController,
      child: ListView.builder(
        itemCount: notes.length,
        controller: _notesScrollController,
        itemBuilder: (BuildContext context, int index) {
          final theNote = notes[index];

          var child = Card(
            child: ListTile(
              leading: getIconByCategory(theNote.categoryId),
              title: Text(theNote.title),
              subtitle: Text(formatter.format(theNote.lastUpdate)),
              onTap: () {
                if (widget.password != null) {
                  final id = theNote.id;
                  FocusScope.of(context).unfocus();
                  if (widget.onNoteSelected != null) {
                    widget.onNoteSelected!(id!);
                  } else {
                    Navigator.pushNamed(context, 'note/$id',
                        arguments: {'password': widget.password}).then((value) {
                      if (value == 'doDelete') {
                        return doDeleteNote(id!);
                      }
                    }).whenComplete(() {
                      if (widget.onRefreshRequested != null) {
                        widget.onRefreshRequested!();
                      } else {
                        setState(() {});
                      }
                    });
                  }
                } else {
                  if (widget.onPasswordRequested != null) {
                    widget.onPasswordRequested!();
                  }
                }
              },
            ),
          );

          if (swipeToDelete && widget.password != null) {
            return _buildSwipeToDelete(theNote.id!, child);
          } else {
            return Container(
              child: child,
            );
          }
        },
      ),
    );
  }

  Widget _buildSwipeToDelete(int noteId, Widget child) {
    return Dismissible(
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerStart,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      secondaryBackground: Container(
        color: Theme.of(context).colorScheme.primary,
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerEnd,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      key: UniqueKey(),
      onDismissed: (_) async {
        _notes = _notes.where((n) => n.id != noteId).toList();
        await doDeleteNote(noteId);
      },
      child: child,
    );
  }

  Future<void> doDeleteNote(int noteId) async {
    final noteService = Provider.of<NoteService>(context, listen: false);
    Note? justDeleted = await noteService.getNote(noteId);
    if (!mounted) return;

    SnackBarAction undoAction = SnackBarAction(
      label: AppLocalizations.of(context)!.undo,
      onPressed: () async {
        if (justDeleted != null) {
          await noteService.insertNote(justDeleted);
        }
        if (widget.onRefreshRequested != null) {
          widget.onRefreshRequested!();
        } else {
          setState(() {});
        }
      },
    );
    if (widget.password != null) {
      await noteService.deleteNote(noteId);
      if (!mounted) return;
      if (widget.onRefreshRequested != null) {
        widget.onRefreshRequested!();
      } else {
        setState(() {});
      }
      displaySnackBarMsg(
          context: context,
          msg: AppLocalizations.of(context)!.goingToDeleteNote,
          action: undoAction);
    } else {
      if (widget.onPasswordRequested != null) {
        widget.onPasswordRequested!();
      }
    }
  }
}
