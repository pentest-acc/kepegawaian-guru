import 'package:intl/intl.dart';

/// Format tanggal dalam Bahasa Indonesia.
///
/// Membutuhkan `initializeDateFormatting('id_ID')` yang sudah dipanggil
/// di `main.dart`.
class FormatTanggal {
  FormatTanggal._();

  /// Minggu, 04-10-2026
  static String hariAngka(DateTime t) =>
      DateFormat('EEEE, dd-MM-yyyy', 'id_ID').format(t);

  /// Minggu, 4 Oktober 2026
  static String panjang(DateTime t) =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(t);

  /// Min, 4 Okt 2026
  static String singkat(DateTime t) =>
      DateFormat('EEE, d MMM yyyy', 'id_ID').format(t);

  /// 07.30
  static String jam(DateTime t) => DateFormat('HH.mm', 'id_ID').format(t);
}
