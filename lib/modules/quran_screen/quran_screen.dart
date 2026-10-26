import 'package:azan/models/reciter_model.dart';
import 'package:azan/modules/quran_screen/surah_reader_screen.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/quran_data.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  String _city = 'Cairo, Egypt';
  final DateTime _currentDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  List<SurahItem> _filteredSurahs = quranSurahsAscending;
  ReciterModel _selectedReciter = availableReciters.first;

  @override
  void initState() {
    super.initState();
    final cachedCity = HiveManager.getMeta('city');
    if (cachedCity != null) _city = cachedCity.toString();

    final reciterId = HiveManager.getMeta('selected_reciter_id', defaultValue: 1);
    _selectedReciter = availableReciters.firstWhere(
      (r) => r.id == reciterId,
      orElse: () => availableReciters.first,
    );

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = quranSurahsAscending;
      } else {
        _filteredSurahs = quranSurahsAscending.where((s) {
          return s.name.toLowerCase().contains(query) ||
              s.arabicName.contains(query) ||
              s.traditionalOrder.toString() == query;
        }).toList();
      }
    });
  }

  void _openSurahReader(SurahItem surah) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SurahReaderScreen(
          surah: surah,
          initialReciter: _selectedReciter,
        ),
      ),
    );
    
    if (mounted) setState(() {});
  }

  void _showReciterSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF242422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Reciter',
              style: TextStyle(
                color: ColorsManager.primaryGold,
                fontSize: 20,
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose your preferred audio reciter for Surahs & Verses',
              style: TextStyle(color: ColorsManager.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: availableReciters.length,
                separatorBuilder: (ctx, idx) => Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final reciter = availableReciters[index];
                  final isSelected = reciter.id == _selectedReciter.id;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    onTap: () async {
                      setState(() {
                        _selectedReciter = reciter;
                      });
                      await HiveManager.addUpdateMetaData('selected_reciter_id', reciter.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? ColorsManager.primaryGold : ColorsManager.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      reciter.name,
                      style: TextStyle(
                        color: isSelected ? ColorsManager.primaryGoldLight : ColorsManager.textPrimary,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      reciter.style,
                      style: const TextStyle(color: ColorsManager.textMuted, fontSize: 11),
                    ),
                    trailing: Text(
                      reciter.nameArabic,
                      style: TextStyle(
                        color: isSelected ? ColorsManager.primaryGold : ColorsManager.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: ColorsManager.primaryGold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _city,
                        style: const TextStyle(
                          color: ColorsManager.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    UiHelpers.formatDate(_currentDate),
                    style: const TextStyle(
                      color: ColorsManager.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Title and count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Holy Quran',
                    style: TextStyle(
                      color: ColorsManager.textPrimary,
                      fontSize: 24,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '114 Surahs',
                    style: TextStyle(
                      color: ColorsManager.primaryGold.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Subtitle and Reciter Selector Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Traditional Order (Tap to Read)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ColorsManager.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showReciterSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282826),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ColorsManager.primaryGold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic, color: ColorsManager.primaryGold, size: 14),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              _selectedReciter.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ColorsManager.primaryGoldLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: ColorsManager.primaryGold, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Box
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242422),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: ColorsManager.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search Surah by name or number...',
                    hintStyle: const TextStyle(color: ColorsManager.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: ColorsManager.primaryGold, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: ColorsManager.textMuted, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 114 Surahs List in Traditional Order Ascending (Overflow Free)
              Expanded(
                child: ListView.separated(
                  itemCount: _filteredSurahs.length,
                  separatorBuilder: (ctx, idx) => Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    final isCached = HiveManager.isSurahCached(surah.traditionalOrder);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      onTap: () => _openSurahReader(surah),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF282826),
                          border: Border.all(
                            color: ColorsManager.primaryGold.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${surah.traditionalOrder}',
                          style: const TextStyle(
                            color: ColorsManager.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              surah.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ColorsManager.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isCached) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.offline_pin,
                              color: Colors.green,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${surah.numberOfVerses} Verses • ${surah.location}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ColorsManager.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: ColorsManager.primaryGoldDark.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${surah.chronologicalOrder}',
                                style: const TextStyle(
                                  color: ColorsManager.primaryGoldLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            surah.arabicName,
                            style: const TextStyle(
                              color: ColorsManager.primaryGoldLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: ColorsManager.textMuted,
                            size: 12,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
