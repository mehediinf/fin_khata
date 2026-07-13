import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/finance/presentation/providers/finance_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FinKhataApp extends ConsumerWidget {
  const FinKhataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    return MaterialApp.router(
      title: 'ফিনখাতা',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(state.bangla ? 'bn' : 'en'),
      supportedLocales: const [Locale('bn'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
