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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as Map?;
    return _NoteList(
        password: arguments != null && arguments.containsKey('password')
            ? arguments['password']
            : null);
  }
}

class _NoteList extends StatefulWidget {
  final String? password;

  _NoteList({this.password});

  @override
  _NoteListState createState() {
    return _NoteListState(this.password);
  }
}

class _NoteListState extends State<_NoteList> {
  String? _password;
  bool _isBusy = false;
  final _searchFieldController = TextEditingController();

  _NoteListState(String? password) {
    this._password = password;
  }

  @override
  void initState() {
    super.initState();
    if (this._password == null) {
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        _displayPasswordInputDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(context),
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
      ),
      drawer: _buildMainDrawer(),
      body: LoadingOverlay(
          isLoading: this._isBusy,
          progressIndicator: _buildLoadingIndicator(),
          child: Container(
            child: FutureBuilder(
              // to refresh the list with setState, don't use previously-obtained future
              future: Future.wait([_getNotes(), Prefs.getSwipeToDelete()]),
              builder:
                  (BuildContext context, AsyncSnapshot<List<Object>> snapshot) {
                if (snapshot.hasError) {
                  log.severe("Problem loading notes");
                  log.severe(snapshot.error.toString());
                  return Container(
                      child: Center(child: Text(AppLocalizations.of(context)!.problemLoadingNotes)));
                }
                if (snapshot.data == null) {
                  return Container(
                      child: Center(child: CircularProgressIndicator()));
                } else {
                  return _buildNoteList(snapshot.data![0] as List<Note>, snapshot.data![1] as bool);
                }
              },
            ),
          )),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          if (this._password != null) {
            FocusScope.of(context).unfocus();
            Navigator.pushNamed(context, 'note/new',
                arguments: {'password': this._password}).whenComplete(() {
              setState(() {
                // refresh the list
              });
            });
          } else {
            _displayPasswordInputDialog(context);
          }
        },
      ),
    );
  }

  Future<List<Note>> _getNotes() async {
    if (_searchFieldController.text.isEmpty) {
      return db.adapter.getNotes();
    }
    Set<int> ids =
        await db.adapter.searchNotes(_searchFieldController.text + '*');
    if (ids.isEmpty) {
      return <Note>[];
    }
    return db.adapter.getNotes(ids);
  }

  Widget _buildSearchField(context) {
    return Container(
        margin: const EdgeInsets.only(right: 10.0),
        child: TextField(
          autofocus: false,
          controller: _searchFieldController,
          style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.background,
            isDense: true,
            contentPadding: EdgeInsets.all(10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(30.0)),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(30.0)),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            prefixIcon: Icon(Icons.search_rounded,
                color: Theme.of(context).colorScheme.onPrimary),
            suffixIcon: IconButton(
              onPressed: () {
                _searchFieldController.clear();
                setState(() {});
              },
              icon: Icon(Icons.clear_rounded),
              iconSize: 20.0,
            ),
            hintText: AppLocalizations.of(context)!.searchTitle,
            hintStyle:
                TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ));
  }

  IconButton _buildSortByIconButton(
      {required String key,
      required IconData icon,
      required void Function()? onPressed}) {
    return IconButton(
      icon: Stack(fit: StackFit.passthrough, children: <Widget>[
        Positioned.fill(
          child: Icon(icon),
        ),
        FutureBuilder(
          future: Future.wait([Prefs.getSortBy(), Prefs.isSortAscending()]),
          builder:
              (BuildContext context, AsyncSnapshot<List<Object>> snapshot) {
            if (snapshot.hasError || snapshot.data == null) {
              return Container();
            }
            if (snapshot.data![0] == key) {
              if (snapshot.data![1] as bool) {
                return Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.arrow_drop_up, size: 15),
                );
              } else {
                return Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.arrow_drop_down, size: 15),
                );
              }
            } else {
              return Container();
            }
          },
        ),
      ]),
      onPressed: onPressed,
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 10),
          Text(AppLocalizations.of(context)!.loading),
        ]);
  }

  Widget _buildMainDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Container(
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
          ),
          Expanded(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.settings_rounded),
                  title: Text(AppLocalizations.of(context)!.settings),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, 'settings/change')
                      .whenComplete(() {
                        setState(() {
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
                          displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.passwordChanged);
                          setState(() {
                            this._password = null;
                            _displayPasswordInputDialog(context);
                          });
                        } else {
                          displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.passwordNotChanged);
                        }
                      })
                      .onError((error, stackTrace) {
                        displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.passwordNotChanged);
                      });
                  },
                  enabled: this._password != null,
                ),
                ListTile(
                  leading: Icon(Icons.read_more_rounded),
                  title: Text(AppLocalizations.of(context)!.importNotes),
                  subtitle: Text(AppLocalizations.of(context)!.importNotesHint),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, 'import/$_password')
                      .whenComplete(() {
                        setState(() {
                          // refresh the list
                        });
                      });
                  },
                  enabled: this._password != null,
                ),
                ListTile(
                  leading: Icon(Icons.save_rounded),
                  title: Text(AppLocalizations.of(context)!.exportNotes),
                  subtitle: Text(AppLocalizations.of(context)!.exportNotesHint),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      String? exportFileName = await getNewExportFullFilePath();
                      log.fine('Target export file: $exportFileName');
                      if (exportFileName == null) {
                        log.severe('Failed to generate an export file name');
                        displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToExport);
                        return;
                      }

                      await exportNotes(
                          exportFileName,
                          await db.adapter.getSignature(),
                          await db.adapter.getNotes());
                      displaySnackBarMsg(
                          context: context, msg: AppLocalizations.of(context)!.exportedToFile + exportFileName);
                    } catch (e) {
                      log.severe('Failed to export notes');
                      log.severe(e);
                      displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToExport);
                    }
                  },
                  // don't disable even when correct password is not entered
                ),
              ],
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
            )
          ),
        ],
      ),
    );
  }

  Widget _buildVersionText() {
    Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();

    return FutureBuilder(
      // to refresh the list with setState, don't use previously-obtained future
      future: packageInfo,
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        if (snapshot.hasError) {
          log.severe("Problem retrieving version info");
          log.severe(snapshot.error.toString());
          return Container(
              child: Center(child: Text('AndSafe3')));
        }
        if (snapshot.data == null) {
          return Container(
              child: Center(child: Text('AndSafe3')));
        } else {
          String appName = snapshot.data!.appName;
          String version = snapshot.data!.version;
          String buildNumber = snapshot.data!.buildNumber;

          return Container(
            alignment: Alignment.bottomRight,
            margin: const EdgeInsets.all(5.0),
            child: Text(
              '$appName $version build $buildNumber',
              style: DefaultTextStyle.of(context).style.apply(fontSizeFactor: 0.8),
            )
          );
        }
      }
    );
  }

  Widget _buildWebSiteLauncher() {
    final Uri home = Uri.https('github.com', '/kitsook/AndSafe3');

    return ListTile(
      leading: Icon(Icons.launch_rounded),
      onTap: () {
        launch(home.toString());
      },
      title: Text(AppLocalizations.of(context)!.visitWebSite),
    );
  }

  Widget _buildNoteList(List<Note> notes, bool swipeToDelete) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scrollbar(
      child: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (BuildContext context, int index) {
          final theNote = notes[index];

          var child = Card(
            child: ListTile(
              leading: getIconByCategory(theNote.categoryId),
              title: Text(theNote.title),
              subtitle: Text(formatter.format(theNote.lastUpdate)),
              onTap: () {
                if (_password != null) {
                  final id = theNote.id;
                  FocusScope.of(context).unfocus();
                  Navigator.pushNamed(context, 'note/$id',
                      arguments: {'password': this._password}
                  ).then((value) {
                    if (value == 'doDelete') {
                      return _doDeleteNote(id!);
                    }
                  }).whenComplete(() {
                    setState(() {
                      // refresh the list
                    });
                  });
                } else {
                  _displayPasswordInputDialog(context);
                }
              },
            ),
          );

          if (swipeToDelete && this._password != null) {
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
      // commented out for now. setting direction as none also disable scrolling
      // the dismiss logic should only allow deletion when password is set
      // direction: this._password == null? DismissDirection.none : DismissDirection.horizontal,
      background: Container(
        color: Theme.of(context).colorScheme.primary,
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerStart,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onPrimary,
          // color: Colors.red,
        ),
      ),
      secondaryBackground: Container(
        color: Theme.of(context).colorScheme.primary,
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerEnd,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onPrimary,
          // color: Colors.red,
        ),
      ),
      key: UniqueKey(),
      onDismissed: (_) async {
        _doDeleteNote(noteId);
      },
      child: child,
    );
  }

  Future<void> _doDeleteNote(int noteId) async {
    Note? justDeleted = await db.adapter.getNote(noteId);

    SnackBarAction undoAction = SnackBarAction(
      label: AppLocalizations.of(context)!.undo,
      onPressed: () async {
        if (justDeleted != null) {
          await db.adapter.insertNote(justDeleted);
        }
        setState(() {
        });
      },
    );
    if (this._password != null) {
      await db.adapter.deleteNote(noteId);
      displaySnackBarMsg(
          context: context,
          msg: AppLocalizations.of(context)!.goingToDeleteNote,
          action: undoAction);
    } else {
      _displayPasswordInputDialog(context);
    }
  }

  Future<void> _displayPasswordInputDialog(BuildContext context) async {
    String? enteredPassword;

    while(true) {
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
                hintText: AppLocalizations.of(context)!.passwordToDecryptYourNotes,
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

      try {
        Signature signature = await db.adapter.getSignature();
        final signatureCheck = await verifySignature(signature, enteredPassword!);
        if (signatureCheck) {
          this._password = enteredPassword;
          return;
        } else {
          displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToVerifyPassword);
        }
      } catch (e) {
        log.severe("Failed to verify password");
        log.severe(e.toString());
        displaySnackBarMsg(context: context, msg: AppLocalizations.of(context)!.failedToVerifyPassword);
      } finally {
        setState(() {
          this._isBusy = false;
        });
      }
    }

  }
}
