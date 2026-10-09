import 'package:flutter_test/flutter_test.dart';
import 'package:kepegawaian_guru/utils/validator.dart';

void main() {
  group('Validator.email', () {
    test('menolak isian kosong dan format salah', () {
      expect(Validator.email(''), isNotNull);
      expect(Validator.email('guru'), isNotNull);
      expect(Validator.email('guru@sekolah'), isNotNull);
    });

    test('menerima email yang benar', () {
      expect(Validator.email('guru@sekolah.sch.id'), isNull);
      expect(Validator.email('  guru@contoh.test  '), isNull);
    });
  });

  group('Validator.noHp', () {
    test('menerima format nomor Indonesia', () {
      expect(Validator.noHp('081234567890'), isNull);
      expect(Validator.noHp('0812-3456-7890'), isNull);
      expect(Validator.noHp('+6281234567890'), isNull);
      expect(Validator.noHp('6281234567890'), isNull);
    });

    test('menolak nomor yang salah', () {
      expect(Validator.noHp(''), isNotNull);
      expect(Validator.noHp('12345'), isNotNull);
      expect(Validator.noHp('0212345678'), isNotNull);
    });
  });

  group('Validator.nomorInduk', () {
    test('4-30 karakter angka/huruf', () {
      expect(Validator.nomorInduk('12345678910'), isNull);
      expect(Validator.nomorInduk('ADM001'), isNull);
      expect(Validator.nomorInduk('123'), isNotNull);
      expect(Validator.nomorInduk('12 34'), isNotNull);
    });
  });

  group('Validator kata sandi', () {
    test('minimal 6 karakter', () {
      expect(Validator.kataSandi('12345'), isNotNull);
      expect(Validator.kataSandi('123456'), isNull);
    });

    test('konfirmasi harus sama', () {
      expect(Validator.konfirmasiKataSandi('abcdef', 'abcdeg'), isNotNull);
      expect(Validator.konfirmasiKataSandi('abcdef', 'abcdef'), isNull);
      expect(Validator.konfirmasiKataSandi('', 'abcdef'), isNotNull);
    });
  });

  test('Validator.namaLengkap', () {
    expect(Validator.namaLengkap('Al'), isNotNull);
    expect(Validator.namaLengkap('Siti Aminah'), isNull);
    // Gelar tidak boleh ditulis di kolom nama
    expect(Validator.namaLengkap('Siti Aminah, S.Pd.'), isNotNull);
  });
}
