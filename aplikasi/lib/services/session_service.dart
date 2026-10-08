import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pengguna.dart';

/// Menyimpan sesi login (token + data pengguna) di memori perangkat,
/// supaya guru tidak perlu login ulang setiap membuka aplikasi.
class SessionService {
  static const String _kunciToken = 'sesi_token';
  static const String _kunciPengguna = 'sesi_pengguna';

  Future<void> simpan(String token, Pengguna pengguna) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunciToken, token);
    await prefs.setString(_kunciPengguna, jsonEncode(pengguna.toJson()));
  }

  Future<void> perbaruiPengguna(Pengguna pengguna) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunciPengguna, jsonEncode(pengguna.toJson()));
  }

  Future<String?> ambilToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kunciToken);
  }

  Future<Pengguna?> ambilPengguna() async {
    final prefs = await SharedPreferences.getInstance();
    final teks = prefs.getString(_kunciPengguna);
    if (teks == null) return null;

    try {
      return Pengguna.fromJson(jsonDecode(teks) as Map<String, dynamic>);
    } catch (_) {
      // Data rusak / format lama: anggap belum login.
      return null;
    }
  }

  Future<void> hapus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kunciToken);
    await prefs.remove(_kunciPengguna);
  }
}
