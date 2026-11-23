/// Tahun ajaran sekolah: Juli sampai Juni tahun berikutnya.
/// Semester Ganjil = Juli-Desember, Semester Genap = Januari-Juni.
class TahunAjaran {
  const TahunAjaran(this.tahunAwal);

  /// Tahun bulan Juli, mis. 2026 untuk tahun ajaran 2026/2027.
  final int tahunAwal;

  /// Tahun ajaran yang memuat [tanggal].
  factory TahunAjaran.dari(DateTime tanggal) =>
      TahunAjaran(tanggal.month >= 7 ? tanggal.year : tanggal.year - 1);

  /// "2026/2027"
  String get label => '$tahunAwal/${tahunAwal + 1}';

  /// Tanggal 1 di setiap bulan: Juli ... Juni.
  List<DateTime> get daftarBulan => [
    for (var i = 0; i < 12; i++) DateTime(tahunAwal, 7 + i),
  ];

  DateTime get bulanPertama => DateTime(tahunAwal, 7);
  DateTime get bulanTerakhir => DateTime(tahunAwal + 1, 6);

  /// Tahun ajaran sebelumnya / berikutnya.
  TahunAjaran geser(int jumlah) => TahunAjaran(tahunAwal + jumlah);

  /// "Ganjil" (Juli-Desember) atau "Genap" (Januari-Juni).
  static String semester(DateTime bulan) =>
      bulan.month >= 7 ? 'Ganjil' : 'Genap';

  /// Daftar tahun ajaran dari [awal] sampai [akhir] (urut terbaru dulu).
  static List<TahunAjaran> rentang(DateTime awal, DateTime akhir) {
    final pertama = TahunAjaran.dari(awal).tahunAwal;
    final terakhir = TahunAjaran.dari(akhir).tahunAwal;
    return [for (var t = terakhir; t >= pertama; t--) TahunAjaran(t)];
  }

  @override
  bool operator ==(Object other) =>
      other is TahunAjaran && other.tahunAwal == tahunAwal;

  @override
  int get hashCode => tahunAwal.hashCode;
}
