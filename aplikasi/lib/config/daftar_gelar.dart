/// Pilihan gelar pada form pendaftaran.
///
/// Nilai `''` berarti tanpa gelar. Untuk menambah pilihan, cukup tambahkan
/// baris baru di bawah ini (backend menerima huruf, titik, koma, dan spasi).
class DaftarGelar {
  DaftarGelar._();

  static const String tanpaGelar = '';

  static const Map<String, String> pilihan = {
    tanpaGelar: 'Tanpa gelar',
    // Diploma
    'A.Md.': 'A.Md. (Ahli Madya)',
    'A.Md.Pd.': 'A.Md.Pd. (Ahli Madya Pendidikan)',
    // Sarjana (S1)
    'S.Pd.': 'S.Pd. (Sarjana Pendidikan)',
    'S.Pd.I.': 'S.Pd.I. (Sarjana Pendidikan Islam)',
    'S.Ag.': 'S.Ag. (Sarjana Agama)',
    'S.Psi.': 'S.Psi. (Sarjana Psikologi)',
    'S.S.': 'S.S. (Sarjana Sastra)',
    'S.Si.': 'S.Si. (Sarjana Sains)',
    'S.Kom.': 'S.Kom. (Sarjana Komputer)',
    'S.E.': 'S.E. (Sarjana Ekonomi)',
    'S.H.': 'S.H. (Sarjana Hukum)',
    'S.Sos.': 'S.Sos. (Sarjana Sosial)',
    'S.Hum.': 'S.Hum. (Sarjana Humaniora)',
    // Magister (S2)
    'M.Pd.': 'M.Pd. (Magister Pendidikan)',
    'M.Pd.I.': 'M.Pd.I. (Magister Pendidikan Islam)',
    'S.Pd., M.Pd.': 'S.Pd., M.Pd.',
    // Gelar yang ditulis di depan nama
    'Drs.': 'Drs. (ditulis di depan nama)',
    'Dra.': 'Dra. (ditulis di depan nama)',
  };
}
