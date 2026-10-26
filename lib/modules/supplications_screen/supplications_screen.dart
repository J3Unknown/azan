import 'package:azan/modules/athkar_screen/athkar_screen.dart';
import 'package:azan/modules/reminders_screen/reminders_screen.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:flutter/material.dart';

class SupplicationsScreen extends StatefulWidget {
  const SupplicationsScreen({super.key});

  @override
  State<SupplicationsScreen> createState() => _SupplicationsScreenState();
}

class _SupplicationsScreenState extends State<SupplicationsScreen> {
  int _selectedTab = 0; // 0: Athkar, 1: Daily Reminders

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191A19),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('Athkar', 0),
                const SizedBox(width: 12),
                _buildTabButton('Daily Reminders', 1),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          AthkarScreen(),
          RemindersScreen(),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ColorsManager.primaryGold : const Color(0xFF282826),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ColorsManager.primaryGold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF191A19) : ColorsManager.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
