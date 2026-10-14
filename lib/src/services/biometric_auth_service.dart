import 'package:local_auth/local_auth.dart';

/// Thin wrapper around [LocalAuthentication] used to gate the Vault.
class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether this device can authenticate the user at all, either with
  /// biometrics or a device PIN/passcode/pattern fallback.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on LocalAuthException {
      return false;
    }
  }

  /// Prompts for authentication. Returns true only when the user succeeds.
  ///
  /// Fingerprint / face unlock is preferred; on devices without enrolled
  /// biometrics the platform falls back to the device passcode so the user is
  /// never permanently locked out of the Vault.
  Future<bool> authenticate({
    String reason = 'Unlock Vault',
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
