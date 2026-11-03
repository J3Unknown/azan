import 'package:azan/modules/bukhari_screen/bukhari_screen.dart';
import 'package:azan/modules/settings_screen/settings_screen.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.tr('Menu'),
              style: TextStyle(
                color: ColorsManager.textPrimary,
                fontSize: 25,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 20),
            _MenuTile(
              icon: Icons.menu_book_rounded,
              title: context.tr('Sahih al-Bukhari'),
              subtitle: context.tr('Browse chapters and search all hadiths'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const BukhariScreen())),
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.settings_rounded,
              title: context.tr('Settings'),
              subtitle: context.tr('Prayer location and app preferences'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(showBackButton: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF282826),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Icon(icon, color: ColorsManager.primaryGold, size: 26),
        title: Text(
          title,
          style: const TextStyle(color: ColorsManager.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: ColorsManager.textMuted),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: ColorsManager.primaryGold,
        ),
        onTap: onTap,
      ),
    );
  }
}
