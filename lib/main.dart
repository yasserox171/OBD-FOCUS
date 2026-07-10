import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/datasources/local/preferences_service.dart';
import 'services/drive_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only — the dashboard layout is designed for portrait.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Local storage first: settings drive locale/theme from the first frame.
  await PreferencesService.instance.init();

  // Date formatting for both locales (intl).
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // Notifications (channels + daily report schedule restored by settings).
  await NotificationService.instance.init();

  // Restore a previous Drive session silently (never blocks startup).
  // ignore: unawaited_futures
  DriveService.instance.signInSilently();

  runApp(const ProviderScope(child: FocusObd2App()));
}
