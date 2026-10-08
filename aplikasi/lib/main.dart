import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_colors.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supaya nama hari & bulan tampil dalam Bahasa Indonesia (Senin, Oktober...)
  await initializeDateFormatting('id_ID');
  runApp(const AplikasiKepegawaian());
}

class AplikasiKepegawaian extends StatelessWidget {
  const AplikasiKepegawaian({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kepegawaian Guru',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.terang,
      // Aplikasi selalu dimulai dari splash screen (cek sesi login dulu)
      onGenerateInitialRoutes: (_) => [
        AppRoutes.buatRoute(const RouteSettings(name: AppRoutes.splash)),
      ],
      onGenerateRoute: AppRoutes.buatRoute,
      builder: (context, child) => _BatasiLebar(child: child!),
    );
  }
}

/// Saat dibuka di browser laptop (layar lebar), tampilan aplikasi dibuat
/// selebar HP di tengah layar supaya sama seperti di Android.
class _BatasiLebar extends StatelessWidget {
  const _BatasiLebar({required this.child});

  final Widget child;

  static const double lebarMaksimal = 440;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= lebarMaksimal + 40) return child;

    return ColoredBox(
      color: AppColors.latarLuar,
      child: Center(
        child: Container(
          width: lebarMaksimal,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
              ),
            ],
          ),
          child: MediaQuery(
            data: media.copyWith(size: Size(lebarMaksimal, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
