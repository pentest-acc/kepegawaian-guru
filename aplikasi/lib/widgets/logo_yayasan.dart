import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Logo Yayasan dalam kotak putih bersudut bulat.
///
/// Memakai file `assets/images/logo_yayasan.png`. Jika file belum ada,
/// otomatis diganti ikon sekolah.
class LogoYayasan extends StatelessWidget {
  const LogoYayasan({super.key, this.ukuran = 56});

  final double ukuran;

  static const String lokasiFile = 'assets/images/logo_yayasan.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      padding: EdgeInsets.all(ukuran * 0.1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ukuran * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        lokasiFile,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.school_rounded,
          size: ukuran * 0.6,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
