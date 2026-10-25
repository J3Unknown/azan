import 'package:azan/layouts/bloc/home_layout_cubit.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/icons_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  late HomeLayoutCubit cubit;

  @override
  void initState() {
    super.initState();
    cubit = context.read<HomeLayoutCubit>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cubit.appbarTitles[cubit.currentIndex]),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(IconsManager.darkThemeIcon)),
        ],
      ),
      body: IndexedStack(index: cubit.currentIndex, children: cubit.screens),
      bottomNavigationBar: NavigationBar(
        labelBehavior: .alwaysHide,
        onDestinationSelected: (value) => cubit.changeBottomSheetIndex,
        overlayColor: WidgetStatePropertyAll(ColorsManager.primaryColor),
        backgroundColor: ColorsManager.darkThemeSecondaryColor,
        selectedIndex: cubit.currentIndex,
        destinations: [
          NavigationDestination(icon: FaIcon(IconsManager.homeIcon), label: ''),
          NavigationDestination(
            icon: FaIcon(IconsManager.azkarIcon),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(IconsManager.checkListIcon),
            label: '',
          ),
        ],
      ),
    );
  }
}
