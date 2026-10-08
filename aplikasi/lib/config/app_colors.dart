import 'package:flutter/material.dart';

/// Kumpulan warna aplikasi, diambil dari palet pada desain UI.
class AppColors {
  AppColors._();

  // ---- Palet utama (4 kotak warna pada desain) ----
  static const Color biru = Color(0xFF63B3ED);
  static const Color mint = Color(0xFF9AE6B4);
  static const Color navy = Color(0xFF140B2D);
  static const Color putih = Color(0xFFF8F9FA);

  // ---- Warna pendukung ----
  /// Warna header gelap pada halaman fitur (Info Kegiatan, Absen, dll).
  static const Color header = Color(0xFF272324);
  static const Color navyTerang = Color(0xFF2A1B5C);
  static const Color teks = Color(0xFF1E1B2E);
  static const Color teksAbu = Color(0xFF6B7280);
  static const Color garis = Color(0xFFE3E6EB);
  static const Color isian = Color(0xFFF1F3F6);
  static const Color merah = Color(0xFFE5484D);
  static const Color hijau = Color(0xFF2E9E5B);

  /// Latar di luar area aplikasi saat dibuka di layar lebar (browser laptop).
  static const Color latarLuar = Color(0xFFE9EBF0);

  // ---- Gradasi ----
  /// Kartu identitas guru di Beranda.
  static const List<Color> gradasiKartu = [
    Color(0xFF6CBD3B),
    Color(0xFF3F8F28),
    Color(0xFF2B7220),
  ];

  /// Banner "Informasi Akademik" di Beranda.
  static const List<Color> gradasiBanner = [
    Color(0xFF0E0640),
    Color(0xFF15055A),
  ];
}
