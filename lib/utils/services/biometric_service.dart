import 'dart:convert';

import 'package:andsafe/utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:andsafe/utils/services/preferences_service.dart';

const String _secureStorageKey = 'andsafe_biometric_password';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  // local_auth is used only for availability checks
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(enforceBiometrics: true),
  );

  /// Check if the device has biometric hardware and enrolled biometrics.
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      log.warning('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Check if the user has opted in to biometric unlock.
  Future<bool> isBiometricEnabled() async {
    return await Prefs.getBiometricEnabled();
  }

  /// Store the password in biometric-protected secure storage.
  /// The Keystore key is created with biometric binding, meaning
  /// only biometric-authenticated operations can access the data.
  Future<bool> storePassword(Uint8List password) async {
    try {
      final String encoded = base64Encode(password);
      await _secureStorage.write(
        key: _secureStorageKey,
        value: encoded,
      );
      await Prefs.setBiometricEnabled(true);
      return true;
    } catch (e) {
      log.severe('Failed to store password in secure storage: $e');
      return false;
    }
  }

  /// Retrieve the stored password with biometric authentication.
  /// The OS biometric prompt is shown by flutter_secure_storage itself
  /// because the Keystore key requires biometric auth to decrypt.
  /// Returns null if authentication fails, is cancelled, or no password
  /// is stored.
  Future<Uint8List?> authenticateAndRetrievePassword(
      String localizedReason) async {
    try {
      final String? encoded = await _secureStorage.read(
        key: _secureStorageKey,
        aOptions: AndroidOptions.biometric(
          biometricPromptTitle: localizedReason,
        ),
      );

      if (encoded == null) {
        // Password was not stored — possibly cleared after password change
        await Prefs.setBiometricEnabled(false);
        return null;
      }

      return Uint8List.fromList(base64Decode(encoded));
    } on PlatformException catch (e) {
      log.warning('Biometric authentication failed: $e');
      // If the key was invalidated (e.g. user enrolled new fingerprints),
      // clear the stored data and disable biometric.
      if (e.code == 'KeyPermanentlyInvalidatedException' ||
          e.code == 'PermanentlyLockedOut') {
        await clearStoredPassword();
      }
      return null;
    } catch (e) {
      log.severe('Error during biometric authentication: $e');
      return null;
    }
  }

  /// Clear the stored password and disable biometric unlock.
  /// Called on password change or when user opts out.
  Future<void> clearStoredPassword() async {
    try {
      await _secureStorage.delete(key: _secureStorageKey);
    } catch (e) {
      log.warning('Failed to delete stored password: $e');
    }
    await Prefs.setBiometricEnabled(false);
  }
}
