import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Animasi loading berupa tiga titik yang memantul bergantian.
///
/// Dipakai di splash screen, tombol yang sedang memproses, dan
/// overlay loading.
class LoadingDots extends StatefulWidget {
  const LoadingDots({
    super.key,
    this.ukuran = 12,
    this.warna = const [AppColors.biru, AppColors.mint, Colors.white],
  });

  /// Diameter setiap titik.
  final double ukuran;

  /// Warna titik pertama, kedua, dan ketiga.
  final List<Color> warna;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tinggiLompatan = widget.ukuran * 0.9;

    return SizedBox(
      height: widget.ukuran + tinggiLompatan,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              // Setiap titik bergerak dengan jeda 0.15 dari titik sebelumnya.
              final t = (_controller.value - i * 0.15) % 1.0;
              final naik = t < 0.5 ? math.sin(t * 2 * math.pi) : 0.0;
              final skala = 0.75 + 0.25 * naik;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.ukuran * 0.3),
                child: Transform.translate(
                  offset: Offset(0, -tinggiLompatan * naik),
                  child: Transform.scale(
                    scale: skala,
                    child: Container(
                      width: widget.ukuran,
                      height: widget.ukuran,
                      decoration: BoxDecoration(
                        color: widget.warna[i % widget.warna.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
