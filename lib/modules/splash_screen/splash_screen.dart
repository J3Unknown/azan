import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/routing/routing_config.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await getCity();
      await Future.wait([
        recalculateAndStorePrayerTimes(),
        checkAndResetAthkarForPrayerTimes(),
        Future.delayed(const Duration(milliseconds: 1600)),
      ]);
    } catch (e) {
      debugPrint('Initialization warning: $e');
    }

    if (mounted) {
      context.go(GoRouterConfig.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF282826),
                  border: Border.all(
                    color: ColorsManager.primaryGold.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorsManager.primaryGold.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.solidMoon,
                    color: ColorsManager.primaryGold,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'AZAN',
                style: TextStyle(
                  color: ColorsManager.textPrimary,
                  fontSize: 28,
                  fontFamily: 'serif',
                  letterSpacing: 6.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prayer Times & Daily Dhikr',
                style: TextStyle(
                  color: ColorsManager.textMuted,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
