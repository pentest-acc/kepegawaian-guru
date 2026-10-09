/// Kumpulan fungsi validasi untuk form (login, register, dll).
///
/// Setiap fungsi mengembalikan `null` jika isian benar, atau pesan
/// kesalahan jika salah. Aturan di sini disamakan dengan validasi di
/// backend (`backend/api/auth/register.php`).
class Validator {
  Validator._();

  static String? wajib(String? nilai, String namaKolom) {
    if (nilai == null || nilai.trim().isEmpty) {
      return '$namaKolom wajib diisi.';
    }
    return null;
  }

  static String? namaLengkap(String? nilai) {
    final teks = nilai?.trim() ?? '';
    if (teks.isEmpty) return 'Nama lengkap wajib diisi.';
    if (teks.length < 3) return 'Nama lengkap minimal 3 karakter.';
    if (teks.length > 100) return 'Nama lengkap maksimal 100 karakter.';
    if (teks.contains(',')) {
      return 'Tulis nama tanpa gelar. Gelar dipilih di kolom Gelar.';
    }
    return null;
  }

  static String? nomorInduk(String? nilai) {
    final teks = nilai?.trim() ?? '';
    if (teks.isEmpty) return 'Nomor Induk Yayasan wajib diisi.';
    if (!RegExp(r'^[0-9A-Za-z.\-]{4,30}$').hasMatch(teks)) {
      return 'Nomor Induk Yayasan 4-30 karakter (angka/huruf).';
    }
    return null;
  }

  static String? email(String? nilai) {
    final teks = nilai?.trim() ?? '';
    if (teks.isEmpty) return 'Email wajib diisi.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(teks)) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  static String? noHp(String? nilai) {
    final teks = (nilai ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (teks.isEmpty) return 'Nomor HP wajib diisi.';
    if (!RegExp(r'^(\+62|62|0)8[0-9]{7,12}$').hasMatch(teks)) {
      return 'Nomor HP tidak valid. Contoh: 081234567890.';
    }
    return null;
  }

  static String? kataSandi(String? nilai) {
    if (nilai == null || nilai.isEmpty) return 'Kata sandi wajib diisi.';
    if (nilai.length < 6) return 'Kata sandi minimal 6 karakter.';
    return null;
  }

  static String? konfirmasiKataSandi(String? nilai, String kataSandiAsli) {
    if (nilai == null || nilai.isEmpty) {
      return 'Ulangi kata sandi.';
    }
    if (nilai != kataSandiAsli) return 'Konfirmasi kata sandi tidak sama.';
    return null;
  }
}
