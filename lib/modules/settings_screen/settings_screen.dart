import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _city = 'Cairo, Egypt';
  bool _athanSound = true;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    final cachedCity = HiveManager.getMeta('city');
    if (cachedCity != null) _city = cachedCity.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: ColorsManager.textPrimary,
                  fontSize: 24,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Location Tile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF282826),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Location', style: TextStyle(color: ColorsManager.textPrimary, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(_city, style: const TextStyle(color: ColorsManager.textMuted, fontSize: 13)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorsManager.primaryGoldDark,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () async {
                        final city = await getCity();
                        await recalculateAndStorePrayerTimes();
                        setState(() {
                          _city = city;
                        });
                      },
                      child: const Text('Update', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notification Settings
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF282826),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Play Adhan Audio', style: TextStyle(color: ColorsManager.textPrimary, fontSize: 15)),
                        Switch(
                          value: _athanSound,
                          activeThumbColor: ColorsManager.primaryGold,
                          onChanged: (v) => setState(() => _athanSound = v),
                        ),
                      ],
                    ),
                    Divider(color: Colors.white.withValues(alpha: 0.08)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vibration on Reminder', style: TextStyle(color: ColorsManager.textPrimary, fontSize: 15)),
                        Switch(
                          value: _vibration,
                          activeThumbColor: ColorsManager.primaryGold,
                          onChanged: (v) => setState(() => _vibration = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Calculation info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF282826),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calculation Method', style: TextStyle(color: ColorsManager.textPrimary, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('Egyptian General Authority of Survey (Shafi)', style: TextStyle(color: ColorsManager.textMuted, fontSize: 13)),
                    SizedBox(height: 12),
                    Text('Background Recalculation', style: TextStyle(color: ColorsManager.textPrimary, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('WorkManager periodic interval: Every 8 hours', style: TextStyle(color: ColorsManager.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
