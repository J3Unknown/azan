import 'package:azan/layouts/bloc/home_layout_cubit.dart';
import 'package:azan/layouts/home_layout.dart';
import 'package:azan/modules/splash_screen/splash_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:azan/modules/community/auth_screen.dart';
import 'package:azan/services/community_service.dart';
import 'package:flutter/material.dart';

class GoRouterConfig {
  static final String initialRoute = '/';
  static final String home = '/home';

  static final routes = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            CommunityService.configured &&
                CommunityService.client.auth.currentSession != null
            ? const AuthScreen(page: AuthPage.reset)
            : const Scaffold(
                body: Center(
                  child: Text(
                    'Open a valid password reset link from your email.',
                  ),
                ),
              ),
      ),
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
