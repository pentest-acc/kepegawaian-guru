import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import 'loading_dots.dart';

/// Menutupi layar dengan animasi loading saat [sedangMemuat] bernilai true,
/// sehingga pengguna tidak bisa menekan tombol dua kali.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.sedangMemuat,
    required this.child,
    this.teks = 'Mohon tunggu...',
  });

  final bool sedangMemuat;
  final Widget child;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          ignoring: !sedangMemuat,
          child: AnimatedOpacity(
            opacity: sedangMemuat ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            // Material diperlukan agar teks di atas overlay memakai gaya
            // tema (tanpa Material, Flutter menampilkan garis bawah kuning).
            child: Material(
              color: AppColors.navy.withValues(alpha: 0.45),
              child: Center(
                child: sedangMemuat ? _KartuLoading(teks: teks) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KartuLoading extends StatelessWidget {
  const _KartuLoading({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoadingDots(
            warna: [AppColors.biru, AppColors.mint, AppColors.navy],
          ),
          const SizedBox(height: 14),
          Text(
            teks,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.teks,
            ),
          ),
        ],
      ),
    );
  }
}
