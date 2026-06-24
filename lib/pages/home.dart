import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/pages/home_drawer.dart';
import 'package:andsafe/pages/note_edit.dart';
import 'package:andsafe/pages/note_list.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/auth_service.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:andsafe/utils/services/export_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_overlay/loading_overlay.dart';

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

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService = AuthService(
      context: context,
      setState: (fn) => setState(fn),
      setIsBusy: (v) => _isBusy = v,
      setPassword: (v) => _password = v,
      refreshCounter: () => _refreshCounter,
      setRefreshCounter: (v) => _refreshCounter = v,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)!.settings.arguments as Map?;
      if (arguments != null && arguments.containsKey('password')) {
        setState(() {
          _password = arguments['password'];
        });
        _authService.offerBiometricEnrollment(arguments['password']);
      } else {
        _authService.attemptBiometricUnlock();
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
                              _authService.displayPasswordInputDialog(),
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
                        _authService.displayPasswordInputDialog(),
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
      signatureVer: currentSignatureVer,
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

  Widget _buildMainDrawer() {
    return HomeDrawer(
      isAuthenticated: _password != null,
      onOpenSettings: () {
        Navigator.of(context).pop();
        Navigator.pushNamed(context, 'settings/change',
                arguments: {'password': this._password})
            .whenComplete(() {
          setState(() {
            _refreshCounter++;
          });
        });
      },
      onChangePassword: () {
        Navigator.of(context).pop();
        Navigator.pushNamed(context, 'password/change').then((value) {
          if (value != null && value as bool) {
            displaySnackBarMsg(
                context: context,
                msg: AppLocalizations.of(context)!.passwordChanged);
            setState(() {
              this._password?.fillRange(0, this._password!.length, 0);
              this._password = null;
              _refreshCounter++;
            });
            _authService.displayPasswordInputDialog();
          } else {
            displaySnackBarMsg(
                context: context,
                msg: AppLocalizations.of(context)!.passwordNotChanged);
          }
        }).onError((error, stackTrace) {
          displaySnackBarMsg(
              context: context,
              msg: AppLocalizations.of(context)!.passwordNotChanged);
        });
      },
      onImportNotes: () {
        Navigator.of(context).pop();
        Navigator.pushNamed(context, 'import',
                arguments: {'password': this._password})
            .whenComplete(() {
          setState(() {
            _refreshCounter++;
          });
        });
      },
      onExportNotes: () async {
        try {
          String? exportFileName = await getNewExportFullFilePath();
          log.fine('Target export file: $exportFileName');
          if (exportFileName == null) {
            log.severe('Failed to generate an export file name');
            displaySnackBarMsg(
                context: context,
                msg: AppLocalizations.of(context)!.failedToExport);
            return;
          }

          final signature = await db.adapter.getSignature();
          if (signature == null) {
            throw Exception('No signature found');
          }
          await exportNotes(
              exportFileName,
              signature,
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
      onExitApp: () {
        SystemNavigator.pop();
      },
    );
  }
}
