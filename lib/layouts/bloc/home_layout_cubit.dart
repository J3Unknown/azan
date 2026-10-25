import 'package:azan/layouts/bloc/home_layout_states.dart';
import 'package:azan/modules/home_screen/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeLayoutCubit extends Cubit<HomeLayoutStates> {
  HomeLayoutCubit() : super(HomeLayoutInitState());

  int currentIndex = 0;
  List<Widget> screens = [HomeScreen()];
  List<String> appbarTitles = ['Prayer times', 'Athkar', 'Daily Tasks'];
  void changeBottomSheetIndex(int newIndex) {
    if (currentIndex == newIndex) return;
    currentIndex = newIndex;
    emit(HomeLayoutChangeBottomSheetState());
  }
}
