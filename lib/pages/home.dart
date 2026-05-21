import 'dart:convert';
import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/note.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/category_icons.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:andsafe/utils/services/export_import_service.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:andsafe/pages/note_edit.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Uint8List? _password;
  int? _selectedNoteId;
  bool _isCreatingNewNote = false;
  int _refreshCounter = 0;
  bool _isBusy = false;

  final GlobalKey<NoteEditState> _noteEditKey = GlobalKey<NoteEditState>();
  final GlobalKey<NoteListState> _noteListKey = GlobalKey<NoteListState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)!.settings.arguments as Map?;
      if (arguments != null && arguments.containsKey('password')) {
        setState(() {
          _password = arguments['password'];
        });
      } else {
        _displayPasswordInputDialog(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      if (this._password != null) {
        this._password!.fillRange(0, this._password!.length, 0);
        setState(() {
          this._password = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing =
        _password != null && (_selectedNoteId != null || _isCreatingNewNote);

    return PopScope(
      canPop: !isEditing,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (isEditing) {
          // Auto-save NoteEdit's changes before clearing editing state.
          // This must complete before setState, because setState triggers a
          // rebuild that removes NoteEdit and reloads the note list from DB.
          await _noteEditKey.currentState?.saveIfNeeded();
          setState(() {
            _selectedNoteId = null;
            _isCreatingNewNote = false;
          });
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isTabletLandscape = constraints.maxWidth > 600 &&
              MediaQuery.of(context).orientation == Orientation.landscape;

          if (isTabletLandscape) {
            return LoadingOverlay(
              isLoading: _isBusy,
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: MediaQuery.removePadding(
                        context: context,
                        removeRight: true,
                        child: NoteList(
                          key: _noteListKey,
                          password: _password,
                          refreshCounter: _refreshCounter,
                          drawer: SafeArea(child: _buildMainDrawer()),
                          onPasswordRequested: () =>
                              _displayPasswordInputDialog(context),
                          onRefreshRequested: () =>
                              setState(() => _refreshCounter++),
                          onNoteSelected: (id) async {
                            await _noteEditKey.currentState?.saveIfNeeded();
                            setState(() {
                              _selectedNoteId = id;
                              _isCreatingNewNote = false;
                              _refreshCounter++;
                            });
                          },
                          onNewNoteRequested: () async {
                            await _noteEditKey.currentState?.saveIfNeeded();
                            setState(() {
                              _selectedNoteId = null;
                              _isCreatingNewNote = true;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true,
                        child: (_password == null ||
                                (_selectedNoteId == null &&
                                    !_isCreatingNewNote))
                            ? Container(
                                color: Theme.of(context).colorScheme.surface)
                            : _buildNoteEdit(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return LoadingOverlay(
              isLoading: _isBusy,
              child: Stack(
                children: [
                  NoteList(
                    key: _noteListKey,
                    password: _password,
                    refreshCounter: _refreshCounter,
                    drawer: SafeArea(child: _buildMainDrawer()),
                    onPasswordRequested: () =>
                        _displayPasswordInputDialog(context),
                    onRefreshRequested: () => setState(() => _refreshCounter++),
                    onNoteSelected: (id) => setState(() {
                      _selectedNoteId = id;
                      _isCreatingNewNote = false;
                    }),
                    onNewNoteRequested: () => setState(() {
                      _selectedNoteId = null;
                      _isCreatingNewNote = true;
                    }),
                  ),
                  if (isEditing) _buildNoteEdit(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildNoteEdit() {
    return NoteEdit(
      key: _noteEditKey,
      id: _selectedNoteId,
      password: _password!,
      onNoteSaved: (id) {
        setState(() {
          _selectedNoteId = id;
          _isCreatingNewNote = false;
          _refreshCounter++;
        });
      },
      onNoteDeleted: (id) {
        if (id != null) {
          _noteListKey.currentState?.doDeleteNote(id);
        }
        setState(() {
          _selectedNoteId = null;
          _isCreatingNewNote = false;
          _refreshCounter++;
        });
      },
      onNoteCancelled: () {
        setState(() {
          _selectedNoteId = null;
          _isCreatingNewNote = false;
        });
      },
    );
  }

  Future<void> _displayPasswordInputDialog(BuildContext context) async {
    String? enteredPassword;

    while (true) {
      var _controller = TextEditingController();
      enteredPassword = null;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.enterYourPassword),
            content: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)!.passwordToDecryptYourNotes,
                suffixIcon: IconButton(
                  icon: Icon(Icons.arrow_right_alt_rounded),
                  onPressed: () {
                    enteredPassword = _controller.text;
                    Navigator.pop(context);
                  },
                ),
              ),
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (value) {
                enteredPassword = value;
                Navigator.pop(context);
              },
            ),
          );
        },
      );

      if (enteredPassword == null) {
        return;
      }

      setState(() {
        this._isBusy = true;
      });

      Uint8List? passwordBytes;
      try {
        Signature signature = await db.adapter.getSignature();
        passwordBytes = Uint8List.fromList(utf8.encode(enteredPassword!));
        final signatureCheck = await verifySignature(signature, passwordBytes);
        if (signatureCheck) {
          setState(() {
            this._password = passwordBytes;
            this._refreshCounter++;
          });
          return;
        } else {
          passwordBytes.fillRange(0, passwordBytes.length, 0);
          displaySnackBarMsg(
              context: context,
              msg: AppLocalizations.of(context)!.failedToVerifyPassword);
        }
      } catch (e) {
        passwordBytes?.fillRange(0, passwordBytes.length, 0);
        log.severe("Failed to verify password");
        log.severe(e.toString());
        displaySnackBarMsg(
            context: context,
            msg: AppLocalizations.of(context)!.failedToVerifyPassword);
      } finally {
        setState(() {
          this._isBusy = false;
        });
      }
    }
  }

  Widget _buildMainDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Container(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/images/icons/safe.png'),
                        width: 80,
                        height: 80,
                      ),
                      SizedBox(height: 10),
                      Text('AndSafe', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.settings_rounded),
                    title: Text(AppLocalizations.of(context)!.settings),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, 'settings/change')
                          .whenComplete(() {
                        setState(() {
                          _refreshCounter++;
                        });
                      });
                    },
                    enabled: this._password != null,
                  ),
                  ListTile(
                    leading: Icon(Icons.cached_rounded),
                    title: Text(AppLocalizations.of(context)!.changePassword),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, 'password/change')
                          .then((value) {
                        if (value != null && value as bool) {
                          displaySnackBarMsg(
                              context: context,
                              msg: AppLocalizations.of(context)!
                                  .passwordChanged);
                          setState(() {
                            this
                                ._password
                                ?.fillRange(0, this._password!.length, 0);
                            this._password = null;
                            _refreshCounter++;
                          });
                          _displayPasswordInputDialog(context);
                        } else {
                          displaySnackBarMsg(
                              context: context,
                              msg: AppLocalizations.of(context)!
                                  .passwordNotChanged);
                        }
                      }).onError((error, stackTrace) {
                        displaySnackBarMsg(
                            context: context,
                            msg: AppLocalizations.of(context)!
                                .passwordNotChanged);
                      });
                    },
                    enabled: this._password != null,
                  ),
                  ListTile(
                    leading: Icon(Icons.read_more_rounded),
                    title: Text(AppLocalizations.of(context)!.importNotes),
                    subtitle:
                        Text(AppLocalizations.of(context)!.importNotesHint),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, 'import',
                              arguments: {'password': this._password})
                          .whenComplete(() {
                        setState(() {
                          _refreshCounter++;
                        });
                      });
                    },
                    enabled: this._password != null,
                  ),
                  ListTile(
                    leading: Icon(Icons.save_rounded),
                    title: Text(AppLocalizations.of(context)!.exportNotes),
                    subtitle:
                        Text(AppLocalizations.of(context)!.exportNotesHint),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        String? exportFileName =
                            await getNewExportFullFilePath();
                        log.fine('Target export file: $exportFileName');
                        if (exportFileName == null) {
                          log.severe('Failed to generate an export file name');
                          displaySnackBarMsg(
                              context: context,
                              msg:
                                  AppLocalizations.of(context)!.failedToExport);
                          return;
                        }

                        await exportNotes(
                            exportFileName,
                            await db.adapter.getSignature(),
                            await db.adapter.getNotes());
                        displaySnackBarMsg(
                            context: context,
                            msg: AppLocalizations.of(context)!.exportedToFile +
                                exportFileName);
                      } catch (e) {
                        log.severe('Failed to export notes');
                        log.severe(e);
                        displaySnackBarMsg(
                            context: context,
                            msg: AppLocalizations.of(context)!.failedToExport);
                      }
                    },
                    enabled: this._password != null,
                  ),
                  ListTile(
                    leading: Icon(Icons.exit_to_app_rounded),
                    title: Text(AppLocalizations.of(context)!.exitApp),
                    onTap: () {
                      SystemNavigator.pop();
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(),
          Container(
            child: _buildWebSiteLauncher(),
          ),
          Container(
            child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: Column(
                children: [
                  _buildVersionText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionText() {
    Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();

    return FutureBuilder(
      future: packageInfo,
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        if (snapshot.hasError) {
          log.severe("Problem retrieving version info");
          log.severe(snapshot.error.toString());
          return Container(child: Center(child: Text('AndSafe3')));
        }
        if (snapshot.data == null) {
          return Container(child: Center(child: Text('AndSafe3')));
        } else {
          String appName = snapshot.data!.appName;
          String version = snapshot.data!.version;
          String buildNumber = snapshot.data!.buildNumber;

          return Container(
            alignment: Alignment.bottomRight,
            margin: const EdgeInsets.all(5.0),
            child: Text(
              '$appName $version build $buildNumber',
              style:
                  DefaultTextStyle.of(context).style.apply(fontSizeFactor: 0.8),
            ),
          );
        }
      },
    );
  }

  Widget _buildWebSiteLauncher() {
    final Uri home = Uri.https('github.com', '/kitsook/AndSafe3');

    return ListTile(
      leading: Icon(Icons.launch_rounded),
      onTap: () {
        launchUrl(home);
      },
      title: Text(AppLocalizations.of(context)!.visitWebSite),
    );
  }
}

class NoteList extends StatefulWidget {
  final Uint8List? password;
  final Widget? drawer;
  final ValueChanged<int>? onNoteSelected;
  final VoidCallback? onNewNoteRequested;
  final VoidCallback? onPasswordRequested;
  final VoidCallback? onRefreshRequested;
  final int refreshCounter;

  NoteList({
    Key? key,
    this.password,
    this.drawer,
    this.onNoteSelected,
    this.onNewNoteRequested,
    this.onPasswordRequested,
    this.onRefreshRequested,
    this.refreshCounter = 0,
  }) : super(key: key);

  @override
  NoteListState createState() => NoteListState();
}

class NoteListState extends State<NoteList> {
  List<Note> _notes = [];
  final _searchFieldController = TextEditingController();
  final _notesScrollController = ScrollController();
  int? _scrollTo;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AndSafe'),
        centerTitle: false,
        actions: <Widget>[
          _buildSortByIconButton(
            key: PREF_SORT_KEY_TITLE,
            icon: Icons.sort_by_alpha_rounded,
            onPressed: () async {
              Prefs.setSortBy(PREF_SORT_KEY_TITLE);
              Prefs.setSortAscending(!await Prefs.isSortAscending());
              setState(() {});
            },
          ),
          _buildSortByIconButton(
            key: PREF_SORT_KEY_LAST_UPDATE,
            icon: Icons.timer_rounded,
            onPressed: () async {
              Prefs.setSortBy(PREF_SORT_KEY_LAST_UPDATE);
              Prefs.setSortAscending(!await Prefs.isSortAscending());
              setState(() {});
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: _buildSearchField(context),
        ),
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
              return Container(
                  child: Center(
                      child: Text(
                          AppLocalizations.of(context)!.problemLoadingNotes)));
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
              return Container(
                  child: Center(child: CircularProgressIndicator()));
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
    if (_searchFieldController.text.isEmpty) {
      _notes = await db.adapter.getNotes();
      return _notes.length;
    }
    Set<int> ids =
        await db.adapter.searchNotes(_searchFieldController.text + '*');
    if (ids.isEmpty) {
      _notes = <Note>[];
      return 0;
    }
    _notes = await db.adapter.getNotes(ids);
    return _notes.length;
  }

  Widget _buildSearchField(context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 10.0, right: 10.0, bottom: 10.0),
      child: TextField(
        autofocus: false,
        controller: _searchFieldController,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          isDense: true,
          contentPadding: EdgeInsets.all(10),
          prefixIcon: Icon(Icons.search_rounded),
          prefixIconConstraints: BoxConstraints(
            minWidth: 20,
            minHeight: 20,
          ),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _searchFieldController.clear();
              });
            },
            icon: Icon(Icons.clear_rounded),
            iconSize: 20.0,
          ),
          hintText: AppLocalizations.of(context)!.searchTitle,
        ),
        onChanged: (_) {
          setState(() {});
        },
      ),
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
    Note? justDeleted = await db.adapter.getNote(noteId);

    SnackBarAction undoAction = SnackBarAction(
      label: AppLocalizations.of(context)!.undo,
      onPressed: () async {
        if (justDeleted != null) {
          await db.adapter.insertNote(justDeleted);
        }
        if (widget.onRefreshRequested != null) {
          widget.onRefreshRequested!();
        } else {
          setState(() {});
        }
      },
    );
    if (widget.password != null) {
      await db.adapter.deleteNote(noteId);
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
