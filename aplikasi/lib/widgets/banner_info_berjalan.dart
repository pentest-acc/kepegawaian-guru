import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/info_kegiatan.dart';
import '../utils/format_tanggal.dart';

/// Banner "Informasi Akademik" di Beranda.
///
/// Menampilkan beberapa info terbaru yang berganti otomatis dengan gerakan
/// ke ATAS setiap [jeda] (seperti banner film di situs streaming, tetapi
/// vertikal). Pengguna juga bisa menggeser banner ke atas/bawah sendiri.
class BannerInfoBerjalan extends StatefulWidget {
  const BannerInfoBerjalan({
    super.key,
    required this.daftar,
    required this.onTapInfo,
    this.sedangMemuat = false,
    this.pesanKosong = 'Belum ada info kegiatan terbaru.',
    this.onTapKosong,
    this.jeda = const Duration(seconds: 5),
  });

  final List<InfoKegiatan> daftar;
  final ValueChanged<InfoKegiatan> onTapInfo;
  final bool sedangMemuat;

  /// Teks yang tampil jika [daftar] kosong (belum ada info / gagal dimuat).
  final String pesanKosong;
  final VoidCallback? onTapKosong;

  /// Lama setiap info tampil sebelum berganti.
  final Duration jeda;

  static const double tinggi = 104;

  @override
  State<BannerInfoBerjalan> createState() => _BannerInfoBerjalanState();
}

class _BannerInfoBerjalanState extends State<BannerInfoBerjalan> {
  final _controller = PageController();
  Timer? _timer;
  int _halaman = 0;

  @override
  void initState() {
    super.initState();
    _mulaiTimer();
  }

  @override
  void didUpdateWidget(covariant BannerInfoBerjalan lama) {
    super.didUpdateWidget(lama);
    if (lama.daftar.length != widget.daftar.length) {
      // Data baru: kembali ke info pertama
      _halaman = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _mulaiTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _mulaiTimer() {
    _timer?.cancel();
    if (widget.daftar.length < 2) return;
    _timer = Timer.periodic(widget.jeda, (_) => _berikutnya());
  }

  void _berikutnya() {
    // Jangan bergerak saat halaman Beranda sedang tertutup halaman lain
    final halamanAktif = ModalRoute.of(context)?.isCurrent ?? true;
    if (!mounted || !_controller.hasClients || !halamanAktif) return;

    _controller.nextPage(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: AppColors.navy.withValues(alpha: 0.4),
      child: Ink(
        height: BannerInfoBerjalan.tinggi,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.gradasiBanner),
        ),
        child: CustomPaint(painter: _GelombangPainter(), child: _isi()),
      ),
    );
  }

  Widget _isi() {
    final daftar = widget.daftar;

    if (daftar.isEmpty) {
      return InkWell(
        onTap: widget.onTapKosong,
        child: _TeksBanner(
          atas: widget.sedangMemuat
              ? 'Memuat info terbaru...'
              : 'Info Kegiatan',
          judul: widget.sedangMemuat
              ? 'Info Kegiatan Yayasan'
              : widget.pesanKosong,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            // Tanpa itemCount = bisa bergulir terus (berputar ke info pertama)
            itemBuilder: (context, i) {
              final info = daftar[i % daftar.length];
              return InkWell(
                onTap: () => widget.onTapInfo(info),
                child: _TeksBanner(
                  atas:
                      '${info.kategori}  •  '
                      '${FormatTanggal.singkat(info.dibuatPada)}',
                  judul: info.judul,
                ),
              );
            },
            onPageChanged: (i) {
              setState(() => _halaman = i % daftar.length);
              _mulaiTimer(); // hitung ulang 5 detik setelah digeser manual
            },
          ),
        ),
        if (daftar.length > 1)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _TitikHalaman(jumlah: daftar.length, aktif: _halaman),
          ),
      ],
    );
  }
}

class _TeksBanner extends StatelessWidget {
  const _TeksBanner({required this.atas, required this.judul});

  final String atas;
  final String judul;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(
                Icons.campaign_rounded,
                size: 15,
                color: AppColors.mint,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  atas,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            judul,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik-titik penanda posisi info (tersusun ke bawah).
class _TitikHalaman extends StatelessWidget {
  const _TitikHalaman({required this.jumlah, required this.aktif});

  final int jumlah;
  final int aktif;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < jumlah; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            width: 6,
            height: i == aktif ? 16 : 6,
            decoration: BoxDecoration(
              color: i == aktif
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Gelombang pink-magenta di bagian bawah banner (seperti desain).
class _GelombangPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void gelombang(double dasar, double tinggi, List<Color> warna) {
      final path = Path()..moveTo(0, h * dasar);
      path.cubicTo(
        w * 0.25,
        h * (dasar - tinggi),
        w * 0.45,
        h * (dasar + tinggi),
        w * 0.7,
        h * dasar,
      );
      path.cubicTo(w * 0.85, h * (dasar - tinggi * 0.6), w * 0.95, h, w, h);
      path.lineTo(0, h);
      path.close();

      final cat = Paint()
        ..shader = LinearGradient(
          colors: warna,
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(path, cat);
    }

    gelombang(0.8, 0.14, const [Color(0x88E0217A), Color(0x44753BBD)]);
    gelombang(0.9, 0.1, const [Color(0xDDF0386B), Color(0x88B620E0)]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
