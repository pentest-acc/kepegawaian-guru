import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Foto selfie yang diambil untuk absen.
class FotoAbsen {
  const FotoAbsen({required this.bytes, required this.namaFile});

  final Uint8List bytes;
  final String namaFile;
}

/// Posisi GPS perangkat saat absen.
class PosisiAbsen {
  const PosisiAbsen({
    required this.lat,
    required this.lng,
    this.akurasi = 0,
    this.palsu = false,
  });

  final double lat;
  final double lng;

  /// Perkiraan ketelitian lokasi (meter).
  final double akurasi;

  /// true jika Android mendeteksi lokasi palsu (aplikasi Fake GPS).
  final bool palsu;
}

/// Halaman pengaturan HP yang bisa memperbaiki masalah lokasi.
enum PengaturanLokasi { tidakAda, gps, izinAplikasi }

/// Kesalahan saat membaca lokasi, berisi pesan yang siap ditampilkan.
class LokasiException implements Exception {
  LokasiException(this.pesan, {this.pengaturan = PengaturanLokasi.tidakAda});

  final String pesan;

  /// Pengaturan HP yang perlu dibuka untuk memperbaikinya.
  final PengaturanLokasi pengaturan;

  @override
  String toString() => pesan;
}

/// Pembaca lokasi GPS. Bisa diganti versi palsu saat pengujian.
class LokasiPerangkat {
  const LokasiPerangkat();

  /// Posisi saat ini (sekali baca).
  Future<PosisiAbsen> posisiSekarang() async {
    await _pastikanIzin();
    try {
      final posisi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return _ubah(posisi);
    } on Exception {
      throw LokasiException(
        'Lokasi belum terbaca. Pastikan GPS menyala dan coba di tempat '
        'terbuka, lalu foto ulang.',
      );
    }
  }

  /// Posisi yang terus diperbarui selama kamera absen terbuka.
  Stream<PosisiAbsen> pantauPosisi() async* {
    await _pastikanIzin();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // kirim setiap pembaruan selama kamera terbuka
      ),
    ).map(_ubah);
  }

  static PosisiAbsen _ubah(Position posisi) => PosisiAbsen(
    lat: posisi.latitude,
    lng: posisi.longitude,
    akurasi: posisi.accuracy,
    palsu: posisi.isMocked,
  );

  Future<void> _pastikanIzin() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LokasiException(
        'GPS/lokasi di HP sedang mati. Nyalakan lokasi lalu coba lagi.',
        pengaturan: kIsWeb ? PengaturanLokasi.tidakAda : PengaturanLokasi.gps,
      );
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied) {
      throw LokasiException(
        'Izin lokasi ditolak. Izinkan akses lokasi agar bisa absen.',
      );
    }
    if (izin == LocationPermission.deniedForever) {
      throw LokasiException(
        'Izin lokasi diblokir. Buka pengaturan aplikasi, lalu izinkan '
        'akses lokasi.',
        pengaturan: kIsWeb
            ? PengaturanLokasi.tidakAda
            : PengaturanLokasi.izinAplikasi,
      );
    }
  }

  /// Buka pengaturan GPS atau izin aplikasi di HP.
  Future<void> bukaPengaturan(PengaturanLokasi pengaturan) async {
    switch (pengaturan) {
      case PengaturanLokasi.gps:
        await Geolocator.openLocationSettings();
      case PengaturanLokasi.izinAplikasi:
        await Geolocator.openAppSettings();
      case PengaturanLokasi.tidakAda:
        break;
    }
  }
}
