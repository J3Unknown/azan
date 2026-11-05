import 'dart:convert';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:http/http.dart' as http;

class QuranAyah {
  final String verseKey;
  final int ayah;
  final String arabic;
  final String transliteration;
  final String translation;
  final String? audioUrl;

  QuranAyah({
    required this.verseKey,
    required this.ayah,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    this.audioUrl,
  });

  factory QuranAyah.fromJson(Map<String, dynamic> json) {
    String translationText = '';
    final trans = json['translations'];
    if (trans is Map) {
      translationText =
          trans['sahih_international'] ??
          trans['pickthall'] ??
          trans['yusuf_ali'] ??
          '';
    } else if (json['translation'] is String) {
      translationText = json['translation'];
    }

    String? audio;
    final audioJson = json['audio'];
    if (audioJson is Map) {
      audio = audioJson['ayah_audio'];
    } else if (json['audio_url'] is String) {
      audio = json['audio_url'];
    }

    return QuranAyah(
      verseKey: json['verse_key'] ?? '',
      ayah: (json['ayah'] as num?)?.toInt() ?? 0,
      arabic: json['arabic'] ?? '',
      transliteration: json['transliteration'] ?? '',
      translation: translationText,
      audioUrl: audio,
    );
  }

  Map<String, dynamic> toJson() => {
    'verse_key': verseKey,
    'ayah': ayah,
    'arabic': arabic,
    'transliteration': transliteration,
    'translation': translation,
    'audio_url': audioUrl,
  };
}

class QuranApiService {
  static const String baseUrl = 'https://ummahapi.com';

  /// Fetches surah details with all ayahs.
  /// If already retrieved and cached in Hive, returns immediately from memory/cache (one-time call).
  /// Otherwise, calls https://ummahapi.com/api/quran/surah/$surahNumber and caches the result permanently.
  static Future<List<QuranAyah>> getSurahVerses(int surahNumber) async {
    // 1. Check local Hive cache first
    final cached = HiveManager.getCachedSurah(surahNumber);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached.toString()) as Map<String, dynamic>;
        final versesData =
            decoded['data']?['verses'] as List? ?? decoded['verses'] as List?;
        if (versesData != null) {
          return versesData
              .map((v) => QuranAyah.fromJson(v as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // If decoding cached data fails, proceed to fetch
      }
    }

    // 2. One-time call from API if not yet in cache
    final url = Uri.parse('$baseUrl/api/quran/surah/$surahNumber');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] == true && decoded['data'] != null) {
        final data = decoded['data'] as Map<String, dynamic>;
        final versesList = data['verses'] as List;

        // Save raw response into Hive cache for offline and all future usages
        await HiveManager.cacheSurah(surahNumber, response.body);

        return versesList
            .map((v) => QuranAyah.fromJson(v as Map<String, dynamic>))
            .toList();
      }
    }

    throw Exception(
      'Failed to load Surah $surahNumber. Status code: ${response.statusCode}',
    );
  }
}

class TafseerType {
  final int id;
  final String name;
  final String language;
  final String author;
  final String bookName;

  const TafseerType({
    required this.id,
    required this.name,
    required this.language,
    required this.author,
    required this.bookName,
  });

  factory TafseerType.fromJson(Map<String, dynamic> json) => TafseerType(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    language: json['language'] as String? ?? '',
    author: json['author'] as String? ?? '',
    bookName: json['book_name'] as String? ?? '',
  );
}

class AyahTafseer {
  final int tafseerId;
  final String tafseerName;
  final String text;

  const AyahTafseer({
    required this.tafseerId,
    required this.tafseerName,
    required this.text,
  });

  factory AyahTafseer.fromJson(Map<String, dynamic> json) => AyahTafseer(
    tafseerId: (json['tafseer_id'] as num?)?.toInt() ?? 1,
    tafseerName: json['tafseer_name'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );
}

class TafseerApiService {
  static const String baseUrl = 'https://api.quran-tafseer.com/tafseer';

  static Future<List<TafseerType>> getTypes() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load tafseer types (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body) as List;
    return decoded
        .map((item) => TafseerType.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<AyahTafseer> getAyahTafseer(
    int tafseerId,
    int surahId,
    int verseId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$tafseerId/$surahId/$verseId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load tafseer (${response.statusCode})');
    }
    return AyahTafseer.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
