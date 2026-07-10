# Changelog

All notable changes to Focus OBD2 Scanner.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] — 2026-07-10

### Added
- **Home**: Bluetooth device scanning (bonded + live discovery), favorites, connection status, per-device history (last connected, connection count), demo mode with a built-in vehicle simulator.
- **Dashboard**: live data refreshed every second — animated gauges for engine temperature (danger zone > 110 °C), RPM and speed; fuel & throttle progress bars; battery voltage health; O₂ sensor; intake air temperature; pulsing check-engine indicator.
- **DTC Codes**: read Modes 03/07/0A (confirmed / pending / permanent), offline database of 200+ codes with Arabic & English descriptions and severity classification, expandable cards, status filtering, clear codes (Mode 04) behind a confirmation dialog.
- **History**: paginated records (50 per page), date-range filters, temperature line chart, RPM bar chart, speed area chart, aggregate stats, CSV/JSON export to Google Drive (queued when offline), WhatsApp share message, delete-all with confirmation.
- **Reports**: daily PDF report with performance summary and rule-based recommendations, automatic generation backfill on launch, scheduled daily notification (default 11 PM, configurable), last 30 reports kept, share + Drive upload per report.
- **Settings**: instant Arabic/English switching with full RTL, dark (default) / light theme, Google Drive sign-in/out, individual notification toggles, daily report time picker, database size & record count, privacy statement.
- **Alerts**: engine temp > 110 °C (critical, sound + vibration), new DTC detected, fuel < 15 % (quiet), daily report ready (silent, deep-links to Reports).
- **Data management**: SQLite with indexes, 500-record cap, 30-day retention with compaction into daily averages, Hive settings/cache, offline export queue.
- Android platform configuration (API 21+, Android 12+ Bluetooth permissions, notification channels, boot-persistent schedules).
- Documentation: README, SETUP, ARCHITECTURE, API_REFERENCE.

[1.0.0]: https://github.com/yasserox171/OBD-FOCUS/releases/tag/v1.0.0
