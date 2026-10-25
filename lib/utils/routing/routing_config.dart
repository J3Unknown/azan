import 'package:azan/layouts/bloc/home_layout_cubit.dart';
import 'package:azan/layouts/home_layout.dart';
import 'package:azan/modules/splash_screen/splash_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class GoRouterConfig {
  static final String initialRoute = '/';
  static final String home = '/home';

  static final routes = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(path: initialRoute, builder: (context, state) => SplashScreen()),
      GoRoute(
        path: home,
        builder: (context, state) => BlocProvider(
          create: (context) => HomeLayoutCubit(),
          child: HomeLayout(),
        ),
      ),
    ],
  );
}
