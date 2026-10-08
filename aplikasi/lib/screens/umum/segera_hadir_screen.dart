import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

/// Halaman sementara untuk fitur yang belum dibuat.
/// Akan diganti satu per satu pada sesi pengembangan berikutnya.
class SegeraHadirScreen extends StatelessWidget {
  const SegeraHadirScreen({
    super.key,
    required this.judul,
    required this.ikon,
    this.warna = const [AppColors.biru, AppColors.navyTerang],
  });

  final String judul;
  final IconData ikon;
  final List<Color> warna;

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
        title: Text(judul),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: warna,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: warna.last.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(ikon, color: Colors.white, size: 54),
              ),
              const SizedBox(height: 28),
              Text(
                'Fitur $judul',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teks,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sedang dalam tahap pengembangan dan akan tersedia '
                'pada pembaruan berikutnya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.teksAbu,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
