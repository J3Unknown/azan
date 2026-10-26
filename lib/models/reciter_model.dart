class ReciterModel {
  final int id;
  final String name;
  final String nameArabic;
  final String style;
  final String everyAyahSubfolder;
  final String fullSurahServerUrl;

  const ReciterModel({
    required this.id,
    required this.name,
    required this.nameArabic,
    required this.style,
    required this.everyAyahSubfolder,
    required this.fullSurahServerUrl,
  });

  String getAyahAudioUrl(int surah, int ayah) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$everyAyahSubfolder/$s$a.mp3';
  }

  String getFullSurahAudioUrl(int surah) {
    final s = surah.toString().padLeft(3, '0');
    return '$fullSurahServerUrl/$s.mp3';
  }
}

const List<ReciterModel> availableReciters = [
  ReciterModel(
    id: 1,
    name: 'Mishary Rashid Alafasy',
    nameArabic: 'مشاري راشد العفاسي',
    style: 'Murattal',
    everyAyahSubfolder: 'Alafasy_128kbps',
    fullSurahServerUrl: 'https://server8.mp3quran.net/afs',
  ),
  ReciterModel(
    id: 2,
    name: 'Abdul Rahman Al-Sudais',
    nameArabic: 'عبدالرحمن السديس',
    style: 'Murattal',
    everyAyahSubfolder: 'Abdurrahmaan_As-Sudais_192kbps',
    fullSurahServerUrl: 'https://server11.mp3quran.net/sds',
  ),
  ReciterModel(
    id: 3,
    name: 'Maher Al Muaiqly',
    nameArabic: 'ماهر المعيقلي',
    style: 'Murattal',
    everyAyahSubfolder: 'MauroAuad-AlMuaiqly_128kbps',
    fullSurahServerUrl: 'https://server12.mp3quran.net/maher',
  ),
  ReciterModel(
    id: 4,
    name: 'Saad Al-Ghamdi',
    nameArabic: 'سعد الغامدي',
    style: 'Murattal',
    everyAyahSubfolder: 'Ghamadi_40kbps',
    fullSurahServerUrl: 'https://server7.mp3quran.net/s_gmd',
  ),
  ReciterModel(
    id: 5,
    name: 'Abdul Basit Abdul Samad',
    nameArabic: 'عبدالباسط عبدالصمد',
    style: 'Murattal',
    everyAyahSubfolder: 'Abdul_Basit_Murattal_192kbps',
    fullSurahServerUrl: 'https://server7.mp3quran.net/basit',
  ),
  ReciterModel(
    id: 6,
    name: 'Yasser Al-Dosari',
    nameArabic: 'ياسر الدوسري',
    style: 'Murattal',
    everyAyahSubfolder: 'Yasser_Ad-Dussary_128kbps',
    fullSurahServerUrl: 'https://server11.mp3quran.net/yasser',
  ),
  ReciterModel(
    id: 7,
    name: 'Abu Bakr Al Shatri',
    nameArabic: 'أبوبكر الشاطري',
    style: 'Murattal',
    everyAyahSubfolder: 'Abu_Bakr_Ash-Shaatree_128kbps',
    fullSurahServerUrl: 'https://server11.mp3quran.net/shatri',
  ),
  ReciterModel(
    id: 8,
    name: 'Hani Ar-Rifai',
    nameArabic: 'هاني الرفاعي',
    style: 'Murattal',
    everyAyahSubfolder: 'Hani_Rifai_192kbps',
    fullSurahServerUrl: 'https://server8.mp3quran.net/rifai',
  ),
  ReciterModel(
    id: 9,
    name: 'Saud Al-Shuraim',
    nameArabic: 'سعود الشريم',
    style: 'Murattal',
    everyAyahSubfolder: 'Saood_ash-Shuraym_128kbps',
    fullSurahServerUrl: 'https://server7.mp3quran.net/shur',
  ),
  ReciterModel(
    id: 10,
    name: 'Abdullah Al-Juhany',
    nameArabic: 'عبدالله الجهني',
    style: 'Murattal',
    everyAyahSubfolder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
    fullSurahServerUrl: 'https://server13.mp3quran.net/jhn',
  ),
];
