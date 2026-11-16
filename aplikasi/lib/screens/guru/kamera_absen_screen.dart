import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/perangkat_absen.dart';

/// Hasil kamera absen: foto + posisi GPS tepat saat foto diambil.
class HasilKamera {
  const HasilKamera({required this.foto, this.posisi, this.masalahLokasi});

  final FotoAbsen foto;

  /// null jika lokasi tidak terbaca (lihat [masalahLokasi]).
  final PosisiAbsen? posisi;
  final LokasiException? masalahLokasi;
}

/// Pembuka kamera absen. Bisa diganti versi palsu saat pengujian.
class KameraAbsen {
  const KameraAbsen();

  /// Buka kamera di dalam aplikasi. null jika guru menutup kamera.
  Future<HasilKamera?> buka(
    BuildContext context, {
    required String judul,
    required List<LokasiAbsen> lokasiAbsen,
    required LokasiPerangkat lokasi,
  }) {
    return Navigator.of(context).push<HasilKamera>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KameraAbsenScreen(
          judul: judul,
          lokasiAbsen: lokasiAbsen,
          lokasi: lokasi,
        ),
      ),
    );
  }
}

/// Kamera langsung untuk foto absen (tidak bisa memilih foto dari galeri).
///
/// Selama kamera terbuka, lokasi GPS terus dipantau (live) dan lokasi absen
/// terdekat ditampilkan di bagian atas. Saat tombol foto ditekan, posisi live
/// saat itu ikut disimpan bersama fotonya.
class KameraAbsenScreen extends StatefulWidget {
  const KameraAbsenScreen({
    super.key,
    required this.judul,
    required this.lokasiAbsen,
    this.lokasi = const LokasiPerangkat(),
  });

  final String judul;
  final List<LokasiAbsen> lokasiAbsen;
  final LokasiPerangkat lokasi;

  @override
  State<KameraAbsenScreen> createState() => _KameraAbsenScreenState();
}

class _KameraAbsenScreenState extends State<KameraAbsenScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _daftarKamera = const [];
  CameraDescription? _kameraDipakai;
  CameraController? _kontroler;
  String? _pesanKamera;
  bool _memotret = false;

  PosisiAbsen? _posisi;
  LokasiException? _masalahLokasi;
  StreamSubscription<PosisiAbsen>? _pantauLokasi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _siapkanKamera();
    _mulaiPantauLokasi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pantauLokasi?.cancel();
    _kontroler?.dispose();
    super.dispose();
  }

  /// Kamera dilepas saat aplikasi ke latar belakang, lalu dibuka lagi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final kontroler = _kontroler;
    // Di browser, berpindah jendela tidak perlu mematikan kamera
    if (kIsWeb || kontroler == null || !kontroler.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _kontroler = null;
      kontroler.dispose();
    } else if (state == AppLifecycleState.resumed && _kameraDipakai != null) {
      _pakaiKamera(_kameraDipakai!);
    }
  }

  // ------------------------------- Kamera -------------------------------

  Future<void> _siapkanKamera() async {
    if (_pesanKamera != null) setState(() => _pesanKamera = null);
    try {
      _daftarKamera = await availableCameras();
      if (_daftarKamera.isEmpty) {
        setState(
          () => _pesanKamera = 'Kamera tidak ditemukan di perangkat ini.',
        );
        return;
      }
      // Utamakan kamera depan (selfie)
      final depan = _daftarKamera.where(
        (k) => k.lensDirection == CameraLensDirection.front,
      );
      await _pakaiKamera(depan.isNotEmpty ? depan.first : _daftarKamera.first);
    } on CameraException catch (e) {
      if (mounted) setState(() => _pesanKamera = _pesanDari(e));
    }
  }

  Future<void> _pakaiKamera(CameraDescription kamera) async {
    final lama = _kontroler;
    final baru = CameraController(
      kamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    setState(() {
      _kontroler = null;
      _kameraDipakai = kamera;
    });
    await lama?.dispose();
    try {
      await baru.initialize();
      if (!mounted) {
        await baru.dispose();
        return;
      }
      setState(() => _kontroler = baru);
    } on CameraException catch (e) {
      await baru.dispose();
      if (mounted) setState(() => _pesanKamera = _pesanDari(e));
    }
  }

  Future<void> _gantiKamera() async {
    if (_daftarKamera.length < 2 || _kameraDipakai == null) return;
    final indeks = _daftarKamera.indexOf(_kameraDipakai!);
    await _pakaiKamera(_daftarKamera[(indeks + 1) % _daftarKamera.length]);
  }

  static String _pesanDari(CameraException e) {
    final kode = e.code.toLowerCase();
    if (kode.contains('denied') ||
        kode.contains('permission') ||
        kode.contains('restricted')) {
      return 'Izin kamera ditolak. Izinkan akses kamera untuk aplikasi ini, '
          'lalu tekan Coba lagi.';
    }
    if (kode.contains('notfound') || kode.contains('not_found')) {
      return 'Kamera tidak ditemukan di perangkat ini.';
    }
    return 'Kamera tidak bisa dibuka (${e.description ?? e.code}).';
  }

  // ------------------------------- Lokasi -------------------------------

  void _mulaiPantauLokasi() {
    _pantauLokasi = widget.lokasi.pantauPosisi().listen(
      (posisi) {
        if (mounted) {
          setState(() {
            _posisi = posisi;
            _masalahLokasi = null;
          });
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(
            () => _masalahLokasi = e is LokasiException
                ? e
                : LokasiException(
                    'Lokasi belum terbaca. Pastikan GPS menyala.',
                  ),
          );
        }
      },
    );
  }

  // ------------------------------- Potret -------------------------------

  Future<void> _potret() async {
    final kontroler = _kontroler;
    if (_memotret || kontroler == null || !kontroler.value.isInitialized) {
      return;
    }
    setState(() => _memotret = true);

    final XFile file;
    try {
      file = await kontroler.takePicture();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _memotret = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto gagal diambil: ${e.description ?? e.code}'),
        ),
      );
      return;
    }

    // Lokasi saat foto diambil: posisi GPS live terakhir yang sedang
    // dipantau. Jika belum ada sama sekali, baca sekali lagi (maks. 15 detik).
    var posisi = _posisi;
    LokasiException? masalah;
    if (posisi == null) {
      try {
        posisi = await widget.lokasi.posisiSekarang().timeout(
          const Duration(seconds: 15),
        );
      } on LokasiException catch (e) {
        masalah = e;
      } on TimeoutException {
        masalah = LokasiException(
          'Lokasi belum terbaca. Pastikan GPS menyala, lalu foto ulang.',
        );
      }
      posisi ??= _posisi; // mungkin sudah masuk dari pantauan
      if (posisi != null) masalah = null;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).pop(
      HasilKamera(
        foto: FotoAbsen(bytes: bytes, namaFile: 'absen.jpg'),
        posisi: posisi,
        masalahLokasi: masalah,
      ),
    );
  }

  // ------------------------------- Tampilan -------------------------------

  @override
  Widget build(BuildContext context) {
    final kontroler = _kontroler;
    final siap = kontroler != null && kontroler.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_pesanKamera != null)
            _PesanKamera(pesan: _pesanKamera!, onCobaLagi: _siapkanKamera)
          else if (siap)
            Center(child: CameraPreview(kontroler))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (siap) const Center(child: _BingkaiWajah()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Tutup kamera',
                        onPressed: _memotret
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                      ),
                      Expanded(
                        child: Text(
                          widget.judul,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_daftarKamera.length > 1)
                        IconButton(
                          tooltip: 'Ganti kamera',
                          onPressed: _memotret ? null : _gantiKamera,
                          icon: const Icon(Icons.cameraswitch_rounded),
                          color: Colors.white,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ChipLokasi(
                    posisi: _posisi,
                    masalah: _masalahLokasi,
                    lokasiAbsen: widget.lokasiAbsen,
                  ),
                ),
                const Spacer(),
                Text(
                  _memotret
                      ? 'Menyimpan foto & membaca lokasi...'
                      : 'Pastikan wajah terlihat jelas di dalam bingkai',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'Ambil foto',
                  child: GestureDetector(
                    onTap: siap ? _potret : null,
                    child: Container(
                      key: const Key('tombol-potret'),
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: _memotret
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: siap ? Colors.white : Colors.white38,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status lokasi terkini di atas kamera, mis. "Lokasi 2 • Gedung SD • 35 m".
class _ChipLokasi extends StatelessWidget {
  const _ChipLokasi({
    required this.posisi,
    required this.masalah,
    required this.lokasiAbsen,
  });

  final PosisiAbsen? posisi;
  final LokasiException? masalah;
  final List<LokasiAbsen> lokasiAbsen;

  @override
  Widget build(BuildContext context) {
    final IconData ikon;
    final Color warna;
    final String teks;

    final posisi = this.posisi;
    if (masalah != null) {
      ikon = Icons.location_off_rounded;
      warna = AppColors.merah;
      teks = masalah!.pesan;
    } else if (posisi == null) {
      ikon = Icons.my_location_rounded;
      warna = Colors.black54;
      teks = 'Mencari lokasi...';
    } else if (posisi.palsu) {
      ikon = Icons.gpp_bad_rounded;
      warna = AppColors.merah;
      teks = 'Terdeteksi lokasi palsu (Fake GPS)';
    } else {
      final terpilih = lokasiAbsenTerpilih(
        urutkanLokasi(lokasiAbsen, posisi.lat, posisi.lng),
      );
      if (terpilih == null) {
        ikon = Icons.location_on_rounded;
        warna = AppColors.hijau;
        teks = 'Lokasi terbaca (± ${posisi.akurasi.round()} m)';
      } else if (terpilih.diDalam) {
        ikon = Icons.location_on_rounded;
        warna = AppColors.hijau;
        teks =
            '${terpilih.lokasi.namaLengkap} • ${formatJarak(terpilih.jarak)}';
      } else {
        ikon = Icons.wrong_location_rounded;
        warna = AppColors.merah;
        teks =
            'Di luar area • ${formatJarak(terpilih.jarak)} dari '
            '${terpilih.lokasi.nama}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              teks,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bingkai oval sebagai panduan posisi wajah.
class _BingkaiWajah extends StatelessWidget {
  const _BingkaiWajah();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 230,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.elliptical(115, 150)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.75),
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _PesanKamera extends StatelessWidget {
  const _PesanKamera({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCobaLagi,
              style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
