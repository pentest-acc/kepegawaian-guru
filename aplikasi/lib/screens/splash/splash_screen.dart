import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../models/pengguna.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/logo_yayasan.dart';

/// Halaman pembuka dengan animasi loading.
///
/// Sambil animasi berjalan, aplikasi mengecek apakah guru masih login.
/// - Masih login  -> langsung ke Beranda (atau Dashboard Admin)
/// - Belum login  -> ke halaman Login
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.authService,
    this.durasiMinimal = const Duration(milliseconds: 2600),
  });

  final AuthService? authService;

  /// Lama minimal splash tampil, supaya animasinya sempat terlihat.
  final Duration durasiMinimal;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animasi = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Logo membesar dengan efek memantul
  late final Animation<double> _skalaLogo = CurvedAnimation(
    parent: _animasi,
    curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
  );

  // Teks muncul perlahan sambil naik sedikit
  late final Animation<double> _munculTeks = CurvedAnimation(
    parent: _animasi,
    curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
  );

  // Animasi loading muncul paling akhir
  late final Animation<double> _munculLoading = CurvedAnimation(
    parent: _animasi,
    curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
  );

  late final AuthService _auth = widget.authService ?? AuthService();

  @override
  void initState() {
    super.initState();
    _animasi.forward();
    _mulai();
  }

  Future<void> _mulai() async {
    final hasil = await Future.wait<Object?>([
      _auth.cekSesi(),
      Future<void>.delayed(widget.durasiMinimal),
    ]);
    if (!mounted) return;

    final pengguna = hasil.first as Pengguna?;
    if (pengguna == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    } else {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.halamanUtama(pengguna),
        arguments: pengguna,
      );
    }
  }

  @override
  void dispose() {
    _animasi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Stack(
          children: [
            // Lingkaran dekorasi di latar belakang
            const Positioned(
              top: -90,
              right: -70,
              child: _Lingkaran(ukuran: 260, warna: AppColors.biru),
            ),
            const Positioned(
              bottom: -110,
              left: -80,
              child: _Lingkaran(ukuran: 300, warna: AppColors.mint),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _skalaLogo,
                    child: const LogoYayasan(ukuran: 110),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _munculTeks,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_munculTeks),
                      child: const Column(
                        children: [
                          Text(
                            'Kepegawaian Guru',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Yayasan Tiara Harapan Jaya',
                            style: TextStyle(
                              color: AppColors.mint,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _munculLoading,
                    child: const LoadingDots(),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: FadeTransition(
                opacity: _munculTeks,
                child: Text(
                  'KB  •  TK  •  SD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 2,
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

class _Lingkaran extends StatelessWidget {
  const _Lingkaran({required this.ukuran, required this.warna});

  final double ukuran;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [warna.withValues(alpha: 0.35), warna.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
