import 'dart:convert';
import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/biometric_service.dart';
import 'package:andsafe/utils/services/database_service.dart' as db;
import 'package:andsafe/utils/services/preferences_service.dart';
import 'package:flutter/material.dart';

class AuthService {
  final BuildContext context;
  final void Function(VoidCallback) setState;
  final void Function(bool) setIsBusy;
  final void Function(Uint8List?) setPassword;
  final int Function() refreshCounter;
  final void Function(int) setRefreshCounter;

  AuthService({
    required this.context,
    required this.setState,
    required this.setIsBusy,
    required this.setPassword,
    required this.refreshCounter,
    required this.setRefreshCounter,
  });

  final BiometricService _biometricService = BiometricService();

  Future<void> attemptBiometricUnlock() async {
    final bool biometricEnabled = await _biometricService.isBiometricEnabled();
    if (biometricEnabled) {
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
          passwordBytes!.fillRange(0, passwordBytes.length, 0);
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
      displayPasswordInputDialog();
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
      await migrateAllNotes(passwordBytes, oldVer, (current, total) async {
        migrationProgressNotifier.value =
            AppLocalizations.of(context)!.migratingNote(current, total);
      });
      log.fine(
          "Migration from ver=$oldVer to ver=$currentSignatureVer completed");
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      log.severe("Migration failed, DB rolled back");
      log.severe(e.toString());
      rethrow;
    } finally {
      migrationProgressNotifier.dispose();
    }
  }

  Future<bool> unlockWithPassword(Uint8List passwordBytes) async {
    Signature? signature = await db.adapter.getSignature();
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
    String? enteredPassword;
    bool? biometricPressed;
    final bool biometricEnabled = await _biometricService.isBiometricEnabled();

    while (true) {
      var _controller = TextEditingController();
      enteredPassword = null;
      biometricPressed = null;

      await showDialog(
        context: context,
        builder: (context) {
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
                if (biometricEnabled) ...[
                  SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      biometricPressed = true;
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.fingerprint),
                    label: Text(
                        AppLocalizations.of(context)!.unlockWithBiometrics),
                  ),
                ],
              ],
            ),
          );
        },
      );

      if (enteredPassword == null && biometricPressed == null) {
        return;
      }

      if (biometricPressed == true) {
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
            if (success) {
              return;
            } else {
              passwordBytes.fillRange(0, passwordBytes.length, 0);
              await _biometricService.clearStoredPassword();
              displaySnackBarMsg(
                  context: context,
                  msg: AppLocalizations.of(context)!.biometricFailed);
            }
          } else {
            displaySnackBarMsg(
                context: context,
                msg: AppLocalizations.of(context)!.biometricFailed);
          }
        } catch (e) {
          log.warning('Biometric unlock from password dialog failed: $e');
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

      setState(() {
        setIsBusy(true);
      });

      Uint8List? passwordBytes;
      try {
        passwordBytes = Uint8List.fromList(utf8.encode(enteredPassword!));
        final success = await unlockWithPassword(passwordBytes);
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
