/// File lampiran pada info kegiatan (mis. PDF jadwal).
class LampiranInfo {
  const LampiranInfo({required this.nama, required this.url});

  final String nama;
  final String url;

  factory LampiranInfo.fromJson(Map<String, dynamic> json) =>
      LampiranInfo(nama: json['nama'].toString(), url: json['url'].toString());
}

/// Data satu info kegiatan, sesuai tabel `info_kegiatan` di database.
class InfoKegiatan {
  const InfoKegiatan({
    required this.idInfo,
    required this.judul,
    required this.isi,
    required this.kategori,
    required this.tanggalKegiatan,
    required this.dibuatPada,
    this.lampiran,
    this.penting = false,
  });

  final int idInfo;
  final String judul;
  final String isi;

  /// Pengumuman, Rapat, Acara, Libur, atau Lainnya.
  final String kategori;

  /// Tanggal kegiatan berlangsung.
  final DateTime tanggalKegiatan;

  /// Waktu info dibuat/diumumkan oleh admin.
  final DateTime dibuatPada;

  final LampiranInfo? lampiran;

  /// true jika guru menandai info ini dengan bintang.
  final bool penting;

  InfoKegiatan copyWith({bool? penting}) => InfoKegiatan(
    idInfo: idInfo,
    judul: judul,
    isi: isi,
    kategori: kategori,
    tanggalKegiatan: tanggalKegiatan,
    dibuatPada: dibuatPada,
    lampiran: lampiran,
    penting: penting ?? this.penting,
  );

  factory InfoKegiatan.fromJson(Map<String, dynamic> json) {
    final lampiran = json['lampiran'];
    final penting = json['penting'];

    return InfoKegiatan(
      idInfo: int.parse(json['id_info'].toString()),
      judul: json['judul'].toString(),
      isi: json['isi']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? 'Lainnya',
      tanggalKegiatan: DateTime.parse(json['tanggal_kegiatan'].toString()),
      dibuatPada: DateTime.parse(json['dibuat_pada'].toString()),
      lampiran: lampiran is Map<String, dynamic>
          ? LampiranInfo.fromJson(lampiran)
          : null,
      penting: penting == true || penting == 1 || penting == '1',
    );
  }
}
