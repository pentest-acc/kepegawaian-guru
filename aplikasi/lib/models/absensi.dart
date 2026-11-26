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

/// Keadaan mapel jika guru sedang [cuti] (jenis cuti/izin/sakit yang sudah
/// disetujui admin): mapel yang belum diabsen dianggap cuti/izin/sakit.
KeadaanMapel keadaanMapelDenganCuti(
  MapelAbsen mapel,
  String? cuti, {
  required HariRelatif hari,
  int menitSekarang = 0,
  int bukaAbsenMenit = 0,
}) {
  if (mapel.absensi == null && cuti != null) {
    switch (cuti) {
      case 'izin':
        return KeadaanMapel.izin;
      case 'sakit':
        return KeadaanMapel.sakit;
      default:
        return KeadaanMapel.cuti;
    }
  }
  return keadaanMapel(
    mapel,
    hari: hari,
    menitSekarang: menitSekarang,
    bukaAbsenMenit: bukaAbsenMenit,
  );
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
    this.cuti,
    this.lokasiAbsen = const [],
    this.mapel = const [],
  });

  final DateTime tanggal;
  final String hari;

  /// Jenis cuti/izin/sakit yang disetujui admin untuk hari ini (guru tidak
  /// perlu absen), atau null.

  /// Jam server saat data diambil. Dipakai agar jam di aplikasi mengikuti
  /// jam server, bukan jam HP.
  final DateTime waktuServer;

  final String? cuti;

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
        cuti: cuti,
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
        cuti: json['cuti'] as String?,
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
    this.cuti,
  });

  final int idPengguna;
  final String namaTampil;
  final String nomorInduk;
  final String? unit;

  /// Jenis cuti/izin/sakit yang disetujui untuk tanggal itu, atau null.
  final String? cuti;
  final List<MapelAbsen> mapel;

  factory KehadiranGuru.fromJson(Map<String, dynamic> json) => KehadiranGuru(
    idPengguna: json['id_pengguna'] as int,
    namaTampil: json['nama_tampil'] as String,
    nomorInduk: json['nomor_induk'] as String,
    unit: json['unit'] as String?,
    cuti: json['cuti'] as String?,
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
    this.kuotaCutiTahunan = 12,
    this.jumlahLokasi = 0,
    this.alamatYayasan,
  });

  final int toleransiTerlambat;
  final int bukaAbsenMenit;

  /// Jatah cuti per tahun (hari kerja). Izin & sakit tidak memotong kuota.
  final int kuotaCutiTahunan;

  /// Jumlah lokasi absen yang aktif.
  final int jumlahLokasi;
  final String? alamatYayasan;

  factory PengaturanAbsen.fromJson(Map<String, dynamic> json) =>
      PengaturanAbsen(
        toleransiTerlambat: json['toleransi_terlambat'] as int,
        bukaAbsenMenit: json['buka_absen_menit'] as int? ?? 30,
        kuotaCutiTahunan: json['kuota_cuti_tahunan'] as int? ?? 12,
        jumlahLokasi: json['jumlah_lokasi'] as int? ?? 0,
        alamatYayasan: json['alamat_yayasan'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'toleransi_terlambat': toleransiTerlambat,
    'buka_absen_menit': bukaAbsenMenit,
    'kuota_cuti_tahunan': kuotaCutiTahunan,
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

// ============================== Riwayat Absen ==============================

/// Posisi [tanggal] terhadap [hariIni] (jam diabaikan).
HariRelatif hariRelatif(DateTime tanggal, DateTime hariIni) {
  final a = DateTime(tanggal.year, tanggal.month, tanggal.day);
  final b = DateTime(hariIni.year, hariIni.month, hariIni.day);
  if (a.isBefore(b)) return HariRelatif.lalu;
  return a.isAfter(b) ? HariRelatif.depan : HariRelatif.ini;
}

/// Satu tanggal di kalender Riwayat Absen.
class HariRiwayat {
  const HariRiwayat({
    required this.tanggal,
    required this.hari,
    this.libur,
    this.cuti,
    this.mapel = const [],
  });

  final DateTime tanggal;

  /// "Senin", ..., "Minggu"
  final String hari;

  /// Keterangan libur ("Hari Minggu", "Hari Raya Natal"), null jika bukan.
  final String? libur;

  /// cuti / izin / sakit yang sudah disetujui admin pada tanggal ini.
  final String? cuti;

  /// Mapel hari itu beserta absensinya (urut jam mulai).
  final List<MapelAbsen> mapel;

  factory HariRiwayat.fromJson(Map<String, dynamic> json) => HariRiwayat(
    tanggal: DateTime.parse(json['tanggal'] as String),
    hari: json['hari'] as String,
    libur: json['libur'] as String?,
    cuti: json['cuti'] as String?,
    mapel: [
      for (final m in json['mapel'] as List? ?? const [])
        MapelAbsen.fromJson(m as Map<String, dynamic>),
    ],
  );
}

/// Riwayat absen satu bulan (dari `absen/riwayat.php`).
class RiwayatBulan {
  const RiwayatBulan({
    required this.bulan,
    required this.hariIni,
    required this.waktuServer,
    required this.mulai,
    required this.hari,
    this.toleransiMenit = 0,
  });

  /// Tanggal 1 bulan ini.
  final DateTime bulan;

  /// Tanggal hari ini menurut server.
  final DateTime hariIni;
  final DateTime waktuServer;

  /// Tanggal awal riwayat guru (akun dibuat / absen pertama).
  final DateTime mulai;
  final int toleransiMenit;

  /// Setiap tanggal dalam bulan ini (tanggal 1 sampai akhir bulan).
  final List<HariRiwayat> hari;

  /// Jam server (menit sejak 00:00).
  int get menitSekarang => waktuServer.hour * 60 + waktuServer.minute;

  HariRiwayat? padaTanggal(DateTime tanggal) {
    for (final h in hari) {
      if (h.tanggal.year == tanggal.year &&
          h.tanggal.month == tanggal.month &&
          h.tanggal.day == tanggal.day) {
        return h;
      }
    }
    return null;
  }

  factory RiwayatBulan.fromJson(Map<String, dynamic> json) {
    final bagian = (json['bulan'] as String).split('-');
    return RiwayatBulan(
      bulan: DateTime(int.parse(bagian[0]), int.parse(bagian[1])),
      hariIni: DateTime.parse(json['hari_ini'] as String),
      waktuServer: DateTime.parse(json['waktu_server'] as String),
      mulai: DateTime.parse(json['mulai'] as String),
      toleransiMenit: json['toleransi_menit'] as int? ?? 0,
      hari: [
        for (final h in json['hari'] as List)
          HariRiwayat.fromJson(h as Map<String, dynamic>),
      ],
    );
  }
}

/// Warna sebuah tanggal di kalender Riwayat Absen.
enum KeadaanHari {
  /// Tidak ada jadwal mengajar.
  kosong,

  /// Hari Minggu / hari libur.
  libur,

  /// Hari ini atau hari mendatang yang mapelnya belum selesai semua.
  menunggu,

  /// Semua mapel diabsen (termasuk yang terlambat). Hijau.
  hadir,

  /// Sebagian mapel tidak diabsen. Kuning.
  sebagian,

  /// Izin / sakit / cuti. Merah.
  izinSakitCuti,

  /// Tidak ada satu pun mapel yang diabsen (atau alpa). Abu-abu.
  tidakHadir,
}

/// Keadaan sebuah mapel di Riwayat Absen. Mapel tanpa absensi pada hari
/// cuti/izin/sakit yang disetujui dianggap cuti/izin/sakit.
KeadaanMapel keadaanMapelRiwayat(
  HariRiwayat hari,
  MapelAbsen mapel, {
  required DateTime hariIni,
  int menitSekarang = 0,
}) {
  return keadaanMapelDenganCuti(
    mapel,
    hari.cuti,
    hari: hariRelatif(hari.tanggal, hariIni),
    menitSekarang: menitSekarang,
  );
}

bool _mapelHadir(KeadaanMapel k) =>
    k == KeadaanMapel.hadir ||
    k == KeadaanMapel.terlambat ||
    k == KeadaanMapel.lewatJam;

bool _mapelIzin(KeadaanMapel k) =>
    k == KeadaanMapel.izin || k == KeadaanMapel.sakit || k == KeadaanMapel.cuti;

bool _mapelTidakHadir(KeadaanMapel k) =>
    k == KeadaanMapel.terlewat || k == KeadaanMapel.alpa;

/// Menentukan warna sebuah tanggal di kalender Riwayat Absen.
KeadaanHari keadaanHari(
  HariRiwayat hari, {
  required DateTime hariIni,
  int menitSekarang = 0,
}) {
  if (hari.mapel.isEmpty) {
    return hari.libur != null ? KeadaanHari.libur : KeadaanHari.kosong;
  }
  var hadir = 0, izin = 0, tidakHadir = 0, menunggu = 0;
  for (final m in hari.mapel) {
    final k = keadaanMapelRiwayat(
      hari,
      m,
      hariIni: hariIni,
      menitSekarang: menitSekarang,
    );
    if (_mapelHadir(k)) {
      hadir++;
    } else if (_mapelIzin(k)) {
      izin++;
    } else if (_mapelTidakHadir(k)) {
      tidakHadir++;
    } else {
      menunggu++;
    }
  }
  if (izin > 0) return KeadaanHari.izinSakitCuti;
  if (tidakHadir == 0) {
    return menunggu == 0 ? KeadaanHari.hadir : KeadaanHari.menunggu;
  }
  return hadir > 0 ? KeadaanHari.sebagian : KeadaanHari.tidakHadir;
}

/// Rekap kehadiran satu bulan (hanya sampai hari ini).
class RekapRiwayat {
  const RekapRiwayat({
    this.hariHadir = 0,
    this.hariSebagian = 0,
    this.hariIzin = 0,
    this.hariTidakHadir = 0,
    this.mapelSelesai = 0,
    this.mapelDiabsen = 0,
    this.kaliTerlambat = 0,
    this.mapelTidakDiabsen = 0,
    this.menitMengajar = 0,
  });

  /// Jumlah hari berwarna hijau / kuning / merah / abu-abu.
  final int hariHadir;
  final int hariSebagian;
  final int hariIzin;
  final int hariTidakHadir;

  /// Mapel yang wajib diabsen sampai saat ini: yang sudah diabsen atau
  /// sudah lewat tanpa absen (tidak termasuk izin/sakit/cuti dan mapel yang
  /// belum selesai).
  final int mapelSelesai;

  /// Mapel yang diabsen guru (hadir + terlambat).
  final int mapelDiabsen;

  /// Mapel yang diabsen terlambat (termasuk lewat jam pelajaran).
  final int kaliTerlambat;

  /// Mapel yang tidak diabsen (atau alpa).
  final int mapelTidakDiabsen;

  /// Total durasi mapel yang diabsen (menit) = jam mengajar.
  final int menitMengajar;
}

RekapRiwayat rekapRiwayat(
  List<HariRiwayat> daftarHari, {
  required DateTime hariIni,
  int menitSekarang = 0,
}) {
  var hariHadir = 0, hariSebagian = 0, hariIzin = 0, hariTidakHadir = 0;
  var selesai = 0, diabsen = 0, terlambat = 0, tidakDiabsen = 0, menit = 0;
  for (final h in daftarHari) {
    switch (keadaanHari(h, hariIni: hariIni, menitSekarang: menitSekarang)) {
      case KeadaanHari.hadir:
        hariHadir++;
      case KeadaanHari.sebagian:
        hariSebagian++;
      case KeadaanHari.izinSakitCuti:
        hariIzin++;
      case KeadaanHari.tidakHadir:
        hariTidakHadir++;
      case KeadaanHari.kosong:
      case KeadaanHari.libur:
      case KeadaanHari.menunggu:
        break;
    }
    for (final m in h.mapel) {
      final k = keadaanMapelRiwayat(
        h,
        m,
        hariIni: hariIni,
        menitSekarang: menitSekarang,
      );
      if (_mapelHadir(k)) {
        selesai++;
        diabsen++;
        menit += math.max(0, m.menitSelesai - m.menitMulai);
        if (k != KeadaanMapel.hadir) terlambat++;
      } else if (_mapelTidakHadir(k)) {
        selesai++;
        tidakDiabsen++;
      }
    }
  }
  return RekapRiwayat(
    hariHadir: hariHadir,
    hariSebagian: hariSebagian,
    hariIzin: hariIzin,
    hariTidakHadir: hariTidakHadir,
    mapelSelesai: selesai,
    mapelDiabsen: diabsen,
    kaliTerlambat: terlambat,
    mapelTidakDiabsen: tidakDiabsen,
    menitMengajar: menit,
  );
}

/// 750 -> "12 jam 30 menit", 45 -> "45 menit", 120 -> "2 jam".
String formatDurasi(int menit) {
  final jam = menit ~/ 60;
  final sisa = menit % 60;
  if (jam == 0) return '$sisa menit';
  return sisa == 0 ? '$jam jam' : '$jam jam $sisa menit';
}
