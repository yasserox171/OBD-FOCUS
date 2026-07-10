import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/datasources/local/database_helper.dart';
import '../../../data/datasources/local/preferences_service.dart';
import '../../../services/drive_service.dart';
import '../../providers/settings_provider.dart';

/// Settings: language (instant switch), theme, Google Drive account,
/// notification toggles, report time, database stats and about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _recordCount = 0;
  int _dbSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadDbStats();
  }

  Future<void> _loadDbStats() async {
    final count = await DatabaseHelper.instance.recordCount();
    final size = await DatabaseHelper.instance.databaseSizeBytes();
    if (mounted) {
      setState(() {
        _recordCount = count;
        _dbSizeBytes = size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('navSettings'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Section(title: context.tr('language')),
          Card(
            child: Column(children: [
              RadioListTile<String>(
                value: 'ar',
                groupValue: settings.locale.languageCode,
                onChanged: (v) => notifier.setLanguage(v!),
                title: Text(context.tr('arabic')),
              ),
              RadioListTile<String>(
                value: 'en',
                groupValue: settings.locale.languageCode,
                onChanged: (v) => notifier.setLanguage(v!),
                title: Text(context.tr('english')),
              ),
            ]),
          ),

          _Section(title: context.tr('appearance')),
          Card(
            child: SwitchListTile(
              value: settings.isDarkMode,
              onChanged: notifier.setDarkMode,
              title: Text(context
                  .tr(settings.isDarkMode ? 'darkMode' : 'lightMode')),
              secondary: Icon(settings.isDarkMode
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined),
            ),
          ),

          _Section(title: context.tr('googleDrive')),
          const _DriveCard(),

          _Section(title: context.tr('notifications')),
          Card(
            child: Column(children: [
              SwitchListTile(
                value: settings.tempAlerts,
                onChanged: notifier.setTempAlerts,
                title: Text(context.tr('tempAlerts')),
                secondary: const Icon(Icons.thermostat,
                    color: AppColors.danger),
              ),
              SwitchListTile(
                value: settings.dtcAlerts,
                onChanged: notifier.setDtcAlerts,
                title: Text(context.tr('dtcAlerts')),
                secondary: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning),
              ),
              SwitchListTile(
                value: settings.fuelAlerts,
                onChanged: notifier.setFuelAlerts,
                title: Text(context.tr('fuelAlerts')),
                secondary: const Icon(Icons.local_gas_station,
                    color: AppColors.warning),
              ),
              SwitchListTile(
                value: settings.dailyReport,
                onChanged: notifier.setDailyReport,
                title: Text(context.tr('dailyReportNotif')),
                secondary: const Icon(Icons.description_outlined,
                    color: AppColors.accentCyan),
              ),
              ListTile(
                enabled: settings.dailyReport,
                leading: const Icon(Icons.schedule),
                title: Text(context.tr('reportTime')),
                trailing: Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay(
                        hour: settings.reportHour,
                        minute: settings.reportMinute),
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(color: AppColors.accentCyan),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                        hour: settings.reportHour,
                        minute: settings.reportMinute),
                  );
                  if (picked != null) {
                    await notifier.setReportTime(picked.hour, picked.minute);
                  }
                },
              ),
            ]),
          ),

          _Section(title: context.tr('database')),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(context.tr('recordCount')),
                trailing: Text('$_recordCount / ${AppConstants.maxRecords}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text(context.tr('dbSize')),
                trailing: Text(_formatBytes(_dbSizeBytes),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
          ),

          _Section(title: context.tr('about')),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.tr('appName')),
                subtitle: Text(
                    '${context.tr('version')} ${AppConstants.appVersion}'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.privacy_tip_outlined, color: AppColors.success),
                title: Text(context.tr('privacy')),
                subtitle: Text(context.tr('privacyDesc'),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DriveCard extends ConsumerStatefulWidget {
  const _DriveCard();

  @override
  ConsumerState<_DriveCard> createState() => _DriveCardState();
}

class _DriveCardState extends ConsumerState<_DriveCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final drive = DriveService.instance;
    final lastBackup = PreferencesService.instance.lastBackup;
    final fmt = DateFormat.yMMMd(context.l10n.locale.languageCode).add_Hm();

    return Card(
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.add_to_drive, color: AppColors.primaryBlue),
          title: Text(
            drive.isSignedIn
                ? '${context.tr('signedInAs')} ${drive.currentUser?.email ?? ''}'
                : context.tr('notSignedIn'),
          ),
          subtitle: Text(
            lastBackup != null
                ? '${context.tr('lastBackup')}: ${fmt.format(lastBackup)}'
                : context.tr('driveDesc'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: () async {
                    setState(() => _busy = true);
                    if (drive.isSignedIn) {
                      await drive.signOut();
                    } else {
                      await drive.signIn();
                    }
                    if (mounted) setState(() => _busy = false);
                  },
                  child: Text(context
                      .tr(drive.isSignedIn ? 'signOut' : 'signIn')),
                ),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: AppColors.accentCyan)),
    );
  }
}
