/// Data pengguna (Guru / Admin) sesuai tabel `pengguna` di database.
class Pengguna {
  const Pengguna({
    required this.idPengguna,
    required this.nomorInduk,
    required this.namaLengkap,
    required this.email,
    required this.role,
    required this.jabatan,
    required this.status,
    this.gelar,
    this.noHp,
    this.unit,
    this.jenisKelamin,
    this.tempatLahir,
    this.tanggalLahir,
    this.alamat,
    this.foto,
    this.notifikasiAktif = true,
  });

  final int idPengguna;
  final String nomorInduk;

  /// Nama tanpa gelar, mis. "Siti Aminah".
  final String namaLengkap;

  /// Gelar akademik, mis. "S.Pd." atau "Drs." (null jika tanpa gelar).
  final String? gelar;
  final String email;
  final String? noHp;

  /// `guru` atau `admin`
  final String role;
  final String jabatan;

  /// `KB`, `TK`, atau `SD` (null untuk admin)
  final String? unit;

  /// `L` atau `P`
  final String? jenisKelamin;
  final String? tempatLahir;
  final String? tanggalLahir;
  final String? alamat;
  final String? foto;
  final bool notifikasiAktif;

  /// `aktif` atau `nonaktif`
  final String status;

  bool get isAdmin => role == 'admin';

  /// Gelar yang ditulis di DEPAN nama (gelar lainnya ditulis di belakang).
  static const Set<String> gelarDepan = {
    'Dr.',
    'Drs.',
    'Dra.',
    'Ir.',
    'H.',
    'Hj.',
  };

  /// Nama lengkap beserta gelar untuk ditampilkan,
  /// mis. "Siti Aminah, S.Pd." atau "Drs. Budi Santoso".
  String get namaTampil {
    final g = gelar?.trim() ?? '';
    if (g.isEmpty) return namaLengkap;
    if (gelarDepan.contains(g)) return '$g $namaLengkap';
    return '$namaLengkap, $g';
  }

  /// Nama depan untuk sapaan, contoh: "Siti Aminah" -> "Siti".
  String get namaDepan {
    final bersih = namaLengkap.split(',').first.trim();
    return bersih.isEmpty ? namaLengkap : bersih.split(RegExp(r'\s+')).first;
  }

  /// Dua huruf awal nama untuk avatar, contoh: "Siti Aminah" -> "SA".
  String get inisial {
    final kata = namaLengkap
        .split(',')
        .first
        .trim()
        .split(RegExp(r'\s+'))
        .where((k) => k.isNotEmpty)
        .toList();
    if (kata.isEmpty) return '?';
    if (kata.length == 1) return kata.first[0].toUpperCase();
    return (kata[0][0] + kata[1][0]).toUpperCase();
  }

  factory Pengguna.fromJson(Map<String, dynamic> json) {
    String? teksAtauNull(String kunci) {
      final nilai = json[kunci];
      if (nilai == null) return null;
      final teks = nilai.toString();
      return teks.isEmpty ? null : teks;
    }

    final notif = json['notifikasi_aktif'];

    return Pengguna(
      idPengguna: int.parse(json['id_pengguna'].toString()),
      nomorInduk: json['nomor_induk'].toString(),
      namaLengkap: json['nama_lengkap'].toString(),
      gelar: teksAtauNull('gelar'),
      email: json['email'].toString(),
      noHp: teksAtauNull('no_hp'),
      role: teksAtauNull('role') ?? 'guru',
      jabatan: teksAtauNull('jabatan') ?? 'Guru',
      unit: teksAtauNull('unit'),
      jenisKelamin: teksAtauNull('jenis_kelamin'),
      tempatLahir: teksAtauNull('tempat_lahir'),
      tanggalLahir: teksAtauNull('tanggal_lahir'),
      alamat: teksAtauNull('alamat'),
      foto: teksAtauNull('foto'),
      notifikasiAktif: notif == true || notif == 1 || notif == '1',
      status: teksAtauNull('status') ?? 'aktif',
    );
  }

  Map<String, dynamic> toJson() => {
    'id_pengguna': idPengguna,
    'nomor_induk': nomorInduk,
    'nama_lengkap': namaLengkap,
    'gelar': gelar,
    'email': email,
    'no_hp': noHp,
    'role': role,
    'jabatan': jabatan,
    'unit': unit,
    'jenis_kelamin': jenisKelamin,
    'tempat_lahir': tempatLahir,
    'tanggal_lahir': tanggalLahir,
    'alamat': alamat,
    'foto': foto,
    'notifikasi_aktif': notifikasiAktif,
    'status': status,
  };
}
