import 'package:flutter/material.dart';

import '../models/pengguna.dart';
import '../screens/admin/dashboard_admin_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/guru/beranda_screen.dart';
import '../screens/splash/splash_screen.dart';

/// Daftar nama halaman (route) dan cara membukanya.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String beranda = '/beranda';
  static const String dashboardAdmin = '/admin';

  /// Halaman pertama setelah login, tergantung role pengguna.
  static String halamanUtama(Pengguna pengguna) =>
      pengguna.isAdmin ? dashboardAdmin : beranda;

  static Route<dynamic> buatRoute(RouteSettings settings) {
    final argumen = settings.arguments;

    switch (settings.name) {
      case login:
        return _transisiPudar(
          settings,
          LoginScreen(identitasAwal: argumen is String ? argumen : null),
        );
      case register:
        // RegisterScreen mengembalikan email (String) ke halaman Login
        return _transisiGeser<String>(settings, const RegisterScreen());
      case beranda:
        if (argumen is Pengguna) {
          return _transisiPudar(settings, BerandaScreen(pengguna: argumen));
        }
        break;
      case dashboardAdmin:
        if (argumen is Pengguna) {
          return _transisiPudar(
            settings,
            DashboardAdminScreen(pengguna: argumen),
          );
        }
        break;
    }

    // Route tidak dikenal / data pengguna tidak ada -> mulai dari splash
    // (splash akan mengecek sesi login lagi).
    return _transisiPudar(
      const RouteSettings(name: splash),
      const SplashScreen(),
    );
  }

  static Route<T> _transisiPudar<T>(RouteSettings settings, Widget hal) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) => hal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static Route<T> _transisiGeser<T>(RouteSettings settings, Widget hal) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => hal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final geser = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(geser), child: child);
      },
    );
  }
}
