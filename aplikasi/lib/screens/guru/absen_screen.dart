import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/perangkat_absen.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/pesan.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/tombol_utama.dart';
import 'kamera_absen_screen.dart';

/// Tahapan halaman Absen pada hari ini.
enum _Tahap {
  libur,
  tanpaAbsen, // tercatat izin / sakit / cuti
  belumDibuka, // sebelum jam absen masuk dibuka
  lewatMasuk, // belum absen masuk padahal sudah lewat jam pulang
  siapMasuk,
  menungguPulang, // sudah absen masuk, tombol pulang belum muncul
  siapPulang,
  selesai,
}

/// Halaman Absen guru (sesuai desain): foto selfie + lokasi GPS.
///
/// Alur:
/// 1. Tekan "Buka Kamera" -> kamera langsung (bukan galeri) -> foto selfie.
///    Lokasi GPS dibaca tepat saat foto diambil.
/// 2. Aplikasi menampilkan lokasi absen terdekat (Lokasi 1, 2, 3, ...);
///    jika berada di dalam radius salah satunya, tekan "Kirim Absen".
/// 3. Setelah absen masuk tombol hilang, lalu muncul lagi mulai jam pulang
///    paling awal (13.00) untuk absen pulang.
///
/// Jam yang dipakai adalah jam SERVER, bukan jam HP.
class AbsenScreen extends StatefulWidget {
  const AbsenScreen({
    super.key,
    this.absenService,
    this.kamera,
    this.lokasi,
    this.sekarang,
  });

  final AbsenService? absenService;
  final KameraAbsen? kamera;
  final LokasiPerangkat? lokasi;

  /// Jam perangkat (bisa diganti saat pengujian).
  final DateTime Function()? sekarang;

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();
  late final KameraAbsen _kamera = widget.kamera ?? const KameraAbsen();
  late final LokasiPerangkat _lokasi = widget.lokasi ?? const LokasiPerangkat();

  InfoAbsenHariIni? _info;
  bool _sedangMemuat = true;
  String? _pesanGagal;

  /// Selisih jam server dengan jam perangkat.
  Duration _selisihServer = Duration.zero;
  Timer? _detak;

  // Foto & lokasi saat foto diambil (belum dikirim)
  FotoAbsen? _foto;
  PosisiAbsen? _posisi;
  LokasiException? _masalahLokasi;
  bool _sedangMengirim = false;

  // Foto yang sudah tersimpan di server
  Uint8List? _fotoMasuk;
  Uint8List? _fotoPulang;

  DateTime _jamPerangkat() => (widget.sekarang ?? DateTime.now)();
  DateTime get _jamServer => _jamPerangkat().add(_selisihServer);

  @override
  void initState() {
    super.initState();
    _muat();
    // Perbarui tampilan berkala, mis. agar tombol absen pulang muncul
    // tepat pukul 13.00 tanpa perlu menutup halaman.
    _detak = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final info = await _service.hariIni();
      if (!mounted) return;
      setState(() {
        _info = info;
        _selisihServer = info.waktuServer.difference(_jamPerangkat());
        _sedangMemuat = false;
        _pesanGagal = null;
      });
      _muatFotoTersimpan(info.absensi);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  Future<void> _muatFotoTersimpan(Absensi? absensi) async {
    if (absensi == null) return;
    Future<Uint8List?> ambil(String jenis) async {
      try {
        return await _service.ambilFoto(absensi.idAbsensi, jenis);
      } on ApiException {
        return null; // foto tidak wajib tampil
      }
    }

    if (absensi.adaFotoMasuk && _fotoMasuk == null) {
      final foto = await ambil('masuk');
      if (mounted && foto != null) setState(() => _fotoMasuk = foto);
    }
    if (absensi.adaFotoPulang && _fotoPulang == null) {
      final foto = await ambil('pulang');
      if (mounted && foto != null) setState(() => _fotoPulang = foto);
    }
  }

  // ------------------------------------------------------------------
  // Aturan tahapan
  // ------------------------------------------------------------------

  static int _keMenit(String jam) {
    final bagian = jam.split(':');
    return int.parse(bagian[0]) * 60 + int.parse(bagian[1]);
  }

  int get _menitServer => _jamServer.hour * 60 + _jamServer.minute;

  _Tahap _tahap(InfoAbsenHariIni info) {
    final absensi = info.absensi;
    if (info.libur != null) return _Tahap.libur;
    if (absensi != null && absensi.tanpaAbsen) return _Tahap.tanpaAbsen;
    if (absensi != null && absensi.sudahPulang) return _Tahap.selesai;
    if (absensi != null && absensi.sudahMasuk) {
      return _menitServer >= _keMenit(info.absenPulangMulai)
          ? _Tahap.siapPulang
          : _Tahap.menungguPulang;
    }
    if (_menitServer < _keMenit(info.absenMasukMulai)) {
      return _Tahap.belumDibuka;
    }
    if (_menitServer >= _keMenit(info.jamKerja.jamPulang)) {
      return _Tahap.lewatMasuk;
    }
    return _Tahap.siapMasuk;
  }

  /// Menit sebelum jam pulang unit guru (0 jika sudah lewat).
  int _menitSebelumJamPulang(InfoAbsenHariIni info) {
    final sisa = _keMenit(info.jamKerja.jamPulang) - _menitServer;
    return sisa > 0 ? sisa : 0;
  }

  /// Jarak posisi saat foto ke setiap lokasi absen, terdekat di atas.
  List<JarakLokasi> get _jarakLokasi {
    final posisi = _posisi;
    if (posisi == null) return const [];
    return urutkanLokasi(
      _info?.lokasiAbsen ?? const [],
      posisi.lat,
      posisi.lng,
    );
  }

  bool get _lokasiSiap {
    final posisi = _posisi;
    if (posisi == null || posisi.palsu) return false;
    final terpilih = lokasiAbsenTerpilih(_jarakLokasi);
    return terpilih == null || terpilih.diDalam;
  }

  // ------------------------------------------------------------------
  // Aksi
  // ------------------------------------------------------------------

  Future<void> _bukaKamera({required bool pulang}) async {
    final hasil = await _kamera.buka(
      context,
      judul: pulang ? 'Foto Absen Pulang' : 'Foto Absen Masuk',
      lokasiAbsen: _info?.lokasiAbsen ?? const [],
      lokasi: _lokasi,
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _foto = hasil.foto;
      _posisi = hasil.posisi;
      _masalahLokasi = hasil.masalahLokasi;
    });
  }

  Future<void> _kirimAbsen(InfoAbsenHariIni info, _Tahap tahap) async {
    final foto = _foto;
    final posisi = _posisi;
    if (foto == null || posisi == null) return;
    final pulang = tahap == _Tahap.siapPulang;

    final menitAwal = _menitSebelumJamPulang(info);
    if (pulang && menitAwal > 0) {
      final lanjut = await _konfirmasiPulangAwal(info, menitAwal);
      if (lanjut != true || !mounted) return;
    }

    setState(() => _sedangMengirim = true);
    try {
      final hasil = pulang
          ? await _service.absenPulang(foto, posisi)
          : await _service.absenMasuk(foto, posisi);
      if (!mounted) return;
      setState(() {
        _info = info.denganAbsensi(hasil.absensi);
        if (pulang) {
          _fotoPulang = foto.bytes;
        } else {
          _fotoMasuk = foto.bytes;
        }
        _foto = null;
        _posisi = null;
        _sedangMengirim = false;
      });
      tampilkanPesan(context, hasil.pesan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      tampilkanPesan(context, e.pesan, gagal: true);
      // Mis. sudah absen dari HP lain: muat ulang data terbaru
      if (e.kodeStatus == 409) _muat();
    }
  }

  Future<bool?> _konfirmasiPulangAwal(InfoAbsenHariIni info, int menit) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulang lebih awal?'),
        content: Text(
          'Jam pulang unit ${info.jamKerja.unit} pukul '
          '${info.jamKerja.jamPulang.replaceAll(':', '.')}. Jika absen pulang '
          'sekarang, kamu tercatat pulang lebih awal $menit menit dan akan '
          'terlihat di rekap admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 42)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tetap Absen'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Tampilan
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Absen'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_sedangMemuat) {
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }
    final info = _info;
    if (info == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_pesanGagal ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _sedangMemuat = true);
                  _muat();
                },
                style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final tahap = _tahap(info);
    final siapKirim = tahap == _Tahap.siapMasuk || tahap == _Tahap.siapPulang;

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: siapKirim && _foto != null
            ? _tampilanSiapKirim(info, tahap)
            : _tampilanUtama(info, tahap),
      ),
    );
  }

  /// Desain 1 & 3: kartu foto besar + info jam + tombol (jika ada).
  List<Widget> _tampilanUtama(InfoAbsenHariIni info, _Tahap tahap) {
    final absensi = info.absensi;
    final tanggal = FormatTanggal.panjang(info.tanggal);

    switch (tahap) {
      case _Tahap.libur:
        return [
          _KartuPesan(
            ikon: Icons.beach_access_rounded,
            warnaIkon: const Color(0xFFFF8A80),
            judul: 'Hari ini libur',
            isi: '${info.libur}\n$tanggal',
          ),
        ];
      case _Tahap.tanpaAbsen:
        return [
          _KartuPesan(
            ikon: Icons.event_available_rounded,
            warnaIkon: AppColors.mint,
            judul: 'Hari ini kamu tercatat ${absensi!.status}',
            isi: '$tanggal\nTidak perlu absen hari ini.',
          ),
        ];
      case _Tahap.belumDibuka:
      case _Tahap.lewatMasuk:
      case _Tahap.siapMasuk:
        return [
          _KartuFoto(foto: null, keterangan: tanggal, tinggi: 200),
          const SizedBox(height: 18),
          if (tahap == _Tahap.siapMasuk)
            TombolUtama(
              teks: 'Buka Kamera',
              ikon: Icons.photo_camera_rounded,
              onPressed: () => _bukaKamera(pulang: false),
            )
          else
            _Catatan(
              ikon: Icons.schedule_rounded,
              teks: tahap == _Tahap.belumDibuka
                  ? 'Absen masuk dibuka mulai pukul '
                        '${info.absenMasukMulai.replaceAll(':', '.')}.'
                  : 'Waktu absen masuk sudah lewat (jam pulang '
                        '${info.jamKerja.jamPulang.replaceAll(':', '.')}). '
                        'Hubungi admin jika ada kendala.',
            ),
          const SizedBox(height: 12),
          Text(
            'Jam masuk unit ${info.jamKerja.unit}: '
            '${info.jamKerja.jamMasuk.replaceAll(':', '.')} '
            '(toleransi ${info.toleransiMenit} menit)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.teksAbu),
          ),
        ];
      case _Tahap.menungguPulang:
      case _Tahap.siapPulang:
        return [
          _KartuFoto(foto: _fotoMasuk, tinggi: 200),
          const SizedBox(height: 18),
          _BarisJam(
            label: 'Jam Masuk',
            jam: absensi!.jamMasuk,
            lokasi: absensi.lokasiMasuk,
            jarak: absensi.jarakMasuk,
            catatan: absensi.terlambat
                ? 'Terlambat ${absensi.menitTerlambat} menit'
                : null,
          ),
          const SizedBox(height: 16),
          const _BarisJam(label: 'Jam Keluar', jam: null),
          const SizedBox(height: 28),
          if (tahap == _Tahap.siapPulang)
            TombolUtama(
              teks: 'Absen Pulang',
              ikon: Icons.photo_camera_rounded,
              onPressed: () => _bukaKamera(pulang: true),
            )
          else
            _Catatan(
              ikon: Icons.info_outline_rounded,
              teks:
                  'Tombol absen pulang muncul pukul '
                  '${info.absenPulangMulai.replaceAll(':', '.')}.',
            ),
        ];
      case _Tahap.selesai:
        return [
          Row(
            children: [
              Expanded(
                child: _KartuFoto(
                  foto: _fotoMasuk,
                  tinggi: 170,
                  label: 'Masuk',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KartuFoto(
                  foto: _fotoPulang,
                  tinggi: 170,
                  label: 'Pulang',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BarisJam(
            label: 'Jam Masuk',
            jam: absensi!.jamMasuk,
            lokasi: absensi.lokasiMasuk,
            jarak: absensi.jarakMasuk,
            catatan: absensi.terlambat
                ? 'Terlambat ${absensi.menitTerlambat} menit'
                : null,
          ),
          const SizedBox(height: 16),
          _BarisJam(
            label: 'Jam Keluar',
            jam: absensi.jamPulang,
            lokasi: absensi.lokasiPulang,
            jarak: absensi.jarakPulang,
            catatan: absensi.menitPulangAwal > 0
                ? 'Pulang lebih awal ${absensi.menitPulangAwal} menit'
                : null,
          ),
          const SizedBox(height: 28),
          const _Catatan(
            ikon: Icons.verified_rounded,
            teks: 'Absen hari ini sudah lengkap. Terima kasih!',
            warna: AppColors.hijau,
          ),
        ];
    }
  }

  /// Desain 2: foto dari kamera + jam + kartu lokasi + tombol "Kirim Absen".
  List<Widget> _tampilanSiapKirim(InfoAbsenHariIni info, _Tahap tahap) {
    final pulang = tahap == _Tahap.siapPulang;
    final jamSekarang = DateFormat('HH:mm').format(_jamServer);
    final menitAwal = pulang ? _menitSebelumJamPulang(info) : 0;

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Column(
              children: [
                _KartuFoto(foto: _foto!.bytes, tinggi: 165),
                TextButton.icon(
                  onPressed: _sedangMengirim
                      ? null
                      : () => _bukaKamera(pulang: pulang),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Foto ulang'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BarisJam(
                    label: 'Jam Masuk',
                    jam: pulang ? info.absensi!.jamMasuk : jamSekarang,
                    tampilkanIkon: false,
                  ),
                  const SizedBox(height: 22),
                  _BarisJam(
                    label: 'Jam Keluar',
                    jam: pulang ? jamSekarang : null,
                    tampilkanIkon: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _KartuLokasi(
        masalah: _masalahLokasi,
        posisi: _posisi,
        adaLokasiAbsen: info.lokasiAbsen.isNotEmpty,
        jarakLokasi: _jarakLokasi,
        onFotoUlang: () => _bukaKamera(pulang: pulang),
        onBukaPengaturan: _masalahLokasi == null
            ? null
            : () => _lokasi.bukaPengaturan(_masalahLokasi!.pengaturan),
      ),
      if (menitAwal > 0) ...[
        const SizedBox(height: 16),
        _Catatan(
          ikon: Icons.warning_amber_rounded,
          warna: const Color(0xFFB7791F),
          teks:
              'Jam pulang unit ${info.jamKerja.unit} pukul '
              '${info.jamKerja.jamPulang.replaceAll(':', '.')}. Absen pulang '
              'sekarang akan tercatat pulang lebih awal $menitAwal menit.',
        ),
      ],
      const SizedBox(height: 28),
      TombolUtama(
        teks: 'Kirim Absen',
        ikon: Icons.send_rounded,
        sedangMemuat: _sedangMengirim,
        onPressed: _lokasiSiap ? () => _kirimAbsen(info, tahap) : null,
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Komponen tampilan
// ---------------------------------------------------------------------------

/// Kartu foto dengan sudut membulat & bayangan (sesuai desain).
class _KartuFoto extends StatelessWidget {
  const _KartuFoto({
    required this.foto,
    required this.tinggi,
    this.keterangan,
    this.label,
  });

  final Uint8List? foto;
  final double tinggi;

  /// Teks pada kartu kosong (belum ada foto).
  final String? keterangan;

  /// Label kecil di pojok kiri bawah, mis. "Masuk".
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tinggi,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (foto != null)
            Image.memory(
              foto!,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              gaplessPlayback: true,
            )
          else
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF040029), Color(0xFF0B0068)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    keterangan == null
                        ? Icons.person_rounded
                        : Icons.photo_camera_front_rounded,
                    size: 54,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  if (keterangan != null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Foto selfie langsung dari kamera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keterangan!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (label != null)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Jam Masuk  06:33" + ikon lokasi & terverifikasi (desain 3).
class _BarisJam extends StatelessWidget {
  const _BarisJam({
    required this.label,
    required this.jam,
    this.lokasi,
    this.jarak,
    this.catatan,
    this.tampilkanIkon = true,
  });

  final String label;

  /// "HH:MM", null = belum absen ("--:--" merah).
  final String? jam;

  /// Nama lokasi absen, mis. "Gedung SD".
  final String? lokasi;
  final int? jarak;
  final String? catatan;
  final bool tampilkanIkon;

  static const _hijau = Color(0xFF6CBD3B);

  @override
  Widget build(BuildContext context) {
    final sudah = jam != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.teks,
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              jam ?? '--:--',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: sudah ? _hijau : AppColors.merah,
              ),
            ),
            if (sudah && tampilkanIkon) ...[
              Tooltip(
                message: jarak == null
                    ? 'Lokasi tercatat'
                    : 'Lokasi tercatat (${formatJarak(jarak!)} dari '
                          '${lokasi ?? 'lokasi absen'})',
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _hijau,
                  size: 22,
                ),
              ),
              const Tooltip(
                message: 'Foto absen tersimpan',
                child: Icon(Icons.how_to_reg_rounded, color: _hijau, size: 22),
              ),
              if (lokasi != null)
                Text(
                  lokasi!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teksAbu,
                  ),
                ),
            ],
            if (catatan != null)
              Text(
                catatan!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB7791F),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Kartu abu-abu berisi ikon lokasi & lokasi absen terdekat (desain 2).
/// Lokasi yang ditampilkan adalah posisi GPS saat foto diambil.
class _KartuLokasi extends StatelessWidget {
  const _KartuLokasi({
    required this.masalah,
    required this.posisi,
    required this.adaLokasiAbsen,
    required this.jarakLokasi,
    required this.onFotoUlang,
    this.onBukaPengaturan,
  });

  final LokasiException? masalah;
  final PosisiAbsen? posisi;
  final bool adaLokasiAbsen;

  /// Jarak ke setiap lokasi absen, terdekat di atas.
  final List<JarakLokasi> jarakLokasi;
  final VoidCallback onFotoUlang;
  final VoidCallback? onBukaPengaturan;

  @override
  Widget build(BuildContext context) {
    final Color warnaIkon;
    final String judul;
    String? keterangan;
    var tombolFotoUlang = false;
    final terpilih = lokasiAbsenTerpilih(jarakLokasi);

    if (masalah != null || posisi == null) {
      warnaIkon = AppColors.merah;
      judul = 'Lokasi tidak terbaca saat foto diambil';
      keterangan = masalah?.pesan;
      tombolFotoUlang = true;
    } else if (posisi!.palsu) {
      warnaIkon = AppColors.merah;
      judul = 'Terdeteksi lokasi palsu';
      keterangan = 'Matikan aplikasi Fake GPS lalu foto ulang.';
      tombolFotoUlang = true;
    } else if (!adaLokasiAbsen || terpilih == null) {
      warnaIkon = AppColors.hijau;
      judul = 'Lokasi terbaca';
      keterangan =
          'Admin belum menambahkan lokasi absen, jadi jarak tidak dicek.';
    } else if (terpilih.diDalam) {
      warnaIkon = AppColors.hijau;
      judul = 'Kamu berada di ${terpilih.lokasi.nama}';
      keterangan =
          'Lokasi ${terpilih.lokasi.nomor} • ± ${formatJarak(terpilih.jarak)} '
          'dari titik absen';
    } else {
      warnaIkon = AppColors.merah;
      judul = 'Di luar area lokasi absen';
      keterangan =
          'Terdekat: ${terpilih.lokasi.namaLengkap}, ± '
          '${formatJarak(terpilih.jarak)} (maksimal ${terpilih.lokasi.radius} m). '
          'Mendekatlah ke lokasi absen lalu foto ulang.';
      tombolFotoUlang = true;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFD3D3D3),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 58,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(color: warnaIkon, width: 3.5),
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(58, 22),
                      ),
                    ),
                  ),
                ),
                Icon(Icons.location_on, size: 96, color: warnaIkon),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.teks,
            ),
          ),
          if (keterangan != null) ...[
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF3F3F46)),
            ),
          ],
          // Jarak ke semua lokasi absen (jika lebih dari satu)
          if (jarakLokasi.length > 1 && posisi != null && !posisi!.palsu) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final j in jarakLokasi)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            j.diDalam
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: j.diDalam
                                ? AppColors.hijau
                                : AppColors.teksAbu,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              j.lokasi.namaLengkap,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: identical(j, terpilih)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.teks,
                              ),
                            ),
                          ),
                          Text(
                            formatJarak(j.jarak),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.teks,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (tombolFotoUlang)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onFotoUlang,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Foto ulang'),
                ),
                if (onBukaPengaturan != null &&
                    masalah?.pengaturan != PengaturanLokasi.tidakAda)
                  TextButton.icon(
                    onPressed: onBukaPengaturan,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Buka pengaturan'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Catatan kecil berikon (info jam, peringatan, dll).
class _Catatan extends StatelessWidget {
  const _Catatan({
    required this.ikon,
    required this.teks,
    this.warna = AppColors.teksAbu,
  });

  final IconData ikon;
  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: warna),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: warna),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu besar untuk hari libur / izin / sakit / cuti.
class _KartuPesan extends StatelessWidget {
  const _KartuPesan({
    required this.ikon,
    required this.warnaIkon,
    required this.judul,
    required this.isi,
  });

  final IconData ikon;
  final Color warnaIkon;
  final String judul;
  final String isi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040029), Color(0xFF0B0068)],
        ),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 56, color: warnaIkon),
          const SizedBox(height: 14),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isi,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
