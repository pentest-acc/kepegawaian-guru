import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Tema (gaya tampilan) yang dipakai di seluruh aplikasi.
class AppTheme {
  AppTheme._();

  static const String font = 'Poppins';

  static ThemeData get terang {
    final skemaWarna = ColorScheme.fromSeed(
      seedColor: AppColors.biru,
      primary: AppColors.biru,
      onPrimary: AppColors.navy,
      secondary: AppColors.mint,
      onSecondary: AppColors.navy,
      surface: Colors.white,
      onSurface: AppColors.teks,
      error: AppColors.merah,
    );

    final bentukTombol = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    OutlineInputBorder garisInput(Color warna, [double tebal = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: warna, width: tebal),
      );
    }

    return ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: skemaWarna,
      scaffoldBackgroundColor: AppColors.putih,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.header,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.biru,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: AppColors.biru.withValues(alpha: 0.6),
          disabledForegroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(52),
          shape: bentukTombol,
          textStyle: const TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF2B7BC4),
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.isian,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.teksAbu, fontSize: 14),
        prefixIconColor: AppColors.teksAbu,
        suffixIconColor: AppColors.teksAbu,
        border: garisInput(Colors.transparent),
        enabledBorder: garisInput(Colors.transparent),
        focusedBorder: garisInput(AppColors.biru, 1.5),
        errorBorder: garisInput(AppColors.merah),
        focusedErrorBorder: garisInput(AppColors.merah, 1.5),
        errorStyle: const TextStyle(fontSize: 12),
        errorMaxLines: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          fontFamily: font,
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: font,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.teks,
        ),
      ),
    );
  }
}
