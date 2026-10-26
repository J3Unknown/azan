import 'package:azan/layouts/bloc/home_layout_cubit.dart';
import 'package:azan/layouts/bloc/home_layout_states.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeLayout extends StatelessWidget {
  const HomeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeLayoutCubit, HomeLayoutStates>(
      builder: (context, state) {
        final cubit = context.read<HomeLayoutCubit>();

        return Scaffold(
          backgroundColor: const Color(0xFF191A19),
          body: IndexedStack(
            index: cubit.currentIndex,
            children: cubit.screens,
          ),
          bottomNavigationBar: _buildBottomNav(context, cubit),
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context, HomeLayoutCubit cubit) {
    final navItems = [
      {'icon': FontAwesomeIcons.house, 'label': 'Home'},
      {'icon': FontAwesomeIcons.compass, 'label': 'Qibla'},
      {'icon': FontAwesomeIcons.bookOpen, 'label': 'Quran'},
      {'icon': FontAwesomeIcons.handsPraying, 'label': 'Supplications'},
      {'icon': FontAwesomeIcons.gear, 'label': 'Settings'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF222220),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (index) {
            final isSelected = cubit.currentIndex == index;
            final item = navItems[index];

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => cubit.changeBottomSheetIndex(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorsManager.primaryGold.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: ColorsManager.primaryGold.withValues(alpha: 0.25),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: FaIcon(
                      item['icon'] as FaIconData,
                      size: 19,
                      color: isSelected
                          ? ColorsManager.primaryGold
                          : ColorsManager.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? ColorsManager.primaryGold
                          : ColorsManager.textMuted,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
