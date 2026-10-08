import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import 'loading_dots.dart';

/// Tombol utama selebar layar. Saat [sedangMemuat] true, teks diganti
/// animasi loading dan tombol tidak bisa ditekan.
class TombolUtama extends StatelessWidget {
  const TombolUtama({
    super.key,
    required this.teks,
    required this.onPressed,
    this.sedangMemuat = false,
    this.ikon,
  });

  final String teks;
  final VoidCallback? onPressed;
  final bool sedangMemuat;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: sedangMemuat ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: sedangMemuat
            ? const LoadingDots(
                ukuran: 9,
                warna: [AppColors.navy, Colors.white, AppColors.navy],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(teks),
                  if (ikon != null) ...[
                    const SizedBox(width: 8),
                    Icon(ikon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}
