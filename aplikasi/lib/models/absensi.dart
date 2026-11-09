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
    this.jarakMasuk,
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

  /// Jarak dari titik lokasi sekolah (meter), null jika lokasi belum diatur.
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
    jarakMasuk: json['jarak_masuk'] as int?,
    jarakPulang: json['jarak_pulang'] as int?,
    adaFotoMasuk: json['ada_foto_masuk'] as bool? ?? false,
    adaFotoPulang: json['ada_foto_pulang'] as bool? ?? false,
    keterangan: json['keterangan'] as String?,
  );
}

/// Titik lokasi sekolah dan radius absen yang diatur admin.
class LokasiSekolah {
  const LokasiSekolah({
    required this.lat,
    required this.lng,
    required this.radius,
  });

  final double lat;
  final double lng;

  /// Meter
  final int radius;

  /// Jarak (meter) sebuah titik ke lokasi sekolah.
  int jarakDari(double lat, double lng) =>
      jarakMeter(this.lat, this.lng, lat, lng).round();

  factory LokasiSekolah.fromJson(Map<String, dynamic> json) => LokasiSekolah(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    radius: json['radius'] as int,
  );
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
    this.lokasiSekolah,
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

  /// null jika admin belum mengatur titik lokasi sekolah.
  final LokasiSekolah? lokasiSekolah;

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
    lokasiSekolah: lokasiSekolah,
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
      lokasiSekolah: json['lokasi_sekolah'] == null
          ? null
          : LokasiSekolah.fromJson(
              json['lokasi_sekolah'] as Map<String, dynamic>,
            ),
      absensi: json['absensi'] == null
          ? null
          : Absensi.fromJson(json['absensi'] as Map<String, dynamic>),
    );
  }
}

/// Pengaturan absen yang diatur admin (menu Pengaturan Sistem).
class PengaturanAbsen {
  const PengaturanAbsen({
    required this.radiusAbsen,
    required this.toleransiTerlambat,
    required this.jamKerja,
    this.lokasiLat,
    this.lokasiLng,
    this.alamatYayasan,
  });

  final double? lokasiLat;
  final double? lokasiLng;
  final int radiusAbsen;
  final int toleransiTerlambat;
  final List<JamKerja> jamKerja;
  final String? alamatYayasan;

  bool get lokasiDiatur => lokasiLat != null && lokasiLng != null;

  factory PengaturanAbsen.fromJson(Map<String, dynamic> json) =>
      PengaturanAbsen(
        lokasiLat: (json['lokasi_lat'] as num?)?.toDouble(),
        lokasiLng: (json['lokasi_lng'] as num?)?.toDouble(),
        radiusAbsen: json['radius_absen'] as int,
        toleransiTerlambat: json['toleransi_terlambat'] as int,
        alamatYayasan: json['alamat_yayasan'] as String?,
        jamKerja: (json['jam_kerja'] as List)
            .map((e) => JamKerja.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'lokasi_lat': lokasiLat,
    'lokasi_lng': lokasiLng,
    'radius_absen': radiusAbsen,
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
