import 'dart:convert';
import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/biometric_service.dart';
import 'package:andsafe/utils/services/note_service.dart';
import 'package:andsafe/utils/services/signature_service.dart';
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthService {
  final BuildContext context;
  final void Function(VoidCallback) setState;
  final void Function(bool) setIsBusy;
  final void Function(Uint8List?) setPassword;
  final int Function() refreshCounter;
  final void Function(int) setRefreshCounter;

  final BiometricService _biometricService;

  AuthService({
    required this.context,
    required this.setState,
    required this.setIsBusy,
    required this.setPassword,
    required this.refreshCounter,
    required this.setRefreshCounter,
    BiometricService? biometricService,
  }) : _biometricService = biometricService ?? BiometricService();

  /// Securely purges in-memory authentication credentials and triggers state cleanup.
  void lockSession({VoidCallback? onWipeComplete}) {
    setPassword(null);
    if (onWipeComplete != null) {
      onWipeComplete();
    }
  }

  Future<void> attemptBiometricUnlock() async {
    final bool biometricEnabled = await _biometricService.isBiometricEnabled();
    if (biometricEnabled) {
      if (!context.mounted) return;
      setState(() {
        setIsBusy(true);
      });

      try {
        final Uint8List? passwordBytes =
            await _biometricService.authenticateAndRetrievePassword(
          AppLocalizations.of(context)!.biometricReason,
        );

        if (passwordBytes != null) {
          final success = await unlockWithPassword(passwordBytes);
          if (!success) {
            passwordBytes.fillRange(0, passwordBytes.length, 0);
            await _biometricService.clearStoredPassword();
          }
          return;
        } else {
          await _biometricService.clearStoredPassword();
        }
      } catch (e) {
        log.warning('Biometric unlock failed: $e');
      } finally {
        setState(() {
          setIsBusy(false);
        });
      }
    }

    if (context.mounted) {
      await displayPasswordInputDialog();
    }
  }

  Future<void> performMigration(Uint8List passwordBytes, int oldVer) async {
    final migrationProgressNotifier = ValueNotifier<String>('');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(AppLocalizations.of(context)!.upgradingData),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: migrationProgressNotifier,
                  builder: (context, value, _) => Text(value),
                ),
                SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.doNotCloseApp),
              ],
            ),
          ),
        );
      },
    );
    try {
      final noteService = Provider.of<NoteService>(context, listen: false);
      final signatureService = Provider.of<SignatureService>(context, listen: false);
      await migrateAllNotes(noteService, signatureService, passwordBytes, oldVer, (current, total) async {
        if (!context.mounted) return;
        migrationProgressNotifier.value =
            AppLocalizations.of(context)!.migratingNote(current, total);
      });
      log.fine(
          "Migration from ver=$oldVer to ver=$currentSignatureVer completed");
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      log.severe("Migration failed, DB rolled back");
      log.severe(e.toString());
      rethrow;
    } finally {
      migrationProgressNotifier.dispose();
    }
  }

  Future<bool> unlockWithPassword(Uint8List passwordBytes) async {
    final signatureService = Provider.of<SignatureService>(context, listen: false);
    Signature? signature = await signatureService.getSignature();
    final signatureCheck = await verifySignature(signature, passwordBytes);
    if (signatureCheck) {
      if (signature != null && signature.ver < currentSignatureVer) {
        await performMigration(passwordBytes, signature.ver);
      }
      setState(() {
        setPassword(passwordBytes);
        setRefreshCounter(refreshCounter() + 1);
      });
      offerBiometricEnrollment(passwordBytes);
      return true;
    }
    return false;
  }

  Future<void> offerBiometricEnrollment(Uint8List password) async {
    final bool alreadyOffered = await Prefs.getBiometricOffered();
    if (alreadyOffered) return;

    final bool available = await _biometricService.isBiometricAvailable();
    if (!available) return;

    await Prefs.setBiometricOffered(true);

    if (!context.mounted) return;

    final bool? shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(Icons.fingerprint, size: 48),
          title: Text(AppLocalizations.of(context)!.enableBiometricPrompt),
          content:
              Text(AppLocalizations.of(context)!.enableBiometricDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.enable),
            ),
          ],
        );
      },
    );

    if (shouldEnable == true) {
      final bool stored = await _biometricService.storePassword(password);
      if (context.mounted) {
        displaySnackBarMsg(
          context: context,
          msg: stored
              ? AppLocalizations.of(context)!.biometricEnabled
              : AppLocalizations.of(context)!.biometricFailed,
        );
      }
    }
  }

  Future<void> displayPasswordInputDialog() async {
    final bool biometricEnabled = await _biometricService.isBiometricEnabled();

    while (true) {
      if (!context.mounted) return;
      final PasswordInputDialogResult? result =
          await showDialog<PasswordInputDialogResult>(
        context: context,
        builder: (context) =>
            PasswordInputDialog(biometricEnabled: biometricEnabled),
      );

      if (result == null) {
        return;
      }

      if (result.isBiometric) {
        if (!context.mounted) continue;
        setState(() {
          setIsBusy(true);
        });

        try {
          final Uint8List? passwordBytes =
              await _biometricService.authenticateAndRetrievePassword(
            AppLocalizations.of(context)!.biometricReason,
          );

          if (!context.mounted) continue;
          if (passwordBytes != null) {
            final success = await unlockWithPassword(passwordBytes);
            if (!context.mounted) continue;
            if (success) {
              return;
            } else {
              passwordBytes.fillRange(0, passwordBytes.length, 0);
              await _biometricService.clearStoredPassword();
              if (!context.mounted) continue;
              displaySnackBarMsg(
                  context: context,
                  msg: AppLocalizations.of(context)!.biometricFailed);
            }
          } else {
            if (!context.mounted) continue;
            displaySnackBarMsg(
                context: context,
                msg: AppLocalizations.of(context)!.biometricFailed);
          }
        } catch (e) {
          log.warning('Biometric unlock from password dialog failed: $e');
          if (!context.mounted) continue;
          displaySnackBarMsg(
              context: context,
              msg: AppLocalizations.of(context)!.biometricFailed);
        } finally {
          setState(() {
            setIsBusy(false);
          });
        }
        continue;
      }

      if (!context.mounted) return;
      setState(() {
        setIsBusy(true);
      });

      Uint8List? passwordBytes;
      try {
        passwordBytes = Uint8List.fromList(utf8.encode(result.password!));
        final success = await unlockWithPassword(passwordBytes);
        if (!context.mounted) return;
        if (success) {
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
        if (!context.mounted) return;
        displaySnackBarMsg(
            context: context,
            msg: AppLocalizations.of(context)!.failedToVerifyPassword);
      } finally {
        setState(() {
          setIsBusy(false);
        });
      }
    }
  }
}

class PasswordInputDialogResult {
  final String? password;
  final bool isBiometric;

  const PasswordInputDialogResult.password(this.password)
      : isBiometric = false;
  const PasswordInputDialogResult.biometric()
      : password = null,
        isBiometric = true;
}

class PasswordInputDialog extends StatefulWidget {
  final bool biometricEnabled;

  const PasswordInputDialog({super.key, required this.biometricEnabled});

  @override
  State<PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<PasswordInputDialog> {
  late final TextEditingController _controller;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    Navigator.pop(context, PasswordInputDialogResult.password(text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.enterYourPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText:
                  AppLocalizations.of(context)!.passwordToDecryptYourNotes,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscureText
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_right_alt_rounded),
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            obscureText: _obscureText,
            enableSuggestions: false,
            autocorrect: false,
            autofocus: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submit(),
          ),
          if (widget.biometricEnabled) ...[
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                    context, const PasswordInputDialogResult.biometric());
              },
              icon: Icon(Icons.fingerprint),
              label: Text(
                  AppLocalizations.of(context)!.unlockWithBiometrics),
            ),
          ],
        ],
      ),
    );
  }
}
