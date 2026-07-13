import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../finance/presentation/providers/finance_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .75, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(
      begin: .78,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _navigationTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bangla = ref.watch(
      financeControllerProvider.select((state) => state.bangla),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final topColor = isDark ? const Color(0xFF071A14) : const Color(0xFFE7F5EF);
    final bottomColor = isDark
        ? const Color(0xFF0B6B53)
        : const Color(0xFFBCE6D7);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bottomColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, bottomColor],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                const Positioned(
                  top: -75,
                  right: -65,
                  child: _DecorativeCircle(size: 220, opacity: .08),
                ),
                const Positioned(
                  bottom: -105,
                  left: -80,
                  child: _DecorativeCircle(size: 280, opacity: .07),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: .28),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            bangla ? 'স্মার্ট হিসাব' : 'Smart Hisab',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.8,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bangla
                                ? 'ব্যক্তিগত ও ব্যবসার হিসাব, একসাথে'
                                : 'Personal and business finance, together',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: .68),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 34,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          bangla
                              ? 'নিরাপদ • সহজ • Offline-first'
                              : 'Secure • Simple • Offline-first',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: .4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
    ),
  );
}
