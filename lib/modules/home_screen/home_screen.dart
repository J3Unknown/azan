import 'dart:async';
import 'package:azan/models/prayer_model.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:azan/services/prayer_home_widget_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _countdownTimer;
  List<PrayerModel> _prayers = [];
  String _city = 'Cairo, Egypt';
  DateTime _currentTime = DateTime.now();
  bool _isRefreshingPrayerTimes = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadData() async {
    final cachedCity = HiveManager.getMeta('city');
    if (cachedCity != null && cachedCity.toString().isNotEmpty) {
      _city = cachedCity.toString();
    } else {
      _city = await getCity();
    }

    var prayers = HiveManager.getPrayer();
    if (prayers.isEmpty) {
      await recalculateAndStorePrayerTimes();
      prayers = HiveManager.getPrayer();
    }

    if (mounted) {
      setState(() {
        _prayers = prayers;
      });
    }
    await PrayerHomeWidgetService.update(prayers);
  }

  Future<void> _togglePrayer(PrayerModel prayer, bool value) async {
    setState(() {
      prayer.isEnabled = value;
    });
    await HiveManager.togglePrayerEnabled(prayer.prayerID, value);
    if (value) {
      await scheduleTask(prayer);
    } else {
      await cancelNotification(prayer.prayerID);
    }
  }

  Future<void> _refreshPrayerTimes() async {
    if (_isRefreshingPrayerTimes) return;
    setState(() => _isRefreshingPrayerTimes = true);
    try {
      await recalculateAndStorePrayerTimes();
      await _loadData();
    } finally {
      if (mounted) setState(() => _isRefreshingPrayerTimes = false);
    }
  }

  /// Evaluates main prayer section based on the quarter-hour rule:
  /// "the current prayer where the prayer didn't pass quarter and hour from it's athan time
  /// will be the main section, if passed then the next prayer will be the main while all prayer
  /// times remain in the list with ability to disable them"
  ({PrayerModel? prayer, bool isCurrentActive, Duration timeDifference})
  _getMainPrayerInfo() {
    if (_prayers.isEmpty) {
      return (
        prayer: null,
        isCurrentActive: false,
        timeDifference: Duration.zero,
      );
    }

    final now = _currentTime;

    // 1. Check if any prayer is currently within 15 minutes (quarter of an hour) after its athan
    for (var prayer in _prayers) {
      final athanTime = prayer.prayerTime;
      final quarterHourAfter = athanTime.add(const Duration(minutes: 15));

      if (now.isAfter(athanTime) && now.isBefore(quarterHourAfter)) {
        final remainingInWindow = quarterHourAfter.difference(now);
        return (
          prayer: prayer,
          isCurrentActive: true,
          timeDifference: remainingInWindow,
        );
      }
    }

    // 2. If no prayer within 15 mins after athan, find the next upcoming prayer today
    for (var prayer in _prayers) {
      if (prayer.prayerTime.isAfter(now)) {
        final diff = prayer.prayerTime.difference(now);
        return (prayer: prayer, isCurrentActive: false, timeDifference: diff);
      }
    }

    // 3. If all prayers for today passed, next prayer is tomorrow's Fajr
    final fajr = _prayers.firstWhere(
      (p) => p.prayerID == 1,
      orElse: () => _prayers.first,
    );
    final tomorrowFajr = fajr.prayerTime.add(const Duration(days: 1));
    final diff = tomorrowFajr.difference(now);

    return (prayer: fajr, isCurrentActive: false, timeDifference: diff);
  }

  @override
  Widget build(BuildContext context) {
    final mainInfo = _getMainPrayerInfo();
    final mainPrayer = mainInfo.prayer;

    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: RefreshIndicator(
          color: ColorsManager.primaryGold,
          backgroundColor: const Color(0xFF282826),
          onRefresh: () async {
            await recalculateAndStorePrayerTimes();
            await _loadData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Location & Date
                _buildHeader(),
                const SizedBox(height: 28),

                // Section Title: "Next Prayer" or "Current Prayer"
                Text(
                  mainInfo.isCurrentActive ? 'Current Prayer' : 'Next Prayer',
                  style: const TextStyle(
                    color: ColorsManager.textPrimary,
                    fontSize: 22,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),

                // Main Highlight Card
                if (mainPrayer != null)
                  _buildMainPrayerCard(
                    mainPrayer,
                    mainInfo.isCurrentActive,
                    mainInfo.timeDifference,
                  ),

                const SizedBox(height: 32),

                // List of all prayer times with toggle switches
                _buildPrayerTimesList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              UiHelpers.formatDate(_currentTime),
              style: const TextStyle(
                color: ColorsManager.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Update prayer times',
              visualDensity: VisualDensity.compact,
              icon: _isRefreshingPrayerTimes
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: ColorsManager.primaryGold, size: 20),
              onPressed: _isRefreshingPrayerTimes ? null : _refreshPrayerTimes,
            ),
            IconButton(
              tooltip: 'Add prayer times widget',
              icon: const Icon(
                Icons.widgets_outlined,
                color: ColorsManager.primaryGold,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                try {
                  await PrayerHomeWidgetService.requestPin();
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not add widget: $error')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainPrayerCard(
    PrayerModel prayer,
    bool isCurrentActive,
    Duration duration,
  ) {
    // Split time into digits and period (e.g., "04:52" and "AM")
    final timeStr = UiHelpers.formatTime12(prayer.prayerTime);
    final parts = timeStr.split(' ');
    final timeDigits = parts.first;
    final period = parts.length > 1 ? parts[1] : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrentActive
              ? ColorsManager.primaryGold.withValues(alpha: 0.5)
              : ColorsManager.primaryGold.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          if (isCurrentActive)
            BoxShadow(
              color: ColorsManager.primaryGold.withValues(alpha: 0.12),
              blurRadius: 25,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Crescent Moon and Star Icon on the right
          Positioned(
            right: 0,
            top: 4,
            child: FaIcon(
              FontAwesomeIcons.solidMoon,
              color: ColorsManager.primaryGold.withValues(alpha: 0.45),
              size: 58,
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prayer Name in Uppercase
              Text(
                prayer.prayerName.toUpperCase(),
                style: const TextStyle(
                  color: ColorsManager.textPrimary,
                  fontSize: 24,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 10),

              // Large Time display with period
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    timeDigits,
                    style: const TextStyle(
                      color: ColorsManager.primaryGold,
                      fontSize: 48,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    period,
                    style: const TextStyle(
                      color: ColorsManager.primaryGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Countdown / Status pill
              Text(
                isCurrentActive
                    ? '${UiHelpers.formatDuration(duration)} left in Athan'
                    : '${UiHelpers.formatDuration(duration)} until ${prayer.prayerName}',
                style: TextStyle(
                  color: ColorsManager.primaryGold.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesList() {
    if (_prayers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: ColorsManager.primaryGold),
        ),
      );
    }

    return Column(
      children: _prayers.map((prayer) {
        return _buildPrayerRow(prayer);
      }).toList(),
    );
  }

  Widget _buildPrayerRow(PrayerModel prayer) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              // Prayer Name
              Expanded(
                flex: 3,
                child: Text(
                  prayer.prayerName,
                  style: const TextStyle(
                    color: ColorsManager.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              // Prayer Time
              Expanded(
                flex: 4,
                child: Text(
                  UiHelpers.formatTime12(prayer.prayerTime),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: prayer.isEnabled
                        ? ColorsManager.textSecondary
                        : ColorsManager.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              // Toggle Switch
              SizedBox(
                width: 48,
                child: Transform.scale(
                  scale: 0.82,
                  child: Switch(
                    value: prayer.isEnabled,
                    activeThumbColor: ColorsManager.primaryGold,
                    activeTrackColor: ColorsManager.primaryGoldDark.withValues(
                      alpha: 0.7,
                    ),
                    inactiveThumbColor: ColorsManager.textMuted,
                    inactiveTrackColor: const Color(0xFF2E2E2C),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => _togglePrayer(prayer, val),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: Colors.white.withValues(alpha: 0.08),
          height: 1,
          thickness: 0.8,
        ),
      ],
    );
  }
}
