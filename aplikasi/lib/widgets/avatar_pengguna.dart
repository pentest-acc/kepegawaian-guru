import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/pengguna.dart';

/// Foto profil pengguna. Selama fitur unggah foto belum dibuat,
/// yang tampil adalah inisial nama.
class AvatarPengguna extends StatelessWidget {
  const AvatarPengguna({
    super.key,
    required this.pengguna,
    this.lebar = 76,
    this.tinggi = 88,
  });

  final Pengguna pengguna;
  final double lebar;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lebar,
      height: tinggi,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.biru, AppColors.navyTerang],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        pengguna.inisial,
        style: TextStyle(
          color: Colors.white,
          fontSize: lebar * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
