import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/jadwal_mengajar.dart';
import '../../services/api_service.dart';
import '../../services/jadwal_service.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/hari.dart';
import '../../widgets/loading_dots.dart';

/// Halaman Jadwal Mengajar untuk guru (sesuai desain).
///
/// Jadwal diatur admin sebagai jadwal MINGGUAN, jadi otomatis berulang
/// setiap minggu. Guru bisa berpindah minggu untuk melihat tanggal & hari
/// libur; jadwal Senin tetap sama di setiap Senin kecuali Senin itu libur.
class JadwalMengajarScreen extends StatefulWidget {
  const JadwalMengajarScreen({super.key, this.jadwalService, this.sekarang});

  final JadwalService? jadwalService;

  /// Sumber waktu "sekarang" (bisa diganti saat pengujian).
  final DateTime Function()? sekarang;

  @override
  State<JadwalMengajarScreen> createState() => _JadwalMengajarScreenState();
}

class _JadwalMengajarScreenState extends State<JadwalMengajarScreen> {
  late final JadwalService _service = widget.jadwalService ?? JadwalService();

  late DateTime _senin; // Senin dari minggu yang sedang ditampilkan
  late String _hariDipilih;

  List<JadwalMengajar> _jadwal = const [];
  List<HariLibur> _libur = const [];
  bool _sedangMemuat = true;
  String? _pesanGagal;
  int _nomorPermintaan = 0;

  DateTime _sekarang() => (widget.sekarang ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final sekarang = _sekarang();
    _senin = Hari.seninDari(sekarang);
    _hariDipilih = Hari.nama(sekarang);
    if (_hariDipilih == 'Minggu') {
      // Hari Minggu: langsung tampilkan jadwal minggu depan
      _senin = _geserMinggu(_senin, 1);
      _hariDipilih = 'Senin';
    }
    _muat();
  }

  static DateTime _geserMinggu(DateTime senin, int jumlah) =>
      DateTime(senin.year, senin.month, senin.day + 7 * jumlah);

  /// Tab hari: Senin-Jumat, ditambah Sabtu jika guru punya jadwal Sabtu.
  List<String> get _daftarHari => [
    ...Hari.sekolah.take(5),
    if (_jadwal.any((j) => j.hari == 'Sabtu')) 'Sabtu',
  ];

  DateTime get _tanggalDipilih => Hari.tanggalPada(_senin, _hariDipilih);

  HariLibur? _liburPada(DateTime tanggal) {
    for (final l in _libur) {
      if (Hari.tanggalSama(l.tanggal, tanggal)) return l;
    }
    return null;
  }

  List<JadwalMengajar> get _jadwalDipilih =>
      _jadwal.where((j) => j.hari == _hariDipilih).toList()
        ..sort((a, b) => a.menitMulai.compareTo(b.menitMulai));

  Future<void> _muat() async {
    final nomor = ++_nomorPermintaan;
    if (!_sedangMemuat) {
      setState(() {
        _sedangMemuat = true;
        _pesanGagal = null;
      });
    }

    try {
      final hasil = await _service.jadwalSaya(
        dari: _senin,
        sampai: Hari.tanggalPada(_senin, 'Sabtu'),
      );
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _jadwal = hasil.jadwal;
        _libur = hasil.libur;
        _sedangMemuat = false;
        _pesanGagal = null;
      });

      // Hari ini Sabtu tetapi tidak ada jadwal Sabtu -> tampilkan minggu depan
      if (!_daftarHari.contains(_hariDipilih)) {
        _gantiMinggu(1, pilihSenin: true);
      }
    } on ApiException catch (e) {
      if (!mounted || nomor != _nomorPermintaan) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  void _gantiMinggu(int arah, {bool pilihSenin = false}) {
    setState(() {
      _senin = _geserMinggu(_senin, arah);
      if (pilihSenin) _hariDipilih = 'Senin';
    });
    _muat();
  }

  void _keHariIni() {
    final sekarang = _sekarang();
    setState(() {
      _senin = Hari.seninDari(sekarang);
      final hari = Hari.nama(sekarang);
      _hariDipilih = _daftarHari.contains(hari) ? hari : 'Senin';
    });
    _muat();
  }

  String get _labelMinggu {
    final seninIni = Hari.seninDari(_sekarang());
    if (Hari.tanggalSama(_senin, seninIni)) return 'Minggu ini';
    if (Hari.tanggalSama(_senin, _geserMinggu(seninIni, 1))) {
      return 'Minggu depan';
    }
    if (Hari.tanggalSama(_senin, _geserMinggu(seninIni, -1))) {
      return 'Minggu lalu';
    }
    final akhir = Hari.tanggalPada(_senin, 'Sabtu');
    return '${DateFormat('d MMM', 'id_ID').format(_senin)} - '
        '${DateFormat('d MMM yyyy', 'id_ID').format(akhir)}';
  }

  @override
  Widget build(BuildContext context) {
    final sekarang = _sekarang();
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Jadwal Mengajar'),
      ),
      body: Column(
        children: [
          _TabHari(
            daftar: _daftarHari,
            dipilih: _hariDipilih,
            hariIni: [
              for (final h in _daftarHari)
                if (Hari.tanggalSama(Hari.tanggalPada(_senin, h), hariIni)) h,
            ],
            hariLibur: [
              for (final h in _daftarHari)
                if (_liburPada(Hari.tanggalPada(_senin, h)) != null) h,
            ],
            onPilih: (hari) => setState(() => _hariDipilih = hari),
          ),
          _BarisTanggal(
            tanggal: _tanggalDipilih,
            labelMinggu: _labelMinggu,
            malam: sekarang.hour >= 18 || sekarang.hour < 5,
            onSebelumnya: () => _gantiMinggu(-1),
            onBerikutnya: () => _gantiMinggu(1),
            onHariIni: _labelMinggu == 'Minggu ini' ? null : _keHariIni,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF040029), Color(0xFF0B0068)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    const _HiasanKartu(),
                    Positioned.fill(child: _isiKartu(sekarang)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _isiKartu(DateTime sekarang) {
    if (_sedangMemuat && _jadwal.isEmpty) {
      return const Center(child: LoadingDots());
    }
    if (_pesanGagal != null && _jadwal.isEmpty) {
      return _InfoKartu(
        ikon: Icons.cloud_off_rounded,
        judul: 'Gagal memuat jadwal',
        keterangan: _pesanGagal!,
        tombol: 'Coba lagi',
        onTombol: _muat,
      );
    }

    final libur = _liburPada(_tanggalDipilih);
    if (libur != null) {
      return _InfoKartu(
        ikon: Icons.beach_access_rounded,
        warnaIkon: const Color(0xFFFF8A8A),
        judul: 'Libur: ${libur.keterangan}',
        keterangan: 'Tidak ada kegiatan mengajar pada tanggal ini.',
      );
    }

    final daftar = _jadwalDipilih;
    if (daftar.isEmpty) {
      return _InfoKartu(
        ikon: Icons.event_available_rounded,
        judul: 'Tidak ada jadwal mengajar',
        keterangan: 'Hari $_hariDipilih Anda tidak memiliki jam mengajar.',
      );
    }

    final adalahHariIni = Hari.tanggalSama(_tanggalDipilih, sekarang);
    final menitSekarang = sekarang.hour * 60 + sekarang.minute;
    final totalMenit = daftar.fold<int>(0, (n, j) => n + j.durasiMenit);

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: _muat,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        children: [
          for (var i = 0; i < daftar.length; i++)
            _ItemTimeline(
              jadwal: daftar[i],
              pertama: i == 0,
              terakhir: i == daftar.length - 1,
              status: !adalahHariIni
                  ? _StatusJam.biasa
                  : menitSekarang >= daftar[i].menitSelesai
                  ? _StatusJam.selesai
                  : menitSekarang >= daftar[i].menitMulai
                  ? _StatusJam.berlangsung
                  : _StatusJam.biasa,
            ),
          const SizedBox(height: 16),
          Text(
            '${daftar.length} jam pelajaran  •  total '
            '${_formatDurasi(totalMenit)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDurasi(int menit) {
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    if (jam == 0) return '$sisa menit';
    if (sisa == 0) return '$jam jam';
    return '$jam jam $sisa menit';
  }
}

// ---------------------------------------------------------------------------

class _TabHari extends StatelessWidget {
  const _TabHari({
    required this.daftar,
    required this.dipilih,
    required this.hariIni,
    required this.hariLibur,
    required this.onPilih,
  });

  final List<String> daftar;
  final String dipilih;
  final List<String> hariIni;
  final List<String> hariLibur;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D5589),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (final hari in daftar)
            Expanded(
              child: Semantics(
                button: true,
                selected: hari == dipilih,
                child: GestureDetector(
                  onTap: () => onPilih(hari),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: hari == dipilih
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hari,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: hari == dipilih
                                  ? AppColors.navy
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Titik kecil: mint = hari ini, merah = libur
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hariLibur.contains(hari)
                                ? const Color(0xFFFF6B6B)
                                : hariIni.contains(hari)
                                ? AppColors.mint
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarisTanggal extends StatelessWidget {
  const _BarisTanggal({
    required this.tanggal,
    required this.labelMinggu,
    required this.malam,
    required this.onSebelumnya,
    required this.onBerikutnya,
    required this.onHariIni,
  });

  final DateTime tanggal;
  final String labelMinggu;
  final bool malam;
  final VoidCallback onSebelumnya;
  final VoidCallback onBerikutnya;
  final VoidCallback? onHariIni;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Minggu sebelumnya',
            onPressed: onSebelumnya,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FormatTanggal.panjang(tanggal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teks,
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      labelMinggu,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.teksAbu,
                      ),
                    ),
                    if (onHariIni != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onHariIni,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Kembali ke hari ini',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2B7BC4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Minggu berikutnya',
            onPressed: onBerikutnya,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 4),
          _IkonCuaca(malam: malam),
        ],
      ),
    );
  }
}

/// Ikon matahari/bulan di balik awan (hiasan seperti desain).
class _IkonCuaca extends StatelessWidget {
  const _IkonCuaca({required this.malam});

  final bool malam;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 44,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 2,
            child: Icon(
              malam ? Icons.nightlight_round : Icons.wb_sunny_outlined,
              size: 28,
              color: malam ? const Color(0xFF6C5CE7) : const Color(0xFFF2A516),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.cloud_rounded, size: 36, color: Colors.white),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.cloud_outlined, size: 36, color: AppColors.teks),
          ),
        ],
      ),
    );
  }
}

enum _StatusJam { biasa, berlangsung, selesai }

class _ItemTimeline extends StatelessWidget {
  const _ItemTimeline({
    required this.jadwal,
    required this.pertama,
    required this.terakhir,
    required this.status,
  });

  final JadwalMengajar jadwal;
  final bool pertama;
  final bool terakhir;
  final _StatusJam status;

  @override
  Widget build(BuildContext context) {
    const warnaGaris = Color(0xFF63B3ED);
    final berlangsung = status == _StatusJam.berlangsung;

    return Opacity(
      opacity: status == _StatusJam.selesai ? 0.5 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2.5,
                      color: pertama ? Colors.transparent : warnaGaris,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: berlangsung ? AppColors.mint : warnaGaris,
                      boxShadow: berlangsung
                          ? [
                              BoxShadow(
                                color: AppColors.mint.withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: AppColors.navy,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2.5,
                      color: terakhir ? Colors.transparent : warnaGaris,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      jadwal.mataPelajaran.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF7CC4F7),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${jadwal.jamTampil}  |  Kelas ${jadwal.kelas}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (status != _StatusJam.biasa) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: berlangsung
                              ? AppColors.mint
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          berlangsung ? 'Sedang berlangsung' : 'Selesai',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: berlangsung ? AppColors.navy : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoKartu extends StatelessWidget {
  const _InfoKartu({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.warnaIkon = const Color(0xFF7CC4F7),
    this.tombol,
    this.onTombol,
  });

  final IconData ikon;
  final Color warnaIkon;
  final String judul;
  final String keterangan;
  final String? tombol;
  final VoidCallback? onTombol;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 56, color: warnaIkon),
            const SizedBox(height: 12),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            if (tombol != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(150, 42)),
                onPressed: onTombol,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tombol!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hiasan samar di latar kartu jadwal.
class _HiasanKartu extends StatelessWidget {
  const _HiasanKartu();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              right: -40,
              bottom: -30,
              child: Icon(
                Icons.auto_stories_rounded,
                size: 220,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              left: -60,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.biru.withValues(alpha: 0.18),
                      AppColors.biru.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
