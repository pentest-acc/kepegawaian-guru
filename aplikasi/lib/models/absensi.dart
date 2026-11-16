import 'dart:math' as math;

/// Absensi seorang guru pada satu tanggal (absen masuk & pulang).
class Absensi {
  const Absensi({
    required this.idAbsensi,
    required this.tanggal,
    required this.status,
    this.jamMasuk,
    this.jamPulang,
    this.menitTerlambat = 0,
    this.menitPulangAwal = 0,
    this.lokasiMasuk,
    this.jarakMasuk,
    this.lokasiPulang,
    this.jarakPulang,
    this.adaFotoMasuk = false,
    this.adaFotoPulang = false,
    this.keterangan,
  });

  final int idAbsensi;
  final DateTime tanggal;

  /// Format "HH:MM" (jam server), null jika belum absen.
  final String? jamMasuk;
  final String? jamPulang;

  /// hadir, terlambat, izin, sakit, cuti, alpa
  final String status;
  final int menitTerlambat;
  final int menitPulangAwal;

  /// Nama lokasi absen terdekat saat absen, mis. "Gedung SD"
  /// (null jika admin belum menambahkan lokasi absen).
  final String? lokasiMasuk;
  final String? lokasiPulang;

  /// Jarak ke lokasi absen terdekat (meter).
  final int? jarakMasuk;
  final int? jarakPulang;
  final bool adaFotoMasuk;
  final bool adaFotoPulang;
  final String? keterangan;

  bool get sudahMasuk => jamMasuk != null;
  bool get sudahPulang => jamPulang != null;
  bool get terlambat => status == 'terlambat';

  /// Izin, sakit, dan cuti tidak perlu absen.
  bool get tanpaAbsen => const ['izin', 'sakit', 'cuti'].contains(status);

  factory Absensi.fromJson(Map<String, dynamic> json) => Absensi(
    idAbsensi: json['id_absensi'] as int,
    tanggal: DateTime.parse(json['tanggal'] as String),
    jamMasuk: json['jam_masuk'] as String?,
    jamPulang: json['jam_pulang'] as String?,
    status: json['status'] as String,
    menitTerlambat: json['menit_terlambat'] as int? ?? 0,
    menitPulangAwal: json['menit_pulang_awal'] as int? ?? 0,
    lokasiMasuk: json['lokasi_masuk'] as String?,
    jarakMasuk: json['jarak_masuk'] as int?,
    lokasiPulang: json['lokasi_pulang'] as String?,
    jarakPulang: json['jarak_pulang'] as int?,
    adaFotoMasuk: json['ada_foto_masuk'] as bool? ?? false,
    adaFotoPulang: json['ada_foto_pulang'] as bool? ?? false,
    keterangan: json['keterangan'] as String?,
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

/// Jam masuk & pulang untuk satu unit (KB/TK/SD).
class JamKerja {
  const JamKerja({
    required this.unit,
    required this.jamMasuk,
    required this.jamPulang,
  });

  final String unit;

  /// Format "HH:MM"
  final String jamMasuk;
  final String jamPulang;

  factory JamKerja.fromJson(Map<String, dynamic> json) => JamKerja(
    unit: json['unit'] as String,
    jamMasuk: json['jam_masuk'] as String,
    jamPulang: json['jam_pulang'] as String,
  );

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'jam_masuk': jamMasuk,
    'jam_pulang': jamPulang,
  };

  JamKerja salin({String? jamMasuk, String? jamPulang}) => JamKerja(
    unit: unit,
    jamMasuk: jamMasuk ?? this.jamMasuk,
    jamPulang: jamPulang ?? this.jamPulang,
  );
}

/// Data halaman Absen untuk hari ini (dari `absen/hari_ini.php`).
class InfoAbsenHariIni {
  const InfoAbsenHariIni({
    required this.tanggal,
    required this.hari,
    required this.waktuServer,
    required this.jamKerja,
    required this.toleransiMenit,
    required this.absenMasukMulai,
    required this.absenPulangMulai,
    this.libur,
    this.lokasiAbsen = const [],
    this.absensi,
  });

  final DateTime tanggal;
  final String hari;

  /// Jam server saat data diambil. Dipakai agar jam di aplikasi mengikuti
  /// jam server, bukan jam HP.
  final DateTime waktuServer;

  /// Keterangan libur (mis. "Hari Minggu"), null jika hari sekolah.
  final String? libur;
  final JamKerja jamKerja;
  final int toleransiMenit;

  /// Format "HH:MM"
  final String absenMasukMulai;

  /// Tombol absen pulang muncul mulai jam ini (jam pulang paling awal).
  final String absenPulangMulai;

  /// Lokasi absen yang aktif. Kosong = admin belum menambahkan lokasi,
  /// jadi jarak tidak dicek.
  final List<LokasiAbsen> lokasiAbsen;

  /// null jika guru belum absen hari ini.
  final Absensi? absensi;

  /// Salinan data ini dengan absensi terbaru (setelah absen berhasil).
  InfoAbsenHariIni denganAbsensi(Absensi absensiBaru) => InfoAbsenHariIni(
    tanggal: tanggal,
    hari: hari,
    waktuServer: waktuServer,
    jamKerja: jamKerja,
    toleransiMenit: toleransiMenit,
    absenMasukMulai: absenMasukMulai,
    absenPulangMulai: absenPulangMulai,
    libur: libur,
    lokasiAbsen: lokasiAbsen,
    absensi: absensiBaru,
  );

  factory InfoAbsenHariIni.fromJson(Map<String, dynamic> json) {
    final jamKerja = json['jam_kerja'] as Map<String, dynamic>;
    return InfoAbsenHariIni(
      tanggal: DateTime.parse(json['tanggal'] as String),
      hari: json['hari'] as String,
      waktuServer: DateTime.parse(json['waktu_server'] as String),
      libur: json['libur'] as String?,
      jamKerja: JamKerja.fromJson(jamKerja),
      toleransiMenit: jamKerja['toleransi_menit'] as int? ?? 0,
      absenMasukMulai: json['absen_masuk_mulai'] as String,
      absenPulangMulai: json['absen_pulang_mulai'] as String,
      lokasiAbsen: [
        for (final l in json['lokasi_absen'] as List? ?? const [])
          LokasiAbsen.fromJson(l as Map<String, dynamic>),
      ],
      absensi: json['absensi'] == null
          ? null
          : Absensi.fromJson(json['absensi'] as Map<String, dynamic>),
    );
  }
}

/// Pengaturan absen yang diatur admin (menu Pengaturan Sistem).
/// Lokasi absen diatur terpisah (menu Lokasi Absen).
class PengaturanAbsen {
  const PengaturanAbsen({
    required this.toleransiTerlambat,
    required this.jamKerja,
    this.jumlahLokasi = 0,
    this.alamatYayasan,
  });

  final int toleransiTerlambat;
  final List<JamKerja> jamKerja;

  /// Jumlah lokasi absen yang aktif.
  final int jumlahLokasi;
  final String? alamatYayasan;

  factory PengaturanAbsen.fromJson(Map<String, dynamic> json) =>
      PengaturanAbsen(
        toleransiTerlambat: json['toleransi_terlambat'] as int,
        jumlahLokasi: json['jumlah_lokasi'] as int? ?? 0,
        alamatYayasan: json['alamat_yayasan'] as String?,
        jamKerja: (json['jam_kerja'] as List)
            .map((e) => JamKerja.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'toleransi_terlambat': toleransiTerlambat,
    'jam_kerja': jamKerja.map((j) => j.toJson()).toList(),
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
