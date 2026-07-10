import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants/app_constants.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/models/daily_report.dart';

/// Builds the daily performance report: aggregates the day's records,
/// derives smart recommendations, renders a PDF and stores the summary row.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  /// Generates (or regenerates) the report for [day]. Returns null when the
  /// day has no records at all.
  Future<DailyReport?> generateDailyReport(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final db = DatabaseHelper.instance;
    final stats = await db.recordStats(from: dayStart, to: dayEnd);
    if (stats.count == 0) return null;

    final dtcCount = await db.dtcCountSince(dayStart);
    final recommendations = buildRecommendations(stats, dtcCount);

    final pdfFile = await _renderPdf(
      day: dayStart,
      stats: stats,
      dtcCount: dtcCount,
      recommendations: recommendations,
    );

    final report = DailyReport(
      date: dayStart,
      pdfPath: pdfFile.path,
      summary: recommendations.join('\n'),
      averageTemp: stats.avgTemp,
      maxTemp: stats.maxTemp,
      minTemp: stats.minTemp,
      averageRpm: stats.avgRpm,
      maxRpm: stats.maxRpm,
      averageFuel: stats.avgFuel,
      minFuel: stats.minFuel,
      maxSpeed: stats.maxSpeed,
      dtcCount: dtcCount,
      recordCount: stats.count,
    );
    await db.upsertReport(report);
    await db.pruneReports();
    return report;
  }

  /// Rule-based recommendations, returned as localization keys so the UI
  /// renders them in the active language.
  List<String> buildRecommendations(RecordStats stats, int dtcCount) {
    final recs = <String>[];
    if ((stats.maxTemp ?? 0) > AppConstants.engineTempCriticalC) {
      recs.add('recOverheat');
    }
    if ((stats.avgRpm ?? 0) > 3500) recs.add('recHighRpm');
    if ((stats.minFuel ?? 100) < AppConstants.fuelLowPercent) {
      recs.add('recLowFuel');
    }
    if (dtcCount > 0) recs.add('recDtc');
    if (recs.isEmpty) recs.add('recAllGood');
    return recs;
  }

  Future<File> _renderPdf({
    required DateTime day,
    required RecordStats stats,
    required int dtcCount,
    required List<String> recommendations,
  }) async {
    final doc = pw.Document();
    const accent = PdfColor.fromInt(0xFF1E90FF);
    const mutedBg = PdfColor.fromInt(0xFFF0F4F8);

    String n(double? v, {int digits = 0, String unit = ''}) =>
        v == null ? '—' : '${v.toStringAsFixed(digits)}$unit';

    // English labels for recommendation keys (the PDF is a shareable
    // document, kept in English for universal readability).
    const recTexts = {
      'recOverheat':
          'Engine temperature exceeded 110°C — check coolant, radiator and thermostat.',
      'recHighRpm':
          'Sustained high RPM detected — gentler acceleration reduces wear.',
      'recLowFuel':
          'Fuel dropped below 15% — avoid running low to protect the fuel pump.',
      'recDtc': 'New trouble codes were detected — review the DTC screen.',
      'recBattery':
          'Battery voltage was outside the healthy range — test battery/alternator.',
      'recAllGood': 'Everything looks good. Keep up the regular maintenance!',
    };

    pw.Widget statRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Focus OBD2 Scanner — Daily Report',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(_dateFmt.format(day),
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Performance summary',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: mutedBg,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(children: [
                statRow('Records logged', '${stats.count}'),
                statRow('Engine temperature (avg / max / min)',
                    '${n(stats.avgTemp)} / ${n(stats.maxTemp)} / ${n(stats.minTemp)} °C'),
                statRow('RPM (avg / max)',
                    '${n(stats.avgRpm)} / ${n(stats.maxRpm)}'),
                statRow('Speed (avg / max)',
                    '${n(stats.avgSpeed)} / ${n(stats.maxSpeed)} km/h'),
                statRow('Fuel level (avg / min)',
                    '${n(stats.avgFuel, digits: 1)} / ${n(stats.minFuel, digits: 1)} %'),
                statRow('New trouble codes', '$dtcCount'),
              ]),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Recommendations',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...recommendations.map(
              (key) => pw.Bullet(
                text: recTexts[key] ?? key,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              'Generated by Focus OBD2 Scanner • data stays on your device',
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(dir.path, 'reports'));
    if (!reportsDir.existsSync()) reportsDir.createSync(recursive: true);
    final file =
        File(p.join(reportsDir.path, 'report_${_dateFmt.format(day)}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
