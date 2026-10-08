import 'package:flutter_test/flutter_test.dart';
import 'package:kepegawaian_guru/models/pengguna.dart';

import '../helpers.dart';

void main() {
  test('fromJson membaca data dari backend', () {
    final p = Pengguna.fromJson(jsonGuruContoh);

    expect(p.idPengguna, 2);
    expect(p.nomorInduk, '12345678910');
    expect(p.namaLengkap, 'Guru Contoh, S.Pd.');
    expect(p.unit, 'SD');
    expect(p.isAdmin, isFalse);
    expect(p.notifikasiAktif, isTrue);
    expect(p.foto, isNull);
  });

  test('fromJson tahan terhadap angka berbentuk teks', () {
    final p = Pengguna.fromJson({
      ...jsonGuruContoh,
      'id_pengguna': '7',
      'notifikasi_aktif': '0',
      'role': 'admin',
      'unit': '',
    });

    expect(p.idPengguna, 7);
    expect(p.notifikasiAktif, isFalse);
    expect(p.isAdmin, isTrue);
    expect(p.unit, isNull);
  });

  test('toJson lalu fromJson menghasilkan data yang sama', () {
    final asli = Pengguna.fromJson(jsonGuruContoh);
    final salinan = Pengguna.fromJson(asli.toJson());

    expect(salinan.toJson(), asli.toJson());
  });

  test('namaDepan dan inisial', () {
    final p = Pengguna.fromJson(jsonGuruContoh);
    expect(p.namaDepan, 'Guru');
    expect(p.inisial, 'GC');

    final satuKata = Pengguna.fromJson({
      ...jsonGuruContoh,
      'nama_lengkap': 'budi',
    });
    expect(satuKata.inisial, 'B');
  });
}
