import 'package:flutter/widgets.dart';

import '../core/localization/app_localizations.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/models/obd2_record.dart';
import '../services/share_service.dart';

/// Small presentation-side bridge to the sharing service: derives the
/// share period from the loaded records and localizes the message.
abstract class ServicesGlue {
  static String buildShareMessage({
    required BuildContext context,
    required RecordStats stats,
    required List<Obd2Record> records,
    int dtcCount = 0,
  }) {
    final now = DateTime.now();
    // Records are newest-first.
    final to = records.isNotEmpty ? records.first.timestamp : now;
    final from = records.isNotEmpty ? records.last.timestamp : now;

    return ShareService.instance.buildSummaryMessage(
      stats: stats,
      dtcCount: dtcCount,
      from: from,
      to: to,
      arabic: context.l10n.isArabic,
    );
  }

  static Future<void> shareText(String text) =>
      ShareService.instance.shareText(text);

  static Future<void> shareFile(String path, {String? text}) =>
      ShareService.instance.shareFile(path, text: text);
}
