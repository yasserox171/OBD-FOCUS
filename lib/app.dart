import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/live_data_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'services/notification_service.dart';

/// Root widget: wires theme, locale (with RTL for Arabic handled by the
/// framework), routing and notification deep-links.
class FocusObd2App extends ConsumerStatefulWidget {
  const FocusObd2App({super.key});

  @override
  ConsumerState<FocusObd2App> createState() => _FocusObd2AppState();
}

class _FocusObd2AppState extends ConsumerState<FocusObd2App> {
  @override
  void initState() {
    super.initState();
    // Notification taps deep-link into the matching tab.
    NotificationService.instance.onNotificationTap = (route) {
      appRouter.go(route);
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // Instantiate the live-data loop so it starts/stops with the connection
    // even before the Dashboard tab is first opened.
    ref.watch(liveDataProvider);

    return MaterialApp.router(
      title: 'Focus OBD2 Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
