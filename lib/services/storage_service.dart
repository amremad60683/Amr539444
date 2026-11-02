import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/installment.dart';
import '../models/settings.dart';
import '../models/txn.dart';

/// Stores everything locally on the phone (no server needed).
class StorageService {
  static const _kSettings = 'settings_v1';
  static const _kTxns = 'txns_v1';
  static const _kInstallments = 'installments_v1';
  static const _kOutings = 'outings_v1';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  List<Txn> loadTxns() => _list(_kTxns).map(Txn.fromJson).toList();

  List<Installment> loadInstallments() =>
      _list(_kInstallments).map(Installment.fromJson).toList();

  Map<String, double> loadOutings() {
    final raw = _prefs.getString(_kOutings);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  Future<void> saveSettings(AppSettings s) =>
      _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  Future<void> saveTxns(List<Txn> t) =>
      _prefs.setString(_kTxns, jsonEncode(t.map((e) => e.toJson()).toList()));

  Future<void> saveInstallments(List<Installment> i) => _prefs.setString(
      _kInstallments, jsonEncode(i.map((e) => e.toJson()).toList()));

  Future<void> saveOutings(Map<String, double> o) =>
      _prefs.setString(_kOutings, jsonEncode(o));

  Future<void> clear() => _prefs.clear();

  List<Map<String, dynamic>> _list(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }
}
