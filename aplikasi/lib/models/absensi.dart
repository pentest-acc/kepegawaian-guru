import 'dart:math' as math;

/// Mengubah "07:30" menjadi menit sejak 00:00 (450).
int menitDariJam(String jam) {
  final bagian = jam.split(':');
  return int.parse(bagian[0]) * 60 + int.parse(bagian[1]);
}

/// "07:30" -> "07.30"
String jamTitik(String jam) => jam.replaceAll(':', '.');

/// Absen guru untuk SATU mata pelajaran pada satu tanggal.
class AbsensiMapel {
  const AbsensiMapel({
    required this.idAbsensi,
    required this.tanggal,
    required this.mataPelajaran,
    required this.jamMulai,
    required this.jamSelesai,
    required this.status,
    this.idJadwal,
    this.unit = '',
    this.kelas = '',
    this.jamAbsen,
    this.menitTerlambat = 0,
    this.lewatJam = false,
    this.lokasi,
    this.jarak,
    this.adaFoto = false,
    this.keterangan,
    this.diubahAdmin = false,
  });

  final int idAbsensi;
  final int? idJadwal;
  final DateTime tanggal;
  final String mataPelajaran;
  final String unit;
  final String kelas;
  final String jamMulai;
  final String jamSelesai;

  /// Jam server saat guru absen ("HH:MM"). null jika ditandai admin.
  final String? jamAbsen;

  /// hadir, terlambat, izin, sakit, cuti, alpa
  final String status;
  final int menitTerlambat;

  /// true jika guru absen setelah jam pelajaran selesai.
  final bool lewatJam;

  /// Nama lokasi absen terdekat saat absen, mis. "Gedung SD".
  final String? lokasi;
  final int? jarak;
  final bool adaFoto;
  final String? keterangan;

  /// true jika kehadiran ditandai/diubah admin.
  final bool diubahAdmin;

  factory AbsensiMapel.fromJson(Map<String, dynamic> json) => AbsensiMapel(
    idAbsensi: json['id_absensi'] as int,
    idJadwal: json['id_jadwal'] as int?,
    tanggal: DateTime.parse(json['tanggal'] as String),
    mataPelajaran: json['mata_pelajaran'] as String,
    unit: json['unit'] as String? ?? '',
    kelas: json['kelas'] as String? ?? '',
    jamMulai: json['jam_mulai'] as String,
    jamSelesai: json['jam_selesai'] as String,
    jamAbsen: json['jam_absen'] as String?,
    status: json['status'] as String,
    menitTerlambat: json['menit_terlambat'] as int? ?? 0,
    lewatJam: json['lewat_jam'] as bool? ?? false,
    lokasi: json['lokasi'] as String?,
    jarak: json['jarak'] as int?,
    adaFoto: json['ada_foto'] as bool? ?? false,
    keterangan: json['keterangan'] as String?,
    diubahAdmin: json['diubah_admin'] as bool? ?? false,
  );
}

/// Satu mata pelajaran (jadwal) guru pada satu hari beserta absensinya.
/// Setiap mapel = satu kali absen.
class MapelAbsen {
  const MapelAbsen({
    required this.mataPelajaran,
    required this.unit,
    required this.kelas,
    required this.jamMulai,
    required this.jamSelesai,
    this.idJadwal,
    this.idLokasi,
    this.lokasi,
    this.absensi,
  });

  /// null jika jadwalnya sudah dihapus (hanya tersisa absensinya).
  final int? idJadwal;
  final String mataPelajaran;
  final String unit;
  final String kelas;

  /// Format "HH:MM"
  final String jamMulai;
  final String jamSelesai;

  /// Gedung tempat mengajar yang diatur admin di jadwal.
  final int? idLokasi;
  final String? lokasi;

  /// null = belum absen.
  final AbsensiMapel? absensi;

  int get menitMulai => menitDariJam(jamMulai);
  int get menitSelesai => menitDariJam(jamSelesai);

  /// "07.30 - 09.00"
  String get jamTampil => '${jamTitik(jamMulai)} - ${jamTitik(jamSelesai)}';

  MapelAbsen denganAbsensi(AbsensiMapel? baru) => MapelAbsen(
    idJadwal: idJadwal,
    mataPelajaran: mataPelajaran,
    unit: unit,
    kelas: kelas,
    jamMulai: jamMulai,
    jamSelesai: jamSelesai,
    idLokasi: idLokasi,
    lokasi: lokasi,
    absensi: baru,
  );

  factory MapelAbsen.fromJson(Map<String, dynamic> json) => MapelAbsen(
    idJadwal: json['id_jadwal'] as int?,
    mataPelajaran: json['mata_pelajaran'] as String,
    unit: json['unit'] as String,
    kelas: json['kelas'] as String,
    jamMulai: json['jam_mulai'] as String,
    jamSelesai: json['jam_selesai'] as String,
    idLokasi: json['id_lokasi'] as int?,
    lokasi: json['lokasi'] as String?,
    absensi: json['absensi'] == null
        ? null
        : AbsensiMapel.fromJson(json['absensi'] as Map<String, dynamic>),
  );
}

/// Posisi sebuah hari terhadap hari ini.
enum HariRelatif { lalu, ini, depan }

/// Keadaan kehadiran sebuah mapel (dipakai untuk label & warna).
enum KeadaanMapel {
  /// Hari ini, absen belum dibuka (masih lama sebelum jam mulai).
  belumDibuka,

  /// Belum absen, mapel belum selesai (atau hari mendatang).
  belumAbsen,

  /// Belum absen padahal mapel sudah selesai.
  terlewat,
  hadir,
  terlambat,

  /// Terlambat dan absen setelah jam pelajaran selesai.
  lewatJam,
  izin,
  sakit,
  cuti,
  alpa,
}

/// Menentukan keadaan kehadiran sebuah mapel.
///
/// [menitSekarang] = jam server saat ini (menit sejak 00:00), dipakai jika
/// [hari] adalah hari ini.
KeadaanMapel keadaanMapel(
  MapelAbsen mapel, {
  required HariRelatif hari,
  int menitSekarang = 0,
  int bukaAbsenMenit = 0,
}) {
  final absensi = mapel.absensi;
  if (absensi != null) {
    switch (absensi.status) {
      case 'izin':
        return KeadaanMapel.izin;
      case 'sakit':
        return KeadaanMapel.sakit;
      case 'cuti':
        return KeadaanMapel.cuti;
      case 'alpa':
        return KeadaanMapel.alpa;
      case 'terlambat':
        return absensi.lewatJam
            ? KeadaanMapel.lewatJam
            : KeadaanMapel.terlambat;
      default:
        return KeadaanMapel.hadir;
    }
  }
  switch (hari) {
    case HariRelatif.lalu:
      return KeadaanMapel.terlewat;
    case HariRelatif.depan:
      return KeadaanMapel.belumAbsen;
    case HariRelatif.ini:
      if (menitSekarang < mapel.menitMulai - bukaAbsenMenit) {
        return KeadaanMapel.belumDibuka;
      }
      return menitSekarang >= mapel.menitSelesai
          ? KeadaanMapel.terlewat
          : KeadaanMapel.belumAbsen;
  }
}

/// Satu titik lokasi absen (mis. salah satu gedung Yayasan) beserta
/// radiusnya. Admin bisa menambah banyak lokasi.
class LokasiAbsen {
  const LokasiAbsen({
    this.idLokasi,
    this.nomor = 0,
    required this.nama,
    required this.lat,
    required this.lng,
    required this.radius,
    this.aktif = true,
  });

  /// null untuk lokasi baru yang belum disimpan.
  final int? idLokasi;

  /// Nomor urut: Lokasi 1, 2, 3, ...
  final int nomor;
  final String nama;
  final double lat;
  final double lng;

  /// Meter
  final int radius;
  final bool aktif;

  /// "Lokasi 2 • Gedung SD"
  String get namaLengkap => nomor > 0 ? 'Lokasi $nomor • $nama' : nama;

  /// Jarak (meter) sebuah titik ke lokasi ini.
  int jarakDari(double lat, double lng) =>
      jarakMeter(this.lat, this.lng, lat, lng).round();

  factory LokasiAbsen.fromJson(Map<String, dynamic> json) => LokasiAbsen(
    idLokasi: json['id_lokasi'] as int?,
    nomor: json['nomor'] as int? ?? 0,
    nama: json['nama'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    radius: json['radius'] as int,
    aktif: json['aktif'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id_lokasi': ?idLokasi,
    'nama': nama,
    'lat': lat,
    'lng': lng,
    'radius': radius,
    'aktif': aktif,
  };
}

/// Jarak posisi guru ke satu lokasi absen.
class JarakLokasi {
  const JarakLokasi(this.lokasi, this.jarak);

  final LokasiAbsen lokasi;

  /// Meter
  final int jarak;

  /// true jika posisi guru di dalam radius lokasi ini.
  bool get diDalam => jarak <= lokasi.radius;
}

/// Jarak posisi guru ke setiap lokasi absen, urut dari yang terdekat.
List<JarakLokasi> urutkanLokasi(
  List<LokasiAbsen> daftar,
  double lat,
  double lng,
) =>
    [for (final l in daftar) JarakLokasi(l, l.jarakDari(lat, lng))]
      ..sort((a, b) => a.jarak.compareTo(b.jarak));

/// Lokasi yang dipakai untuk absen (sama dengan aturan server): lokasi
/// terdekat yang radiusnya mencakup posisi guru. Jika tidak ada, lokasi
/// terdekat (diDalam = false). null jika daftar lokasi kosong.
JarakLokasi? lokasiAbsenTerpilih(List<JarakLokasi> urut) {
  if (urut.isEmpty) return null;
  for (final j in urut) {
    if (j.diDalam) return j;
  }
  return urut.first;
}

/// Data halaman Absen guru untuk hari ini (dari `absen/hari_ini.php`).
class InfoAbsenHariIni {
  const InfoAbsenHariIni({
    required this.tanggal,
    required this.hari,
    required this.waktuServer,
    required this.toleransiMenit,
    required this.bukaAbsenMenit,
    this.libur,
    this.lokasiAbsen = const [],
    this.mapel = const [],
  });

  final DateTime tanggal;
  final String hari;

  /// Jam server saat data diambil. Dipakai agar jam di aplikasi mengikuti
  /// jam server, bukan jam HP.
  final DateTime waktuServer;

  /// Keterangan libur (mis. "Hari Minggu"), null jika hari sekolah.
  final String? libur;

  /// Lewat dari jam mulai mapel + toleransi = terlambat.
  final int toleransiMenit;

  /// Absen mapel dibuka sekian menit sebelum jam mulai.
  final int bukaAbsenMenit;

  /// Lokasi absen yang aktif. Kosong = jarak tidak dicek.
  final List<LokasiAbsen> lokasiAbsen;

  /// Mapel guru hari ini (urut jam mulai), masing-masing satu kali absen.
  final List<MapelAbsen> mapel;

  /// Jam masuk = jam mulai mapel pertama.
  String? get jamMasuk => mapel.isEmpty ? null : mapel.first.jamMulai;

  /// Boleh pulang setelah mapel terakhir selesai.
  String? get jamBolehPulang => mapel.isEmpty
      ? null
      : mapel
            .map((m) => m.jamSelesai)
            .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

  /// Salinan data ini dengan absensi baru untuk mapel ke-[indeks].
  InfoAbsenHariIni denganAbsensi(int indeks, AbsensiMapel absensi) =>
      InfoAbsenHariIni(
        tanggal: tanggal,
        hari: hari,
        waktuServer: waktuServer,
        toleransiMenit: toleransiMenit,
        bukaAbsenMenit: bukaAbsenMenit,
        libur: libur,
        lokasiAbsen: lokasiAbsen,
        mapel: [
          for (var i = 0; i < mapel.length; i++)
            i == indeks ? mapel[i].denganAbsensi(absensi) : mapel[i],
        ],
      );

  factory InfoAbsenHariIni.fromJson(Map<String, dynamic> json) =>
      InfoAbsenHariIni(
        tanggal: DateTime.parse(json['tanggal'] as String),
        hari: json['hari'] as String,
        waktuServer: DateTime.parse(json['waktu_server'] as String),
        libur: json['libur'] as String?,
        toleransiMenit: json['toleransi_menit'] as int? ?? 0,
        bukaAbsenMenit: json['buka_absen_menit'] as int? ?? 0,
        lokasiAbsen: [
          for (final l in json['lokasi_absen'] as List? ?? const [])
            LokasiAbsen.fromJson(l as Map<String, dynamic>),
        ],
        mapel: [
          for (final m in json['mapel'] as List? ?? const [])
            MapelAbsen.fromJson(m as Map<String, dynamic>),
        ],
      );
}

/// Kehadiran seorang guru pada satu hari (Monitoring Absensi admin).
class KehadiranGuru {
  const KehadiranGuru({
    required this.idPengguna,
    required this.namaTampil,
    required this.nomorInduk,
    required this.mapel,
    this.unit,
  });

  final int idPengguna;
  final String namaTampil;
  final String nomorInduk;
  final String? unit;
  final List<MapelAbsen> mapel;

  factory KehadiranGuru.fromJson(Map<String, dynamic> json) => KehadiranGuru(
    idPengguna: json['id_pengguna'] as int,
    namaTampil: json['nama_tampil'] as String,
    nomorInduk: json['nomor_induk'] as String,
    unit: json['unit'] as String?,
    mapel: [
      for (final m in json['mapel'] as List)
        MapelAbsen.fromJson(m as Map<String, dynamic>),
    ],
  );
}

/// Monitoring absensi satu hari (dari `admin/absensi/harian.php`).
class RekapHarian {
  const RekapHarian({
    required this.tanggal,
    required this.hari,
    required this.waktuServer,
    required this.guru,
    this.libur,
  });

  final DateTime tanggal;
  final String hari;
  final DateTime waktuServer;
  final String? libur;
  final List<KehadiranGuru> guru;

  factory RekapHarian.fromJson(Map<String, dynamic> json) => RekapHarian(
    tanggal: DateTime.parse(json['tanggal'] as String),
    hari: json['hari'] as String,
    waktuServer: DateTime.parse(json['waktu_server'] as String),
    libur: json['libur'] as String?,
    guru: [
      for (final g in json['guru'] as List)
        KehadiranGuru.fromJson(g as Map<String, dynamic>),
    ],
  );
}

/// Pengaturan absen yang diatur admin (menu Pengaturan Sistem).
/// Jam absen setiap guru mengikuti jadwal mengajarnya.
class PengaturanAbsen {
  const PengaturanAbsen({
    required this.toleransiTerlambat,
    required this.bukaAbsenMenit,
    this.jumlahLokasi = 0,
    this.alamatYayasan,
  });

  final int toleransiTerlambat;
  final int bukaAbsenMenit;

  /// Jumlah lokasi absen yang aktif.
  final int jumlahLokasi;
  final String? alamatYayasan;

  factory PengaturanAbsen.fromJson(Map<String, dynamic> json) =>
      PengaturanAbsen(
        toleransiTerlambat: json['toleransi_terlambat'] as int,
        bukaAbsenMenit: json['buka_absen_menit'] as int? ?? 30,
        jumlahLokasi: json['jumlah_lokasi'] as int? ?? 0,
        alamatYayasan: json['alamat_yayasan'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'toleransi_terlambat': toleransiTerlambat,
    'buka_absen_menit': bukaAbsenMenit,
  };
}

/// Jarak dua titik GPS dalam meter (rumus Haversine, sama dengan server).
double jarakMeter(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double derajat) => derajat * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// 350 -> "350 m", 1234 -> "1,2 km".
String formatJarak(int meter) {
  if (meter < 1000) return '$meter m';
  return '${(meter / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
