import 'package:azan/layouts/bloc/home_layout_states.dart';
import 'package:azan/modules/home_screen/home_screen.dart';
import 'package:azan/modules/menu_screen/menu_screen.dart';
import 'package:azan/modules/qibla_screen/qibla_screen.dart';
import 'package:azan/modules/quran_screen/quran_screen.dart';
import 'package:azan/modules/supplications_screen/supplications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeLayoutCubit extends Cubit<HomeLayoutStates> {
  HomeLayoutCubit() : super(HomeLayoutInitState());

  int currentIndex = 0;

  List<Widget> screens({required bool qiblaActive}) => [
    const HomeScreen(),
    QiblaScreen(isActive: qiblaActive),
    const QuranScreen(),
    const SupplicationsScreen(),
    const MenuScreen(),
  ];

  void changeBottomSheetIndex(int newIndex) {
    if (currentIndex == newIndex) return;
    currentIndex = newIndex;
    emit(HomeLayoutChangeBottomSheetState());
  }
}
