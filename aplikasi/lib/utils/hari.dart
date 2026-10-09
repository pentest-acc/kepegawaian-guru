/// Fungsi bantu nama hari & minggu (Senin sebagai awal minggu).
class Hari {
  Hari._();

  /// Hari sekolah yang bisa diisi jadwal (sesuai database).
  static const List<String> sekolah = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  /// Nama hari dari tanggal, mis. 12-10-2026 -> "Senin".
  /// Hari Minggu menghasilkan "Minggu".
  static String nama(DateTime tanggal) => tanggal.weekday == DateTime.sunday
      ? 'Minggu'
      : sekolah[tanggal.weekday - 1];

  /// Tanggal hari Senin pada minggu yang sama dengan [tanggal]
  /// (jam dibuang, hanya tanggal).
  static DateTime seninDari(DateTime tanggal) {
    final t = DateTime(tanggal.year, tanggal.month, tanggal.day);
    return t.subtract(Duration(days: t.weekday - DateTime.monday));
  }

  /// Tanggal untuk [namaHari] di minggu yang diawali [senin].
  static DateTime tanggalPada(DateTime senin, String namaHari) =>
      DateTime(senin.year, senin.month, senin.day + sekolah.indexOf(namaHari));

  static bool tanggalSama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
