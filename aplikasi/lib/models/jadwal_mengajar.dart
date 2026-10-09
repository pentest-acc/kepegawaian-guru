/// Satu jam pelajaran dalam jadwal mengajar MINGGUAN seorang guru.
///
/// Jadwal ini berlaku setiap minggu pada [hari] yang sama, sampai admin
/// mengubah atau menghapusnya.
class JadwalMengajar {
  const JadwalMengajar({
    this.idJadwal,
    required this.idPengguna,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.unit,
    required this.kelas,
    required this.mataPelajaran,
  });

  /// null untuk jadwal baru yang belum disimpan.
  final int? idJadwal;
  final int idPengguna;

  /// Senin ... Sabtu
  final String hari;

  /// Format "HH:MM", mis. "07:30".
  final String jamMulai;
  final String jamSelesai;

  /// KB, TK, atau SD
  final String unit;
  final String kelas;
  final String mataPelajaran;

  /// Menit sejak tengah malam, mis. "07:30" -> 450.
  static int keMenit(String jam) {
    final bagian = jam.split(':');
    return int.parse(bagian[0]) * 60 + int.parse(bagian[1]);
  }

  int get menitMulai => keMenit(jamMulai);
  int get menitSelesai => keMenit(jamSelesai);
  int get durasiMenit => menitSelesai - menitMulai;

  /// "07.30 - 09.00" (format jam Indonesia memakai titik).
  String get jamTampil =>
      '${jamMulai.replaceAll(':', '.')} - ${jamSelesai.replaceAll(':', '.')}';

  factory JadwalMengajar.fromJson(Map<String, dynamic> json) => JadwalMengajar(
    idJadwal: int.parse(json['id_jadwal'].toString()),
    idPengguna: int.parse(json['id_pengguna'].toString()),
    hari: json['hari'].toString(),
    jamMulai: json['jam_mulai'].toString().substring(0, 5),
    jamSelesai: json['jam_selesai'].toString().substring(0, 5),
    unit: json['unit'].toString(),
    kelas: json['kelas'].toString(),
    mataPelajaran: json['mata_pelajaran'].toString(),
  );

  Map<String, dynamic> toJson() => {
    if (idJadwal != null) 'id_jadwal': idJadwal,
    'id_pengguna': idPengguna,
    'hari': hari,
    'jam_mulai': jamMulai,
    'jam_selesai': jamSelesai,
    'unit': unit,
    'kelas': kelas,
    'mata_pelajaran': mataPelajaran,
  };
}

/// Tanggal libur (dari tabel hari_libur).
class HariLibur {
  const HariLibur({required this.tanggal, required this.keterangan});

  final DateTime tanggal;
  final String keterangan;

  factory HariLibur.fromJson(Map<String, dynamic> json) => HariLibur(
    tanggal: DateTime.parse(json['tanggal'].toString()),
    keterangan: json['keterangan'].toString(),
  );
}

/// Ringkasan data guru untuk halaman admin.
class GuruRingkas {
  const GuruRingkas({
    required this.idPengguna,
    required this.nomorInduk,
    required this.namaTampil,
    required this.jabatan,
    required this.status,
    required this.jumlahJadwal,
    this.unit,
  });

  final int idPengguna;
  final String nomorInduk;

  /// Nama beserta gelar, mis. "Siti Rahmawati, S.Pd."
  final String namaTampil;
  final String? unit;
  final String jabatan;
  final String status;
  final int jumlahJadwal;

  bool get aktif => status == 'aktif';

  factory GuruRingkas.fromJson(Map<String, dynamic> json) => GuruRingkas(
    idPengguna: int.parse(json['id_pengguna'].toString()),
    nomorInduk: json['nomor_induk'].toString(),
    namaTampil: json['nama_tampil'].toString(),
    unit: json['unit']?.toString(),
    jabatan: json['jabatan']?.toString() ?? 'Guru',
    status: json['status']?.toString() ?? 'aktif',
    jumlahJadwal: int.parse((json['jumlah_jadwal'] ?? 0).toString()),
  );
}
