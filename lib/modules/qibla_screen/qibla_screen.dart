import 'dart:async';
import 'dart:math' as math;
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  String _city = 'Cairo, Egypt';
  final DateTime _currentDate = DateTime.now();
  double _userLat = 30.0444;
  double _userLng = 31.2357;
  late QiblaData _qiblaData;

  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _deviceHeading; // Heading from North in degrees (0..360)
  bool _hasCompassSensor = true;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _qiblaData = calculateQibla(_userLat, _userLng);
    _initCompass();
  }

  void _initCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      setState(() {
        _hasCompassSensor = false;
      });
      return;
    }

    _compassSubscription = stream.listen((CompassEvent event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) {
        // Check alignment with Kaaba (within +/- 3 degrees)
        final diff = (_qiblaData.bearing - heading).abs() % 360;
        final isAligned = diff <= 3 || diff >= 357;

        if (isAligned && !_wasAligned) {
          HapticFeedback.mediumImpact();
        }
        _wasAligned = isAligned;

        setState(() {
          _deviceHeading = heading;
          _hasCompassSensor = true;
        });
      }
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _hasCompassSensor = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final cachedCity = HiveManager.getMeta('city');
    final lat = HiveManager.getMeta('lat');
    final lng = HiveManager.getMeta('long');

    if (lat != null && lng != null) {
      _userLat = (lat as num).toDouble();
      _userLng = (lng as num).toDouble();
    }
    if (cachedCity != null) {
      _city = cachedCity.toString();
    }

    final newQibla = calculateQibla(_userLat, _userLng);
    if (mounted) {
      setState(() {
        _qiblaData = newQibla;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current heading in degrees; default to 0 if sensor not ready
    final currentHeading = _deviceHeading ?? 0.0;
    // Calculate angle difference relative to phone top
    final diffDegrees = (_qiblaData.bearing - currentHeading + 360) % 360;
    final isFacingQibla = diffDegrees <= 3 || diffDegrees >= 357;

    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
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
              const SizedBox(height: 20),

              // Title
              const Text(
                'Qibla Direction',
                style: TextStyle(
                  color: ColorsManager.textPrimary,
                  fontSize: 24,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFacingQibla
                    ? '✨ You are facing the Holy Kaaba!'
                    : 'Turn your device until the needle points up',
                style: TextStyle(
                  color: isFacingQibla ? ColorsManager.primaryGoldLight : ColorsManager.textMuted,
                  fontSize: 13,
                  fontWeight: isFacingQibla ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Real-time Dynamic Compass Widget
              Expanded(
                child: Center(
                  child: _buildDynamicCompass(currentHeading, isFacingQibla),
                ),
              ),

              const SizedBox(height: 16),

              // Sensor Status Warning if not available
              if (!_hasCompassSensor)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sensors_off, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Compass sensor not detected. Showing calculated angle.',
                        style: TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ],
                  ),
                ),

              // Info Cards: Bearing & Distance
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282826),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFacingQibla
                              ? ColorsManager.primaryGold
                              : ColorsManager.primaryGold.withValues(alpha: 0.2),
                          width: isFacingQibla ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Qibla Bearing',
                            style: TextStyle(
                              color: ColorsManager.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_qiblaData.bearing.toStringAsFixed(1)}° ${_qiblaData.directionText}',
                            style: const TextStyle(
                              color: ColorsManager.primaryGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282826),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ColorsManager.primaryGold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Distance to Kaaba',
                            style: TextStyle(
                              color: ColorsManager.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_qiblaData.distanceKm.toStringAsFixed(0)} km',
                            style: const TextStyle(
                              color: ColorsManager.primaryGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Coordinates Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF20201E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Heading: ${currentHeading.toStringAsFixed(1)}°',
                      style: const TextStyle(color: ColorsManager.textMuted, fontSize: 11),
                    ),
                    const Text(
                      'Kaaba: 21.42° N, 39.83° E',
                      style: TextStyle(color: ColorsManager.primaryGoldDark, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicCompass(double phoneHeading, bool isFacingQibla) {
    const size = 270.0;
    // Compass dial rotates by -phoneHeading so North on the dial matches real world North
    final dialAngleRad = -phoneHeading * (math.pi / 180.0);
    // Kaaba angle relative to the device's top
    final kaabaAngleRad = (_qiblaData.bearing - phoneHeading) * (math.pi / 180.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Rotating Dial (aligns N, E, S, W with real world direction)
          Transform.rotate(
            angle: dialAngleRad,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222220),
                border: Border.all(
                  color: isFacingQibla
                      ? ColorsManager.primaryGold
                      : ColorsManager.primaryGold.withValues(alpha: 0.35),
                  width: isFacingQibla ? 2.5 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  if (isFacingQibla)
                    BoxShadow(
                      color: ColorsManager.primaryGold.withValues(alpha: 0.25),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  // Cardinal Markings on rotating dial
                  Positioned(
                    top: 14,
                    child: Text(
                      'N',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    child: Text(
                      'E',
                      style: TextStyle(
                        color: ColorsManager.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: ColorsManager.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    child: Text(
                      'W',
                      style: TextStyle(
                        color: ColorsManager.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Kaaba Pointer Needle (rotates smoothly to point towards Kaaba)
          Transform.rotate(
            angle: kaabaAngleRad,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Needle top with Kaaba icon
                  Positioned(
                    top: 32,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ColorsManager.primaryGold,
                            boxShadow: [
                              BoxShadow(
                                color: ColorsManager.primaryGold.withValues(
                                  alpha: isFacingQibla ? 0.9 : 0.6,
                                ),
                                blurRadius: isFacingQibla ? 16 : 10,
                                spreadRadius: isFacingQibla ? 3 : 2,
                              ),
                            ],
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.kaaba,
                            color: Color(0xFF191A19),
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 4.5,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ColorsManager.primaryGold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Needle bottom
                  Positioned(
                    bottom: 40,
                    child: Container(
                      width: 4,
                      height: 52,
                      decoration: BoxDecoration(
                        color: ColorsManager.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Pivot Indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFacingQibla ? ColorsManager.primaryGoldLight : ColorsManager.primaryGold,
              border: Border.all(color: const Color(0xFF191A19), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),

          // Fixed Top Reference Arrow on Phone
          Positioned(
            top: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFacingQibla ? ColorsManager.primaryGold : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
