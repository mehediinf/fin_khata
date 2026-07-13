import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/finance/presentation/screens/home_shell.dart';
import '../../features/premium/presentation/premium_insights_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeGate(),
      ),
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (context, state) => const PremiumInsightsScreen(),
      ),
    ],
  ),
);
