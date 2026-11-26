import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/absensi.dart';
import '../../services/absen_service.dart';
import '../../services/api_service.dart';
import '../../services/perangkat_absen.dart';
import '../../utils/format_tanggal.dart';
import '../../utils/pesan.dart';
import '../../widgets/chip_kehadiran.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/tombol_utama.dart';
import 'kamera_absen_screen.dart';
import 'riwayat_absen_screen.dart';

/// Halaman Absen guru: absen PER MATA PELAJARAN.
///
/// - Daftar mapel hari ini diambil dari jadwal mengajar guru. Setiap mapel
///   diabsen sekali (2 mapel = 2 kali absen).
/// - Jam masuk mengikuti mapel pertama; guru boleh pulang setelah mapel
///   terakhir selesai.
/// - Absen sebuah mapel dibuka sebelum jam mulai dan tetap bisa dilakukan
///   walaupun sudah terlambat atau mapelnya sudah selesai (admin melihat
///   tandanya).
/// - Absen: "Absen" -> kamera langsung -> lokasi saat foto diambil dicek ke
///   lokasi absen terdekat -> "Kirim Absen".
///
/// Jam yang dipakai adalah jam SERVER, bukan jam HP.
class AbsenScreen extends StatefulWidget {
  const AbsenScreen({
    super.key,
    this.absenService,
    this.kamera,
    this.lokasi,
    this.sekarang,
  });

  final AbsenService? absenService;
  final KameraAbsen? kamera;
  final LokasiPerangkat? lokasi;

  /// Jam perangkat (bisa diganti saat pengujian).
  final DateTime Function()? sekarang;

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  late final AbsenService _service = widget.absenService ?? AbsenService();
  late final KameraAbsen _kamera = widget.kamera ?? const KameraAbsen();
  late final LokasiPerangkat _lokasi = widget.lokasi ?? const LokasiPerangkat();

  InfoAbsenHariIni? _info;
  bool _sedangMemuat = true;
  String? _pesanGagal;

  /// Selisih jam server dengan jam perangkat.
  Duration _selisihServer = Duration.zero;
  Timer? _detak;

  // Absen yang sedang disiapkan (belum dikirim)
  int? _indeksMapel;
  FotoAbsen? _foto;
  PosisiAbsen? _posisi;
  LokasiException? _masalahLokasi;
  bool _sedangMengirim = false;

  DateTime _jamPerangkat() => (widget.sekarang ?? DateTime.now)();
  DateTime get _jamServer => _jamPerangkat().add(_selisihServer);
  int get _menitServer => _jamServer.hour * 60 + _jamServer.minute;

  @override
  void initState() {
    super.initState();
    _muat();
    // Perbarui tampilan berkala, mis. status "Absen dibuka 07.00" berubah
    // menjadi tombol Absen tanpa perlu menutup halaman.
    _detak = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final info = await _service.hariIni();
      if (!mounted) return;
      setState(() {
        _info = info;
        _selisihServer = info.waktuServer.difference(_jamPerangkat());
        _sedangMemuat = false;
        _pesanGagal = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pesanGagal = e.pesan;
        _sedangMemuat = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Aturan
  // ------------------------------------------------------------------

  KeadaanMapel _keadaan(InfoAbsenHariIni info, MapelAbsen mapel) =>
      keadaanMapelDenganCuti(
        mapel,
        info.cuti,
        hari: HariRelatif.ini,
        menitSekarang: _menitServer,
        bukaAbsenMenit: info.bukaAbsenMenit,
      );

  bool _bisaAbsen(InfoAbsenHariIni info, MapelAbsen mapel) {
    if (info.libur != null || info.cuti != null || mapel.idJadwal == null) {
      return false;
    }
    final keadaan = _keadaan(info, mapel);
    return keadaan == KeadaanMapel.belumAbsen ||
        keadaan == KeadaanMapel.terlewat;
  }

  static String _jamDariMenit(int menit) {
    final m = menit < 0 ? 0 : menit;
    return '${(m ~/ 60).toString().padLeft(2, '0')}.'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  /// Jarak posisi saat foto ke setiap lokasi absen, terdekat di atas.
  List<JarakLokasi> get _jarakLokasi {
    final posisi = _posisi;
    if (posisi == null) return const [];
    return urutkanLokasi(
      _info?.lokasiAbsen ?? const [],
      posisi.lat,
      posisi.lng,
    );
  }

  bool get _lokasiSiap {
    final posisi = _posisi;
    if (posisi == null || posisi.palsu) return false;
    final terpilih = lokasiAbsenTerpilih(_jarakLokasi);
    return terpilih == null || terpilih.diDalam;
  }

  // ------------------------------------------------------------------
  // Aksi
  // ------------------------------------------------------------------

  Future<void> _mulaiAbsen(int indeks) async {
    final info = _info!;
    final mapel = info.mapel[indeks];
    final hasil = await _kamera.buka(
      context,
      judul: 'Absen ${mapel.mataPelajaran}',
      lokasiAbsen: info.lokasiAbsen,
      lokasi: _lokasi,
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _indeksMapel = indeks;
      _foto = hasil.foto;
      _posisi = hasil.posisi;
      _masalahLokasi = hasil.masalahLokasi;
    });
  }

  void _batal() {
    setState(() {
      _indeksMapel = null;
      _foto = null;
      _posisi = null;
      _masalahLokasi = null;
    });
  }

  Future<void> _kirimAbsen() async {
    final info = _info!;
    final indeks = _indeksMapel;
    final foto = _foto;
    final posisi = _posisi;
    if (indeks == null || foto == null || posisi == null) return;

    setState(() => _sedangMengirim = true);
    try {
      final hasil = await _service.kirimAbsen(
        info.mapel[indeks].idJadwal!,
        foto,
        posisi,
      );
      if (!mounted) return;
      setState(() {
        _info = info.denganAbsensi(indeks, hasil.absensi);
        _sedangMengirim = false;
      });
      _batal();
      tampilkanPesan(context, hasil.pesan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      tampilkanPesan(context, e.pesan, gagal: true);
      // Mis. sudah absen dari HP lain / sudah ditandai admin
      if (e.kodeStatus == 409) {
        _batal();
        _muat();
      }
    }
  }

  // ------------------------------------------------------------------
  // Tampilan
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final menyiapkan = _foto != null && _indeksMapel != null;
    return PopScope(
      // Saat sedang menyiapkan absen, tombol kembali = batal absen
      canPop: !menyiapkan,
      onPopInvokedWithResult: (sudahKembali, _) {
        if (!sudahKembali && !_sedangMengirim) _batal();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Absen'),
          actions: [
            IconButton(
              tooltip: 'Riwayat Absen',
              icon: const Icon(Icons.manage_history_rounded),
              onPressed: menyiapkan
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RiwayatAbsenScreen(
                          absenService: widget.absenService,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: _isi(),
      ),
    );
  }

  Widget _isi() {
    if (_sedangMemuat) {
      return const Center(
        child: LoadingDots(
          warna: [AppColors.biru, AppColors.mint, AppColors.navy],
        ),
      );
    }
    final info = _info;
    if (info == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_pesanGagal ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _sedangMemuat = true);
                  _muat();
                },
                style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_foto != null && _indeksMapel != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: _tampilanSiapKirim(info, info.mapel[_indeksMapel!]),
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: _tampilanDaftar(info),
      ),
    );
  }

  /// Daftar mapel hari ini, masing-masing dengan status & tombol Absen.
  List<Widget> _tampilanDaftar(InfoAbsenHariIni info) {
    final tanggal = FormatTanggal.panjang(info.tanggal);
    if (info.libur != null) {
      return [
        _KartuPesan(
          ikon: Icons.beach_access_rounded,
          warnaIkon: const Color(0xFFFF8A80),
          judul: 'Hari ini libur',
          isi: '${info.libur}\n$tanggal',
        ),
      ];
    }
    if (info.mapel.isEmpty) {
      return [
        _KartuPesan(
          ikon: Icons.event_available_rounded,
          warnaIkon: AppColors.mint,
          judul: 'Tidak ada jadwal mengajar hari ini',
          isi: '$tanggal\nAbsen hanya untuk hari yang ada jadwal mengajarnya.',
        ),
      ];
    }

    return [
      _KartuRingkas(tanggal: tanggal, info: info, menitSekarang: _menitServer),
      const SizedBox(height: 18),
      Text(
        'Mapel hari ini',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.teks,
        ),
      ),
      const SizedBox(height: 8),
      if (info.cuti != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Catatan(
            ikon: Icons.beach_access_rounded,
            warna: GayaKehadiran.biru,
            teks:
                'Hari ini kamu ${info.cuti} (sudah disetujui admin), '
                'jadi tidak perlu absen.',
          ),
        ),
      for (var i = 0; i < info.mapel.length; i++)
        _KartuMapel(
          mapel: info.mapel[i],
          gaya: GayaKehadiran.dari(
            _keadaan(info, info.mapel[i]),
            absensi: info.mapel[i].absensi,
            jamBuka: _jamDariMenit(
              info.mapel[i].menitMulai - info.bukaAbsenMenit,
            ),
          ),
          berlangsung:
              _menitServer >= info.mapel[i].menitMulai &&
              _menitServer < info.mapel[i].menitSelesai,
          onAbsen: _bisaAbsen(info, info.mapel[i])
              ? () => _mulaiAbsen(i)
              : null,
        ),
      const SizedBox(height: 8),
      _Catatan(
        ikon: Icons.info_outline_rounded,
        teks:
            'Absen setiap mapel dibuka ${info.bukaAbsenMenit} menit sebelum '
            'jam mulai. Lewat ${info.toleransiMenit} menit dari jam mulai '
            'tercatat terlambat, tetapi tetap bisa absen.',
      ),
    ];
  }

  /// Desain 2: foto dari kamera + jam + kartu lokasi + tombol "Kirim Absen".
  List<Widget> _tampilanSiapKirim(InfoAbsenHariIni info, MapelAbsen mapel) {
    final jamSekarang = DateFormat('HH:mm').format(_jamServer);
    final menitTelat = _menitServer - mapel.menitMulai;
    final terlambat = menitTelat > info.toleransiMenit;
    final perkiraan = !terlambat
        ? const GayaKehadiran(
            'Tepat waktu',
            GayaKehadiran.hijau,
            Icons.check_circle_rounded,
          )
        : _menitServer >= mapel.menitSelesai
        ? GayaKehadiran(
            'Lewat jam pelajaran • +$menitTelat menit',
            GayaKehadiran.merah,
            Icons.running_with_errors_rounded,
          )
        : GayaKehadiran(
            'Terlambat $menitTelat menit',
            GayaKehadiran.kuning,
            Icons.watch_later_rounded,
          );

    final terpilih = lokasiAbsenTerpilih(_jarakLokasi);
    final bedaGedung =
        mapel.lokasi != null &&
        terpilih != null &&
        terpilih.diDalam &&
        terpilih.lokasi.nama != mapel.lokasi;

    return [
      _InfoMapel(mapel: mapel),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Column(
              children: [
                _KartuFoto(foto: _foto!.bytes, tinggi: 165),
                TextButton.icon(
                  onPressed: _sedangMengirim
                      ? null
                      : () => _mulaiAbsen(_indeksMapel!),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Foto ulang'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jam Absen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teks,
                    ),
                  ),
                  Text(
                    jamSekarang,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6CBD3B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ChipKehadiran(gaya: perkiraan),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _KartuLokasi(
        masalah: _masalahLokasi,
        posisi: _posisi,
        adaLokasiAbsen: info.lokasiAbsen.isNotEmpty,
        jarakLokasi: _jarakLokasi,
        onFotoUlang: () => _mulaiAbsen(_indeksMapel!),
        onBukaPengaturan: _masalahLokasi == null
            ? null
            : () => _lokasi.bukaPengaturan(_masalahLokasi!.pengaturan),
      ),
      if (bedaGedung) ...[
        const SizedBox(height: 14),
        _Catatan(
          ikon: Icons.info_outline_rounded,
          warna: GayaKehadiran.kuning,
          teks:
              'Mapel ini dijadwalkan di ${mapel.lokasi}, sedangkan kamu '
              'berada di ${terpilih.lokasi.nama}. Absen tetap bisa dikirim.',
        ),
      ],
      const SizedBox(height: 24),
      TombolUtama(
        teks: 'Kirim Absen',
        ikon: Icons.send_rounded,
        sedangMemuat: _sedangMengirim,
        onPressed: _lokasiSiap ? _kirimAbsen : null,
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: _sedangMengirim ? null : _batal,
        child: const Text('Batal'),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Komponen tampilan
// ---------------------------------------------------------------------------

/// Kartu ringkasan hari ini: jumlah mapel, jam masuk, jam boleh pulang.
class _KartuRingkas extends StatelessWidget {
  const _KartuRingkas({
    required this.tanggal,
    required this.info,
    required this.menitSekarang,
  });

  final String tanggal;
  final InfoAbsenHariIni info;
  final int menitSekarang;

  @override
  Widget build(BuildContext context) {
    final sudahAbsen = info.mapel.where((m) => m.absensi != null).length;
    final jamPulang = info.jamBolehPulang!;
    final bolehPulang = menitSekarang >= menitDariJam(jamPulang);

    Widget angka(String label, String nilai) => Expanded(
      child: Column(
        children: [
          Text(
            nilai,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040029), Color(0xFF0B0068)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            tanggal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              angka('Mapel', '$sudahAbsen/${info.mapel.length}'),
              angka('Masuk', jamTitik(info.jamMasuk!)),
              angka('Boleh pulang', jamTitik(jamPulang)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bolehPulang
                ? 'Semua mapel hari ini sudah selesai. Kamu sudah boleh pulang.'
                : 'Absen di setiap mapel. Kamu boleh pulang setelah mapel '
                      'terakhir selesai.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: bolehPulang ? AppColors.mint : Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu mapel hari ini: jam, kelas, gedung, status, dan tombol Absen.
class _KartuMapel extends StatelessWidget {
  const _KartuMapel({
    required this.mapel,
    required this.gaya,
    required this.berlangsung,
    this.onAbsen,
  });

  final MapelAbsen mapel;
  final GayaKehadiran gaya;
  final bool berlangsung;
  final VoidCallback? onAbsen;

  @override
  Widget build(BuildContext context) {
    final absensi = mapel.absensi;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: berlangsung ? AppColors.biru : AppColors.garis,
          width: berlangsung ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    jamTitik(mapel.jamMulai),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    jamTitik(mapel.jamSelesai),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mapel.mataPelajaran,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teks,
                    ),
                  ),
                  Text(
                    '${mapel.unit} • Kelas ${mapel.kelas}'
                    '${berlangsung ? ' • sedang berlangsung' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.teksAbu,
                    ),
                  ),
                  if (mapel.lokasi != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 14,
                            color: AppColors.teksAbu,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              mapel.lokasi!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teksAbu,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  ChipKehadiran(gaya: gaya),
                  if (absensi?.lokasi != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Absen di ${absensi!.lokasi}'
                        '${absensi.jarak == null ? '' : ' (${formatJarak(absensi.jarak!)})'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.teksAbu,
                        ),
                      ),
                    ),
                  if (absensi?.keterangan != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Catatan admin: ${absensi!.keterangan}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.teksAbu,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onAbsen != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilledButton.icon(
                  onPressed: onAbsen,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Absen'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Keterangan mapel yang sedang diabsen (di atas foto).
class _InfoMapel extends StatelessWidget {
  const _InfoMapel({required this.mapel});

  final MapelAbsen mapel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.biru.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Absen ${mapel.mataPelajaran}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teks,
                  ),
                ),
                Text(
                  '${mapel.jamTampil} • ${mapel.unit} Kelas ${mapel.kelas}'
                  '${mapel.lokasi == null ? '' : ' • ${mapel.lokasi}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.teksAbu,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu foto dengan sudut membulat & bayangan (sesuai desain).
class _KartuFoto extends StatelessWidget {
  const _KartuFoto({required this.foto, required this.tinggi});

  final Uint8List foto;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tinggi,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.memory(
        foto,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.3),
        gaplessPlayback: true,
        width: double.infinity,
      ),
    );
  }
}

/// Kartu abu-abu berisi ikon lokasi & lokasi absen terdekat (desain 2).
/// Lokasi yang ditampilkan adalah posisi GPS saat foto diambil.
class _KartuLokasi extends StatelessWidget {
  const _KartuLokasi({
    required this.masalah,
    required this.posisi,
    required this.adaLokasiAbsen,
    required this.jarakLokasi,
    required this.onFotoUlang,
    this.onBukaPengaturan,
  });

  final LokasiException? masalah;
  final PosisiAbsen? posisi;
  final bool adaLokasiAbsen;

  /// Jarak ke setiap lokasi absen, terdekat di atas.
  final List<JarakLokasi> jarakLokasi;
  final VoidCallback onFotoUlang;
  final VoidCallback? onBukaPengaturan;

  @override
  Widget build(BuildContext context) {
    final Color warnaIkon;
    final String judul;
    String? keterangan;
    var tombolFotoUlang = false;
    final terpilih = lokasiAbsenTerpilih(jarakLokasi);

    if (masalah != null || posisi == null) {
      warnaIkon = AppColors.merah;
      judul = 'Lokasi tidak terbaca saat foto diambil';
      keterangan = masalah?.pesan;
      tombolFotoUlang = true;
    } else if (posisi!.palsu) {
      warnaIkon = AppColors.merah;
      judul = 'Terdeteksi lokasi palsu';
      keterangan = 'Matikan aplikasi Fake GPS lalu foto ulang.';
      tombolFotoUlang = true;
    } else if (!adaLokasiAbsen || terpilih == null) {
      warnaIkon = AppColors.hijau;
      judul = 'Lokasi terbaca';
      keterangan =
          'Admin belum menambahkan lokasi absen, jadi jarak tidak dicek.';
    } else if (terpilih.diDalam) {
      warnaIkon = AppColors.hijau;
      judul = 'Kamu berada di ${terpilih.lokasi.nama}';
      keterangan =
          'Lokasi ${terpilih.lokasi.nomor} • ± ${formatJarak(terpilih.jarak)} '
          'dari titik absen';
    } else {
      warnaIkon = AppColors.merah;
      judul = 'Di luar area lokasi absen';
      keterangan =
          'Terdekat: ${terpilih.lokasi.namaLengkap}, ± '
          '${formatJarak(terpilih.jarak)} (maksimal ${terpilih.lokasi.radius} m). '
          'Mendekatlah ke lokasi absen lalu foto ulang.';
      tombolFotoUlang = true;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFD3D3D3),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 58,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(color: warnaIkon, width: 3.5),
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(58, 22),
                      ),
                    ),
                  ),
                ),
                Icon(Icons.location_on, size: 96, color: warnaIkon),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.teks,
            ),
          ),
          if (keterangan != null) ...[
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF3F3F46)),
            ),
          ],
          // Jarak ke semua lokasi absen (jika lebih dari satu)
          if (jarakLokasi.length > 1 && posisi != null && !posisi!.palsu) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final j in jarakLokasi)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            j.diDalam
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: j.diDalam
                                ? AppColors.hijau
                                : AppColors.teksAbu,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              j.lokasi.namaLengkap,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: identical(j, terpilih)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.teks,
                              ),
                            ),
                          ),
                          Text(
                            formatJarak(j.jarak),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.teks,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (tombolFotoUlang)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onFotoUlang,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Foto ulang'),
                ),
                if (onBukaPengaturan != null &&
                    masalah?.pengaturan != PengaturanLokasi.tidakAda)
                  TextButton.icon(
                    onPressed: onBukaPengaturan,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Buka pengaturan'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Catatan kecil berikon (info jam, peringatan, dll).
class _Catatan extends StatelessWidget {
  const _Catatan({
    required this.ikon,
    required this.teks,
    this.warna = AppColors.teksAbu,
  });

  final IconData ikon;
  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: warna),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: warna),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu besar untuk hari libur / izin / sakit / cuti.
class _KartuPesan extends StatelessWidget {
  const _KartuPesan({
    required this.ikon,
    required this.warnaIkon,
    required this.judul,
    required this.isi,
  });

  final IconData ikon;
  final Color warnaIkon;
  final String judul;
  final String isi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF040029), Color(0xFF0B0068)],
        ),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 56, color: warnaIkon),
          const SizedBox(height: 14),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isi,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
