import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../models/info_kegiatan.dart';
import '../../models/pengguna.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/info_service.dart';
import '../../utils/pesan.dart';
import '../../widgets/avatar_pengguna.dart';
import '../../widgets/banner_info_berjalan.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/logo_yayasan.dart';
import '../umum/segera_hadir_screen.dart';
import 'info_detail_screen.dart';
import 'info_kegiatan_screen.dart';

/// Data satu tombol menu di Beranda.
class MenuBeranda {
  const MenuBeranda(this.judul, this.ikon, this.warna);

  final String judul;
  final IconData ikon;
  final List<Color> warna;
}

/// Halaman utama (Beranda) untuk Guru.
class BerandaScreen extends StatefulWidget {
  const BerandaScreen({
    super.key,
    required this.pengguna,
    this.authService,
    this.infoService,
  });

  final Pengguna pengguna;
  final AuthService? authService;
  final InfoService? infoService;

  /// Menu sesuai daftar fitur di Project Charter (Tampilan Guru).
  static const List<MenuBeranda> daftarMenu = [
    MenuBeranda('Info Kegiatan', Icons.campaign_rounded, [
      Color(0xFF6CBFFF),
      Color(0xFF2F86DE),
    ]),
    MenuBeranda('Jadwal Mengajar', Icons.calendar_month_rounded, [
      Color(0xFFFFA59C),
      Color(0xFFEF6B6B),
    ]),
    MenuBeranda('Absen', Icons.fact_check_rounded, [
      Color(0xFF6AD6B4),
      Color(0xFF2E9E80),
    ]),
    MenuBeranda('Riwayat Absen', Icons.manage_history_rounded, [
      Color(0xFFA899FF),
      Color(0xFF6C5CE7),
    ]),
    MenuBeranda('Cuti / Izin', Icons.beach_access_rounded, [
      Color(0xFFFFD66E),
      Color(0xFFF2A516),
    ]),
    MenuBeranda('Pengaturan', Icons.settings_rounded, [
      Color(0xFFC3CEDB),
      Color(0xFF8796A8),
    ]),
    MenuBeranda('Profil', Icons.person_rounded, [
      Color(0xFF7FCBFF),
      Color(0xFF3D7BF5),
    ]),
  ];

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  late Pengguna _pengguna = widget.pengguna;
  late final AuthService _auth = widget.authService ?? AuthService();
  late final InfoService _infoService = widget.infoService ?? InfoService();
  bool _sedangKeluar = false;

  /// 5 info kegiatan terbaru untuk banner "Informasi Akademik".
  List<InfoKegiatan> _infoTerbaru = const [];
  bool _memuatInfo = true;
  String _pesanInfo = 'Belum ada info kegiatan terbaru.';

  @override
  void initState() {
    super.initState();
    _muatInfo();
  }

  Future<void> _muatInfo() async {
    try {
      final hasil = await _infoService.daftar(batas: 5);
      if (!mounted) return;
      setState(() {
        _infoTerbaru = hasil;
        _memuatInfo = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _memuatInfo = false;
        _pesanInfo = e.tidakAdaKoneksi
            ? 'Info belum bisa dimuat. Tarik layar ke bawah untuk mencoba lagi.'
            : e.pesan;
      });
    }
  }

  /// Tarik layar ke bawah untuk memuat ulang data profil & info terbaru.
  Future<void> _muatUlang() async {
    _muatInfo();
    final terbaru = await _auth.cekSesi();
    if (!mounted) return;
    if (terbaru == null) {
      tampilkanPesan(
        context,
        'Sesi berakhir. Silakan login kembali.',
        gagal: true,
      );
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      return;
    }
    setState(() => _pengguna = terbaru);
  }

  Future<void> _konfirmasiKeluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.merah,
          size: 36,
        ),
        title: const Text('Keluar dari Aplikasi?'),
        content: const Text(
          'Anda perlu login kembali untuk menggunakan aplikasi.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.merah,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _sedangKeluar = true);
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _bukaInfoKegiatan() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InfoKegiatanScreen(infoService: _infoService),
      ),
    );
    _muatInfo(); // siapa tahu ada info baru
  }

  void _bukaDetailInfo(InfoKegiatan info) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InfoDetailScreen(info: info, infoService: _infoService),
      ),
    );
  }

  void _bukaMenu(MenuBeranda menu) {
    if (menu.judul == 'Info Kegiatan') {
      _bukaInfoKegiatan();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SegeraHadirScreen(
          judul: menu.judul,
          ikon: menu.ikon,
          warna: menu.warna,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: LoadingOverlay(
        sedangMemuat: _sedangKeluar,
        teks: 'Sedang keluar...',
        child: Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            color: AppColors.navy,
            onRefresh: _muatUlang,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _HeaderBeranda(
                  pengguna: _pengguna,
                  onKeluar: _konfirmasiKeluar,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _KartuIdentitas(pengguna: _pengguna),
                      const SizedBox(height: 26),
                      _JudulBagian(
                        'Informasi Akademik',
                        aksi: 'Selengkapnya',
                        onAksi: _bukaInfoKegiatan,
                      ),
                      BannerInfoBerjalan(
                        daftar: _infoTerbaru,
                        sedangMemuat: _memuatInfo,
                        pesanKosong: _pesanInfo,
                        onTapInfo: _bukaDetailInfo,
                        onTapKosong: _bukaInfoKegiatan,
                      ),
                      const SizedBox(height: 26),
                      const _JudulBagian('Menu Lainnya'),
                      _GridMenu(
                        daftar: BerandaScreen.daftarMenu,
                        onTap: _bukaMenu,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: foto sekolah + logo + foto profil + sapaan
// ---------------------------------------------------------------------------

class _HeaderBeranda extends StatelessWidget {
  const _HeaderBeranda({required this.pengguna, required this.onKeluar});

  final Pengguna pengguna;
  final VoidCallback onKeluar;

  static const double _tinggiFoto = 190;

  String _sapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat Pagi';
    if (jam < 15) return 'Selamat Siang';
    if (jam < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.paddingOf(context).top;
    final tanggal = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(DateTime.now());

    return SizedBox(
      height: atas + _tinggiFoto + 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: atas + _tinggiFoto,
            child: const _FotoSekolah(),
          ),
          Positioned(
            top: atas + 12,
            left: 16,
            child: const LogoYayasan(ukuran: 52),
          ),
          Positioned(
            top: atas + 14,
            right: 16,
            child: Material(
              color: Colors.black.withValues(alpha: 0.3),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Keluar',
                onPressed: onKeluar,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: atas + _tinggiFoto - 54,
            left: 20,
            child: AvatarPengguna(pengguna: pengguna),
          ),
          Positioned(
            top: atas + _tinggiFoto + 8,
            left: 110,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_sapaan()}, ${pengguna.namaDepan}!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teks,
                  ),
                ),
                Text(
                  tanggal,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.teksAbu,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto bersama Yayasan (`assets/images/header_sekolah.jpg`).
/// Jika file tidak ada, diganti latar gradasi dengan nama Yayasan.
class _FotoSekolah extends StatelessWidget {
  const _FotoSekolah();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/header_sekolah.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, 0.15),
          errorBuilder: (context, error, stackTrace) =>
              const _LatarPenggantiFoto(),
        ),
        // Filter: rona navy tipis agar warna foto senada dengan aplikasi,
        // lebih gelap di bagian atas supaya logo & tombol tetap jelas,
        // dan memudar ke putih di bagian bawah (menyatu dengan halaman).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99140B2D),
                Color(0x26140B2D),
                Color(0x14140B2D),
                Color(0xB3FFFFFF),
              ],
              stops: [0, 0.38, 0.72, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _LatarPenggantiFoto extends StatelessWidget {
  const _LatarPenggantiFoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyTerang, Color(0xFF2C6FB0)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: Icon(
              Icons.groups_rounded,
              size: 200,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Align(
            alignment: const Alignment(0.55, 0.15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KB / TK / SD',
                  style: TextStyle(
                    color: AppColors.mint.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const Text(
                  'TIARA HARAPAN JAYA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu identitas hijau: Nama, Nomor Induk Yayasan, Jabatan
// ---------------------------------------------------------------------------

class _KartuIdentitas extends StatelessWidget {
  const _KartuIdentitas({required this.pengguna});

  final Pengguna pengguna;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradasiKartu,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B7220).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: _PolaKartuPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BarisKartu(label: 'Nama', nilai: pengguna.namaTampil),
                const SizedBox(height: 12),
                _BarisKartu(
                  label: 'Nomor Induk Yayasan',
                  nilai: pengguna.nomorInduk,
                ),
                const SizedBox(height: 12),
                _BarisKartu(label: 'Jabatan', nilai: pengguna.jabatan),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarisKartu extends StatelessWidget {
  const _BarisKartu({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            nilai,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bidang-bidang miring transparan sebagai hiasan kartu (seperti desain).
class _PolaKartuPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.55, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h * 0.55)
        ..close(),
      cat,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.35, h)
        ..lineTo(w * 0.85, h * 0.25)
        ..lineTo(w, h * 0.45)
        ..lineTo(w, h)
        ..close(),
      cat,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.7)
        ..lineTo(w * 0.25, h)
        ..lineTo(0, h)
        ..close(),
      cat,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Judul bagian + banner Informasi Akademik
// ---------------------------------------------------------------------------

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.judul, {this.aksi, this.onAksi});

  final String judul;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              judul,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.teks,
              ),
            ),
          ),
          if (aksi != null)
            InkWell(
              onTap: onAksi,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  aksi!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.teksAbu,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid menu: 4 per baris, baris terakhir di tengah (seperti desain)
// ---------------------------------------------------------------------------

class _GridMenu extends StatelessWidget {
  const _GridMenu({required this.daftar, required this.onTap});

  final List<MenuBeranda> daftar;
  final ValueChanged<MenuBeranda> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const jarak = 8.0;
        final lebarItem = (constraints.maxWidth - jarak * 3) / 4;

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: jarak,
          runSpacing: 16,
          children: [
            for (final menu in daftar)
              SizedBox(
                width: lebarItem,
                child: _ItemMenu(menu: menu, onTap: () => onTap(menu)),
              ),
          ],
        );
      },
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.menu, required this.onTap});

  final MenuBeranda menu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: menu.warna,
                ),
                boxShadow: [
                  BoxShadow(
                    color: menu.warna.last.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(menu.ikon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              menu.judul,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.teks,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
