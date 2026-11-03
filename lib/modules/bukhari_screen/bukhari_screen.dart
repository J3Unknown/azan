import 'dart:async';
import 'dart:convert';

import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _BukhariData {
  static Future<Map<String, dynamic>>? _cached;

  static Future<Map<String, dynamic>> load() {
    return _cached ??= rootBundle
        .loadString('assets/sources/bukhari.json')
        .then((source) => jsonDecode(source) as Map<String, dynamic>);
  }
}

class BukhariScreen extends StatelessWidget {
  const BukhariScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      appBar: AppBar(title: Text(context.tr('Sahih al-Bukhari'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BukhariSearchScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF282826),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: ColorsManager.primaryGold),
                    SizedBox(width: 12),
                    Text(
                      context.tr('Search all hadiths'),
                      style: const TextStyle(color: ColorsManager.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _BukhariData.load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const _LoadError();
                }
                final chapters = snapshot.data!['chapters'] as List<dynamic>;
                final hadiths = snapshot.data!['hadiths'] as List<dynamic>;
                final counts = <String, int>{};
                for (final item in hadiths) {
                  final hadith = item as Map<String, dynamic>;
                  final id = hadith['chapterId'].toString();
                  counts.update(id, (count) => count + 1, ifAbsent: () => 1);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final chapter = chapters[index] as Map<String, dynamic>;
                    final id = chapter['id'].toString();
                    final entries = hadiths
                        .where(
                          (item) =>
                              (item as Map<String, dynamic>)['chapterId']
                                  .toString() ==
                              id,
                        )
                        .cast<Map<String, dynamic>>()
                        .toList(growable: false);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF302D22),
                        foregroundColor: ColorsManager.primaryGold,
                        child: Text(id),
                      ),
                      title: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? chapter['arabic']?.toString() ?? ''
                            : chapter['english']?.toString() ?? '',
                        textDirection:
                            Localizations.localeOf(context).languageCode == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: const TextStyle(
                          color: ColorsManager.textPrimary,
                          fontSize: 18,
                          height: 1.7,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? '${counts[id] ?? 0} حديثًا'
                              : '${counts[id] ?? 0} hadiths',
                          style: const TextStyle(
                            color: ColorsManager.textMuted,
                          ),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: ColorsManager.primaryGold,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BukhariChapterScreen(
                            chapter: chapter,
                            hadiths: entries,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BukhariChapterScreen extends StatelessWidget {
  const BukhariChapterScreen({
    required this.chapter,
    required this.hadiths,
    super.key,
  });

  final Map<String, dynamic> chapter;
  final List<Map<String, dynamic>> hadiths;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      appBar: AppBar(
        title: Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? chapter['arabic']?.toString() ?? context.tr('Chapter')
              : chapter['english']?.toString() ?? context.tr('Chapter'),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: hadiths.length,
        itemBuilder: (context, index) => _HadithCard(hadith: hadiths[index]),
      ),
    );
  }
}

class BukhariSearchScreen extends StatefulWidget {
  const BukhariSearchScreen({super.key});

  @override
  State<BukhariSearchScreen> createState() => _BukhariSearchScreenState();
}

class _BukhariSearchScreenState extends State<BukhariSearchScreen> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 350);
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  String _inputQuery = '';
  bool _isDebouncing = false;
  static final RegExp _diacritics = RegExp(
    r'[\u064B-\u065F\u0670\u06D6-\u06ED]',
  );

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(_diacritics, '')
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      appBar: AppBar(title: Text(context.tr('Search Bukhari'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) {
                _debounceTimer?.cancel();
                final trimmedValue = value.trim();
                setState(() {
                  _inputQuery = value;
                  _isDebouncing = trimmedValue.isNotEmpty;
                  if (trimmedValue.isEmpty) _query = '';
                });
                if (trimmedValue.isNotEmpty) {
                  _debounceTimer = Timer(_searchDebounceDuration, () {
                    if (!mounted) return;
                    setState(() {
                      _query = trimmedValue;
                      _isDebouncing = false;
                    });
                  });
                }
              },
              style: const TextStyle(color: ColorsManager.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr('Search Arabic or English text'),
                hintStyle: const TextStyle(color: ColorsManager.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: ColorsManager.primaryGold,
                ),
                suffixIcon: _inputQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _controller.clear();
                          setState(() {
                            _query = '';
                            _inputQuery = '';
                            _isDebouncing = false;
                          });
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFF282826),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _BukhariData.load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const _LoadError();
                }
                if (_isDebouncing) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_query.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr(
                        'Enter a word or phrase to search all hadiths.',
                      ),
                      style: TextStyle(color: ColorsManager.textMuted),
                    ),
                  );
                }
                final chapters = {
                  for (final value
                      in snapshot.data!['chapters'] as List<dynamic>)
                    (value as Map<String, dynamic>)['id'].toString(): value,
                };
                final needle = _normalize(_query);
                final matches = (snapshot.data!['hadiths'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                    .where(
                      (hadith) => _normalize(
                        '${hadith['arabic'] ?? ''} ${hadith['english'] ?? ''}',
                      ).contains(needle),
                    )
                    .toList(growable: false);
                if (matches.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('No matching hadiths found.'),
                      style: TextStyle(color: ColorsManager.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final hadith = matches[index];
                    final chapter = chapters[hadith['chapterId'].toString()];
                    return _HadithCard(
                      hadith: hadith,
                      chapterTitle: chapter == null
                          ? null
                          : (Localizations.localeOf(context).languageCode ==
                                    'ar'
                                ? chapter['arabic']?.toString()
                                : chapter['english']?.toString()),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithCard extends StatelessWidget {
  const _HadithCard({required this.hadith, this.chapterTitle});

  final Map<String, dynamic> hadith;
  final String? chapterTitle;

  @override
  Widget build(BuildContext context) {
    final text = hadith['arabic']?.toString() ?? '';
    return Card(
      color: const Color(0xFF282826),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chapterTitle ??
                  '${context.tr('Hadith')} ${hadith['idInBook'] ?? hadith['id']}',
              style: const TextStyle(
                color: ColorsManager.primaryGold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ColorsManager.textPrimary,
                fontSize: 19,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr('Hadith')} ${hadith['id']}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ColorsManager.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        context.tr('Could not load the Bukhari collection.'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: ColorsManager.textMuted),
      ),
    ),
  );
}
