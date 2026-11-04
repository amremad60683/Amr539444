import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID / fingerprint unlock. Every call is safe on devices (and tests)
/// without biometrics: it simply reports "not available".
class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }
}
