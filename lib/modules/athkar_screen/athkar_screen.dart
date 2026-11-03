import 'package:azan/models/athkar_model.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/supplication_data.dart';
import 'package:azan/utils/helpers/reference_supplication_data.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> {
  List<AthkarModel> _athkar = [];

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  void _loadChoices() {
    final allById = {
      for (final item in [
        ...additionalSupplications,
        ...referenceSupplications,
      ])
        item.id: item,
    };
    for (final item in HiveManager.getAthkar()) {
      allById[item.id] = item;
    }
    setState(() => _athkar = allById.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final allPrayerItems = _athkar.where((item) {
      final group = item.prayerName.toLowerCase();
      return group == 'all prayers' ||
          group.contains('fajr') ||
          group.contains('maghrib');
    }).toList();
    final groups = <String, List<AthkarModel>>{
      'All prayers': allPrayerItems,
      'Morning supplications': _athkar
          .where((item) => item.prayerName == 'Morning supplications')
          .toList(),
      'Evening supplications': _athkar
          .where((item) => item.prayerName == 'Evening supplications')
          .toList(),
      'Tasbeeh': _athkar.where((item) => item.prayerName == 'Tasbeeh').toList(),
      'Sleep supplications': _athkar
          .where((item) => item.prayerName == 'Sleep supplications')
          .toList(),
      'Wake-up supplications': _athkar
          .where((item) => item.prayerName == 'Wake-up supplications')
          .toList(),
      'Quranic supplications': _athkar
          .where((item) => item.prayerName == 'Quranic supplications')
          .toList(),
      'Prophets’ supplications': _athkar
          .where((item) => item.prayerName == 'Prophets’ supplications')
          .toList(),
    }..removeWhere((_, items) => items.isEmpty);
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.tr('Supplications'),
              style: const TextStyle(
                color: ColorsManager.textPrimary,
                fontSize: 25,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Choose a supplication collection to begin.'),
              style: TextStyle(color: ColorsManager.textMuted),
            ),
            const SizedBox(height: 18),
            for (final entry in groups.entries)
              Card(
                color: const Color(0xFF282826),
                child: ListTile(
                  title: Text(
                    context.tr(entry.key),
                    style: const TextStyle(color: ColorsManager.textPrimary),
                  ),
                  subtitle: Text(
                    '${entry.value.length} ${context.tr('supplications')}',
                    style: const TextStyle(color: ColorsManager.textMuted),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: ColorsManager.primaryGold,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SupplicationCounterScreen(
                        title: entry.key,
                        supplications: entry.value,
                        showFajrMaghribNote: entry.key == 'All prayers',
                      ),
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

class SupplicationCounterScreen extends StatefulWidget {
  final String title;
  final List<AthkarModel> supplications;
  final bool showFajrMaghribNote;

  const SupplicationCounterScreen({
    super.key,
    required this.title,
    required this.supplications,
    this.showFajrMaghribNote = false,
  });

  @override
  State<SupplicationCounterScreen> createState() =>
      _SupplicationCounterScreenState();
}

class _SupplicationCounterScreenState extends State<SupplicationCounterScreen> {
  List<AthkarModel> _athkarList = [];
  int _currentIndex = 0;
  String _city = 'Cairo, Egypt';
  final DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAthkar();
  }

  Future<void> _loadAthkar() async {
    // Check if prayer time is up to reset counts
    await checkAndResetAthkarForPrayerTimes();

    final cachedCity = HiveManager.getMeta('city');
    if (cachedCity != null && cachedCity.toString().isNotEmpty) {
      _city = cachedCity.toString();
    }

    final storedById = {
      for (final item in HiveManager.getAthkar()) item.id: item,
    };
    final list = widget.supplications
        .map((item) => storedById[item.id] ?? item)
        .toList();
    if (mounted) {
      setState(() {
        _athkarList = list;
      });
    }
  }

  void _incrementCounter() {
    if (_athkarList.isEmpty) return;

    final currentAthkar = _athkarList[_currentIndex];
    if (currentAthkar.currentCount < currentAthkar.totalCount) {
      HapticFeedback.lightImpact();
      setState(() {
        currentAthkar.currentCount++;
      });
      HiveManager.updateAthkar(currentAthkar);
    } else {
      HapticFeedback.mediumImpact();
      // Completed current athkar - auto advance to next if available
      if (_currentIndex < _athkarList.length - 1) {
        setState(() {
          _currentIndex++;
        });
      }
    }
  }

  void _manualReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2A),
        title: Text(
          context.tr('Reset Counters'),
          style: TextStyle(
            color: ColorsManager.textPrimary,
            fontFamily: 'serif',
          ),
        ),
        content: Text(
          context.tr('Do you want to reset all Athkar counters to 0?'),
          style: TextStyle(color: ColorsManager.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('Cancel'),
              style: const TextStyle(color: ColorsManager.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsManager.primaryGoldDark,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await HiveManager.resetAthkarCounts();
              await _loadAthkar();
            },
            child: Text(
              context.tr('Reset'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_athkarList.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF191A19),
        body: Center(
          child: CircularProgressIndicator(color: ColorsManager.primaryGold),
        ),
      );
    }

    final currentAthkar = _athkarList[_currentIndex];
    final progressFraction = currentAthkar.totalCount > 0
        ? (currentAthkar.currentCount / currentAthkar.totalCount).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Header: Location, Date and Reset Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: ColorsManager.primaryGold,
                            size: 20,
                          ),
                          tooltip: context.tr('Back to supplications'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                  Row(
                    children: [
                      Text(
                        UiHelpers.formatDate(
                          _currentDate,
                          arabic:
                              Localizations.localeOf(context).languageCode ==
                              'ar',
                        ),
                        style: const TextStyle(
                          color: ColorsManager.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: ColorsManager.primaryGold,
                          size: 20,
                        ),
                        onPressed: _manualReset,
                        tooltip: context.tr('Reset Counters'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title and Subtitle
              Text(
                context.tr(widget.title),
                style: TextStyle(
                  color: ColorsManager.textPrimary,
                  fontSize: 24,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.showFajrMaghribNote)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    context.tr(
                      'Some supplications in this collection are specifically said after Fajr, after Maghrib, or after both prayers. Follow the note shown with each supplication.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ColorsManager.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (widget.showFajrMaghribNote) const SizedBox(height: 8),
              Text(
                context.tr('Post-Prayer Supplications'),
                style: TextStyle(
                  color: ColorsManager.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),

              // Progress Bar Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${context.tr('Progress:')} ${currentAthkar.currentCount} / ${currentAthkar.totalCount}',
                      style: const TextStyle(
                        color: ColorsManager.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressFraction,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF3C3C3A),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          ColorsManager.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Main Supplication Card with side indicators
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: ColorsManager.primaryGold.withValues(
                            alpha: 0.35,
                          ),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Arabic text with subtle gold glow
                            Text(
                              currentAthkar.arabicText,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: ColorsManager.primaryGoldLight,
                                fontSize: currentAthkar.arabicText.length > 30
                                    ? 22
                                    : 36,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    color: ColorsManager.primaryGold.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Transliteration
                            if (currentAthkar.transliteration.isNotEmpty)
                              Text(
                                currentAthkar.transliteration,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ColorsManager.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (widget.showFajrMaghribNote &&
                                (currentAthkar.prayerName
                                        .toLowerCase()
                                        .contains('fajr') ||
                                    currentAthkar.prayerName
                                        .toLowerCase()
                                        .contains('maghrib'))) ...[
                              const SizedBox(height: 10),
                              Text(
                                currentAthkar.prayerName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ColorsManager.primaryGold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),

                            // Translation
                            if (currentAthkar.translation.isNotEmpty)
                              Text(
                                currentAthkar.translation,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ColorsManager.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Navigation Arrows on left and right edges
                    if (_currentIndex > 0)
                      Positioned(
                        left: -4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: ColorsManager.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentIndex--;
                            });
                          },
                        ),
                      ),
                    if (_currentIndex < _athkarList.length - 1)
                      Positioned(
                        right: -4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: ColorsManager.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentIndex++;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Circular Tap Counter
              _buildCircularCounter(currentAthkar, progressFraction),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularCounter(AthkarModel currentAthkar, double progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left geometric line flourish
        CustomPaint(
          size: const Size(40, 40),
          painter: _FlourishPainter(isLeft: true),
        ),
        const SizedBox(width: 12),

        // Interactive Circular Counter
        GestureDetector(
          onTap: _incrementCounter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Progress Ring
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: const Color(0xFF333331),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ColorsManager.primaryGold,
                  ),
                ),
              ),

              // Center Circular Button
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF242422),
                  border: Border.all(
                    color: ColorsManager.primaryGold.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorsManager.primaryGold.withValues(alpha: 0.15),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${currentAthkar.currentCount}',
                      style: const TextStyle(
                        color: ColorsManager.primaryGoldLight,
                        fontSize: 38,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Tap to Count'),
                      style: TextStyle(
                        color: ColorsManager.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '${currentAthkar.totalCount} ${context.tr('times')}',
                      style: const TextStyle(
                        color: ColorsManager.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),
        // Right geometric line flourish
        CustomPaint(
          size: const Size(40, 40),
          painter: _FlourishPainter(isLeft: false),
        ),
      ],
    );
  }
}

class _FlourishPainter extends CustomPainter {
  final bool isLeft;
  _FlourishPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorsManager.primaryGold.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    if (isLeft) {
      path.moveTo(size.width, size.height / 2);
      path.lineTo(size.width * 0.4, size.height / 2);
      path.lineTo(size.width * 0.2, size.height * 0.3);
      path.lineTo(0, size.height / 2);
      path.lineTo(size.width * 0.2, size.height * 0.7);
      path.lineTo(size.width * 0.4, size.height / 2);
    } else {
      path.moveTo(0, size.height / 2);
      path.lineTo(size.width * 0.6, size.height / 2);
      path.lineTo(size.width * 0.8, size.height * 0.3);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width * 0.8, size.height * 0.7);
      path.lineTo(size.width * 0.6, size.height / 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
