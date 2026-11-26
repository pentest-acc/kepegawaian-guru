import 'jadwal_mengajar.dart';

/// Jenis pengajuan: cuti memotong kuota tahunan, izin & sakit tidak.
enum JenisCuti {
  cuti('cuti', 'Cuti', 'Memotong kuota cuti tahunan. Diajukan sebelum hari H.'),
  izin(
    'izin',
    'Izin',
    'Keperluan mendesak. Tidak memotong kuota, boleh diajukan menyusul '
        'paling lambat 7 hari.',
  ),
  sakit(
    'sakit',
    'Sakit',
    'Tidak memotong kuota. Sakit 2 hari atau lebih wajib foto surat dokter.',
  );

  const JenisCuti(this.kode, this.label, this.keterangan);

  /// Nilai yang dikirim ke server: cuti, izin, sakit.
  final String kode;
  final String label;
  final String keterangan;

  static JenisCuti dari(String kode) => JenisCuti.values.firstWhere(
    (j) => j.kode == kode,
    orElse: () => JenisCuti.izin,
  );
}

enum StatusCuti {
  menunggu('menunggu', 'Menunggu'),
  disetujui('disetujui', 'Disetujui'),
  ditolak('ditolak', 'Ditolak');

  const StatusCuti(this.kode, this.label);

  final String kode;
  final String label;

  static StatusCuti dari(String kode) => StatusCuti.values.firstWhere(
    (s) => s.kode == kode,
    orElse: () => StatusCuti.menunggu,
  );
}

DateTime? _tanggalAtauNull(Object? teks) =>
    teks == null ? null : DateTime.parse(teks.toString());

/// Satu pengajuan cuti / izin / sakit.
class PengajuanCuti {
  const PengajuanCuti({
    required this.idCuti,
    required this.idPengguna,
    required this.jenis,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.jumlahHari,
    required this.alasan,
    required this.status,
    required this.dibuatPada,
    this.adaLampiran = false,
    this.catatanAdmin,
    this.diprosesOleh,
    this.diprosesPada,
    this.guru,
    this.jumlahMapel,
  });

  final int idCuti;
  final int idPengguna;
  final JenisCuti jenis;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;

  /// Hari kerja (Minggu & hari libur tidak dihitung).
  final int jumlahHari;
  final String alasan;
  final bool adaLampiran;
  final StatusCuti status;
  final String? catatanAdmin;

  /// Nama admin yang menyetujui / menolak.
  final String? diprosesOleh;
  final DateTime? diprosesPada;
  final DateTime dibuatPada;

  /// Data guru (untuk admin).
  final GuruRingkas? guru;

  /// Jumlah mapel yang ditinggalkan (untuk admin).
  final int? jumlahMapel;

  bool get satuHari =>
      tanggalMulai.year == tanggalSelesai.year &&
      tanggalMulai.month == tanggalSelesai.month &&
      tanggalMulai.day == tanggalSelesai.day;

  /// Guru hanya bisa membatalkan pengajuan yang belum diproses.
  bool get bisaDibatalkan => status == StatusCuti.menunggu;

  factory PengajuanCuti.fromJson(Map<String, dynamic> json) => PengajuanCuti(
    idCuti: json['id_cuti'] as int,
    idPengguna: json['id_pengguna'] as int,
    jenis: JenisCuti.dari(json['jenis'] as String),
    tanggalMulai: DateTime.parse(json['tanggal_mulai'] as String),
    tanggalSelesai: DateTime.parse(json['tanggal_selesai'] as String),
    jumlahHari: json['jumlah_hari'] as int,
    alasan: json['alasan'] as String,
    adaLampiran: json['ada_lampiran'] as bool? ?? false,
    status: StatusCuti.dari(json['status'] as String),
    catatanAdmin: json['catatan_admin'] as String?,
    diprosesOleh: json['diproses_oleh'] as String?,
    diprosesPada: _tanggalAtauNull(json['diproses_pada']),
    dibuatPada: DateTime.parse(json['dibuat_pada'] as String),
    guru: json['guru'] == null
        ? null
        : GuruRingkas.fromJson(json['guru'] as Map<String, dynamic>),
    jumlahMapel: json['jumlah_mapel'] as int?,
  );
}

/// Kuota cuti seorang guru dalam satu tahun kalender.
class KuotaCuti {
  const KuotaCuti({
    required this.tahun,
    required this.kuota,
    required this.terpakai,
    required this.diajukan,
    required this.sisa,
  });

  final int tahun;

  /// Jatah cuti per tahun (hari kerja).
  final int kuota;

  /// Cuti yang sudah disetujui.
  final int terpakai;

  /// Cuti yang masih menunggu persetujuan.
  final int diajukan;

  /// Yang masih bisa diajukan = kuota - terpakai - diajukan.
  final int sisa;

  factory KuotaCuti.fromJson(Map<String, dynamic> json) => KuotaCuti(
    tahun: json['tahun'] as int,
    kuota: json['kuota'] as int,
    terpakai: json['terpakai'] as int,
    diajukan: json['diajukan'] as int,
    sisa: json['sisa'] as int,
  );
}

/// Satu hari kerja selama cuti beserta mapel yang ditinggalkan.
class HariCuti {
  const HariCuti({
    required this.tanggal,
    required this.hari,
    this.mapel = const [],
  });

  final DateTime tanggal;
  final String hari;
  final List<JadwalMengajar> mapel;

  factory HariCuti.fromJson(Map<String, dynamic> json) => HariCuti(
    tanggal: DateTime.parse(json['tanggal'] as String),
    hari: json['hari'] as String,
    mapel: [
      for (final m in json['mapel'] as List? ?? const [])
        JadwalMengajar.fromJson(m as Map<String, dynamic>),
    ],
  );
}

List<HariCuti> _daftarHari(Object? json) => [
  for (final h in json as List? ?? const [])
    HariCuti.fromJson(h as Map<String, dynamic>),
];

/// Pratinjau sebelum mengajukan (dari `cuti/hitung.php`).
class PratinjauCuti {
  const PratinjauCuti({
    required this.jenis,
    required this.jumlahHari,
    required this.jumlahMapel,
    required this.hari,
    this.kuota,
    this.wajibLampiran = false,
  });

  final JenisCuti jenis;
  final int jumlahHari;
  final int jumlahMapel;
  final List<HariCuti> hari;

  /// Hanya untuk jenis cuti.
  final KuotaCuti? kuota;

  /// true jika sakit 2 hari atau lebih (wajib foto surat dokter).
  final bool wajibLampiran;

  /// Sisa kuota jika pengajuan cuti ini disetujui.
  int? get sisaSetelahCuti => kuota == null ? null : kuota!.sisa - jumlahHari;

  factory PratinjauCuti.fromJson(Map<String, dynamic> json) => PratinjauCuti(
    jenis: JenisCuti.dari(json['jenis'] as String),
    jumlahHari: json['jumlah_hari'] as int,
    jumlahMapel: json['jumlah_mapel'] as int? ?? 0,
    hari: _daftarHari(json['hari']),
    kuota: json['kuota'] == null
        ? null
        : KuotaCuti.fromJson(json['kuota'] as Map<String, dynamic>),
    wajibLampiran: json['wajib_lampiran'] as bool? ?? false,
  );
}

/// Halaman Cuti / Izin guru (dari `cuti/saya.php`).
class DataCutiSaya {
  const DataCutiSaya({
    required this.hariIni,
    required this.kuota,
    required this.pengajuan,
  });

  final DateTime hariIni;
  final KuotaCuti kuota;
  final List<PengajuanCuti> pengajuan;

  factory DataCutiSaya.fromJson(Map<String, dynamic> json) => DataCutiSaya(
    hariIni: DateTime.parse(json['hari_ini'] as String),
    kuota: KuotaCuti.fromJson(json['kuota'] as Map<String, dynamic>),
    pengajuan: [
      for (final c in json['pengajuan'] as List)
        PengajuanCuti.fromJson(c as Map<String, dynamic>),
    ],
  );
}

/// Persetujuan Cuti admin (dari `admin/cuti/daftar.php`).
class DaftarCutiAdmin {
  const DaftarCutiAdmin({
    required this.jumlahMenunggu,
    required this.pengajuan,
  });

  final int jumlahMenunggu;
  final List<PengajuanCuti> pengajuan;

  factory DaftarCutiAdmin.fromJson(Map<String, dynamic> json) =>
      DaftarCutiAdmin(
        jumlahMenunggu: json['jumlah_menunggu'] as int,
        pengajuan: [
          for (final c in json['pengajuan'] as List)
            PengajuanCuti.fromJson(c as Map<String, dynamic>),
        ],
      );
}

/// Detail pengajuan untuk admin (dari `admin/cuti/detail.php`).
class DetailCutiAdmin {
  const DetailCutiAdmin({
    required this.cuti,
    required this.hari,
    required this.jumlahMapel,
    required this.kuota,
    this.bertumpuk,
  });

  final PengajuanCuti cuti;
  final List<HariCuti> hari;
  final int jumlahMapel;

  /// Kuota guru pada tahun pengajuan, tanpa menghitung pengajuan ini.
  final KuotaCuti kuota;

  /// Keterangan pengajuan lain yang sudah disetujui & tanggalnya bertumpuk.
  final String? bertumpuk;

  factory DetailCutiAdmin.fromJson(Map<String, dynamic> json) {
    final tumpuk = json['bertumpuk'] as Map<String, dynamic>?;
    return DetailCutiAdmin(
      cuti: PengajuanCuti.fromJson(json['cuti'] as Map<String, dynamic>),
      hari: _daftarHari(json['hari']),
      jumlahMapel: json['jumlah_mapel'] as int? ?? 0,
      kuota: KuotaCuti.fromJson(json['kuota'] as Map<String, dynamic>),
      bertumpuk: tumpuk == null
          ? null
          : '${JenisCuti.dari(tumpuk['jenis'] as String).label} '
                '${tumpuk['tanggal_mulai']} s.d. ${tumpuk['tanggal_selesai']}',
    );
  }
}
