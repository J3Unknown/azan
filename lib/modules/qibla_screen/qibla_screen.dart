import 'dart:async';
import 'dart:math' as math;
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/helpers/ui_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class QiblaScreen extends StatefulWidget {
  final bool isActive;

  const QiblaScreen({super.key, this.isActive = false});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const MethodChannel _compassChannel = MethodChannel('azan/compass');
  String _city = 'Cairo, Egypt';
  final DateTime _currentDate = DateTime.now();
  double _userLat = 30.0444;
  double _userLng = 31.2357;
  late QiblaData _qiblaData;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double? _deviceHeading; // Heading from North in degrees (0..360)
  double? _headingAccuracy;
  double _magneticDeclination = 0;
  bool _useCameraHeading = false;
  bool _hasCompassSensor = true;
  bool _locationPermissionDenied = false;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _qiblaData = calculateQibla(_userLat, _userLng);
    if (widget.isActive) _initCompass();
  }

  @override
  void didUpdateWidget(covariant QiblaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _initCompass();
    } else {
      _compassSubscription?.cancel();
      _accelerometerSubscription?.cancel();
      _compassSubscription = null;
      _accelerometerSubscription = null;
      _deviceHeading = null;
      _headingAccuracy = null;
      _wasAligned = false;
    }
  }

  void _initCompass() {
    _startCompassStream();
  }

  Future<void> _startCompassStream() async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted || !widget.isActive) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _hasCompassSensor = false;
          _locationPermissionDenied = true;
        });
        return;
      }
    }
    if (!mounted || !widget.isActive) return;

    _compassSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        if (!mounted) return;
        // With the screen facing up, gravity is mostly on the Z axis. When
        // upright, gravity is mostly on X or Y, so use the back-facing axis.
        final screenNormalGravity = event.z.abs();
        // Hysteresis prevents rapid axis switching around the transition angle.
        final useCameraHeading = _useCameraHeading
            ? screenNormalGravity < 7.5
            : screenNormalGravity < 5.5;
        if (useCameraHeading != _useCameraHeading) {
          setState(() => _useCameraHeading = useCameraHeading);
        }
      },
      onError: (_) {},
    );
    final stream = FlutterCompass.eventsFor(CompassUpdateOptions.balanced);
    if (stream == null) {
      setState(() {
        _hasCompassSensor = false;
      });
      return;
    }

    _compassSubscription = stream.listen(
      (CompassEvent event) {
        if (!mounted) return;
        final heading = _useCameraHeading
            ? (event.headingForCameraMode ?? event.heading)
            : event.heading;
        if (heading != null) {
          // Android reports magnetic north; convert it to true north before
          // comparing it with the geographic Qibla bearing.
          final correctedHeading = _normalizeHeading(
            heading + _magneticDeclination,
          );
          final diff = (_qiblaData.bearing - correctedHeading).abs() % 360;
          final reportedAccuracy = event.accuracy;
          final accuracy = reportedAccuracy != null && reportedAccuracy >= 0
              ? reportedAccuracy
              : null;
          final tolerance = accuracy == null
              ? 5.0
              : math.max(3.0, math.min(accuracy, 10.0));
          final isAligned =
              (accuracy != null && accuracy <= 30) &&
              (diff <= tolerance || diff >= 360 - tolerance);

          if (isAligned && !_wasAligned) {
            HapticFeedback.mediumImpact();
          }
          _wasAligned = isAligned;

          setState(() {
            _deviceHeading = heading;
            _headingAccuracy = accuracy;
            _hasCompassSensor = true;
            _locationPermissionDenied = false;
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _hasCompassSensor = false;
          });
        }
      },
    );
  }

  double _normalizeHeading(double heading) => (heading % 360 + 360) % 360;

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _accelerometerSubscription?.cancel();
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
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final declination = await _compassChannel.invokeMethod<num>(
          'getMagneticDeclination',
          {'latitude': _userLat, 'longitude': _userLng},
        );
        if (mounted && declination != null) {
          setState(() => _magneticDeclination = declination.toDouble());
        }
      } on PlatformException {
        // Fall back to the device's magnetic heading if the model is unavailable.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current heading in degrees; default to 0 if sensor not ready
    final currentHeading = _normalizeHeading(
      (_deviceHeading ?? 0.0) + _magneticDeclination,
    );
    // Calculate angle difference relative to phone top
    final diffDegrees = (_qiblaData.bearing - currentHeading + 360) % 360;
    final tolerance = _headingAccuracy == null
        ? 5.0
        : math.max(3.0, math.min(_headingAccuracy!, 10.0));
    final isFacingQibla =
        (_headingAccuracy != null && _headingAccuracy! <= 30) &&
        (diffDegrees <= tolerance || diffDegrees >= 360 - tolerance);

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
                    UiHelpers.formatDate(
                      _currentDate,
                      arabic:
                          Localizations.localeOf(context).languageCode == 'ar',
                    ),
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
              Text(
                context.tr('Qibla Direction'),
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
                    ? context.tr('✨ You are facing the Holy Kaaba!')
                    : context.tr(
                        _useCameraHeading
                            ? 'Point the back of your phone toward the Qibla.'
                            : 'Lay your phone flat and turn until the Qibla marker points up.',
                      ),
                style: TextStyle(
                  color: isFacingQibla
                      ? ColorsManager.primaryGoldLight
                      : ColorsManager.textMuted,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sensors_off, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Text(
                        context.tr(
                          _locationPermissionDenied
                              ? 'Location permission is needed for compass heading.'
                              : 'Compass sensor not detected. Showing calculated angle.',
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282826),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFacingQibla
                              ? ColorsManager.primaryGold
                              : ColorsManager.primaryGold.withValues(
                                  alpha: 0.2,
                                ),
                          width: isFacingQibla ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            context.tr('Qibla Bearing'),
                            style: TextStyle(
                              color: ColorsManager.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${UiHelpers.localizeDigits(_qiblaData.bearing.toStringAsFixed(1), arabic: Localizations.localeOf(context).languageCode == 'ar')}° ${context.tr(_qiblaData.directionText)}',
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282826),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ColorsManager.primaryGold.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            context.tr('Distance to Kaaba'),
                            style: TextStyle(
                              color: ColorsManager.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${UiHelpers.localizeDigits(_qiblaData.distanceKm.toStringAsFixed(0), arabic: Localizations.localeOf(context).languageCode == 'ar')} ${context.tr('km')}',
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
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF20201E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${context.tr('Heading:')} ${UiHelpers.localizeDigits(currentHeading.toStringAsFixed(1), arabic: Localizations.localeOf(context).languageCode == 'ar')}°${_headingAccuracy == null ? '' : ' ±${_headingAccuracy!.toStringAsFixed(0)}°'}',
                      style: const TextStyle(
                        color: ColorsManager.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      context.tr('Kaaba: 21.42° N, 39.83° E'),
                      style: TextStyle(
                        color: ColorsManager.primaryGoldDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_deviceHeading != null &&
                  (_headingAccuracy == null || _headingAccuracy! > 20))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr(
                      'Compass accuracy is low. Move away from metal or magnets and move the phone in a figure eight.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
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
    final kaabaAngleRad =
        (_qiblaData.bearing - phoneHeading) * (math.pi / 180.0);

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
              color: isFacingQibla
                  ? ColorsManager.primaryGoldLight
                  : ColorsManager.primaryGold,
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
                color: isFacingQibla
                    ? ColorsManager.primaryGold
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
