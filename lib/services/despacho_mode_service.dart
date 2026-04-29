import 'package:shared_preferences/shared_preferences.dart';

/// Local flags indicating whether this installation is configured as a
/// despacho machine (bodega and/or tecnología). Read by features that
/// should only activate on a dispatch terminal. Both flags default to off.
class DespachoModeService {
  static const _bodegaKey = 'despacho_mode_enabled';
  static const _tecnologiaKey = 'despacho_tecnologia_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bodegaKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bodegaKey, value);
  }

  Future<bool> isTecnologiaEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tecnologiaKey) ?? false;
  }

  Future<void> setTecnologiaEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tecnologiaKey, value);
  }
}
