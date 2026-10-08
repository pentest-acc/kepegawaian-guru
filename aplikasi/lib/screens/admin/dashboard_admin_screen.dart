import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../models/pengguna.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_overlay.dart';

/// Halaman awal Admin (sementara).
///
/// Fitur admin (Dashboard, Data Guru, Kelola Info Kegiatan, dll.) akan
/// dibuat setelah semua fitur Guru selesai.
class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({
    super.key,
    required this.pengguna,
    this.authService,
  });

  final Pengguna pengguna;
  final AuthService? authService;

  static const List<(IconData, String)> _rencanaFitur = [
    (Icons.dashboard_rounded, 'Dashboard kehadiran hari ini'),
    (Icons.groups_rounded, 'Data Guru'),
    (Icons.campaign_rounded, 'Kelola Info Kegiatan'),
    (Icons.calendar_month_rounded, 'Kelola Jadwal Mengajar'),
    (Icons.fact_check_rounded, 'Monitoring Absensi'),
    (Icons.approval_rounded, 'Persetujuan Cuti'),
    (Icons.print_rounded, 'Laporan (PDF/Excel)'),
    (Icons.tune_rounded, 'Pengaturan Sistem'),
  ];

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();
  bool _sedangKeluar = false;

  Future<void> _keluar() async {
    setState(() => _sedangKeluar = true);
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      sedangMemuat: _sedangKeluar,
      teks: 'Sedang keluar...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin'),
          actions: [
            IconButton(
              tooltip: 'Keluar',
              onPressed: _keluar,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyTerang],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${widget.pengguna.namaLengkap}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.pengguna.jabatan,
                    style: const TextStyle(color: AppColors.mint, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fitur Admin yang akan dibuat:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final (ikon, nama) in DashboardAdminScreen._rencanaFitur)
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.garis),
                ),
                child: ListTile(
                  leading: Icon(ikon, color: AppColors.navyTerang),
                  title: Text(nama, style: const TextStyle(fontSize: 14)),
                  trailing: const Text(
                    'Segera',
                    style: TextStyle(fontSize: 11, color: AppColors.teksAbu),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
