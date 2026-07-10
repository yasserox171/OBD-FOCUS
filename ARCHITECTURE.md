# Architecture — Focus OBD2 Scanner

The app follows a pragmatic **Clean Architecture**: three layers with
one-directional dependencies (presentation → services/data), small
singletons for infrastructure and Riverpod for all app state.

```
lib/
├── main.dart                    # bootstrap: storage, notifications, Drive session
├── app.dart                     # MaterialApp.router, theme + locale wiring
│
├── core/                        # framework-agnostic building blocks
│   ├── constants/               #   palette (app_colors), thresholds (app_constants)
│   ├── theme/                   #   dark/light ThemeData (Poppins + IBM Plex Arabic)
│   ├── localization/            #   delegate + 150+ string tables (en / ar)
│   ├── router/                  #   GoRouter: StatefulShellRoute, 6 tab branches
│   └── utils/obd_utils.dart     #   ELM327/J1979 response parsing (pure functions)
│
├── data/
│   ├── models/                  # Obd2Record, DtcCode, DailyReport, ObdDevice
│   ├── dtc/dtc_database.dart    # 200+ offline DTC descriptions (en+ar) + severity
│   └── datasources/
│       ├── bluetooth/obd2_service.dart   # ObdInterface: real ELM327 + demo simulator
│       └── local/               # DatabaseHelper (SQLite), PreferencesService (Hive)
│
├── services/                    # single-purpose infrastructure singletons
│   ├── notification_service.dart  # channels, threshold alerts, daily schedule
│   ├── report_service.dart        # aggregates a day + renders the PDF
│   ├── export_service.dart        # CSV / JSON serialization
│   ├── share_service.dart         # WhatsApp/share-sheet message templates
│   └── drive_service.dart         # Google Sign-In + Drive uploads (drive.file)
│
└── presentation/
    ├── providers/               # Riverpod Notifiers = all app state
    ├── shell/main_shell.dart    # bottom navigation (6 tabs)
    ├── screens/                 # home, dashboard, dtc, history, reports, settings
    └── widgets/                 # CircularGauge, LabeledProgressBar, MetricTile,
                                 # ExpandableDtcCard, StatusBanner
```

## Key decisions

### State management — Riverpod `Notifier`s
Each feature has one provider owning an immutable state class with
`copyWith`. UI is `ConsumerWidget`s that `watch` state and call notifier
methods. Cross-feature reactions use `ref.listen` (e.g. the live-data loop
starts/stops when `connectionProvider` changes).

### The vehicle link — `ObdInterface`
`Obd2Service` (real ELM327 over `flutter_bluetooth_serial`) and
`DemoObdService` (simulator) implement the same interface, so every screen
and provider is hardware-agnostic. The real service:

- serializes commands on a queue (one in flight at a time),
- buffers received bytes until the `>` prompt,
- times out gracefully (`NO DATA`) so one dead PID never stalls the loop.

### Polling & persistence
`LiveDataNotifier` polls all 9 values once per second (Dashboard refresh)
but persists to SQLite only every 30 s — 1 Hz would blow the retention
budget with no analytical value. Threshold alerts are debounced
(temp: 5 min, fuel: 30 min).

### Data retention (SQLite)
Runs once per day, on first connection:
1. Records older than 30 days are **compacted** into one averaged row per
   day, then the raw rows are deleted.
2. A hard cap keeps the newest **500** rows.

Tables: `obd2_records` (indexed on `timestamp`), `dtc_codes` (upsert per
active code; clearing stamps `cleared_date` instead of deleting history),
`daily_reports` (unique per day, pruned to 30), `devices` (favorites +
connection stats).

### Localization
A dependency-free `LocalizationsDelegate` with two string tables and an
`context.tr('key')` extension. Missing keys fall back to English, then the
key itself. RTL comes free from `MaterialApp.locale` — the framework flips
layout, and `EdgeInsetsDirectional` is used where sides matter.
Report recommendations are stored as **keys** and localized at render time,
so switching language re-localizes old reports too.

### Offline-first
Everything reads/writes local storage. Drive exports check connectivity
first; when offline they are queued in Hive and flushed by
`HistoryNotifier.flushPendingExports()` when connectivity returns. The
`StatusBanner` on every screen shows both link states (Bluetooth + network).

### Background limits (deliberate)
Android cannot run Dart reliably in the background without a foreground
service. The daily report is therefore: a scheduled *notification* at the
configured time + report *generation* on app open (backfilling yesterday
when missed). This keeps battery usage near zero.

## Extending the app

| Goal | Where |
|---|---|
| New PID / gauge | `ObdUtils` decoder → `Obd2Record` field → DB column (bump `_dbVersion` + migration) → Dashboard widget |
| New DTC descriptions | `data/dtc/dtc_database.dart` (add `[en, ar]` entry) |
| New language | `core/localization/strings_xx.dart` + add to `supportedLocales` |
| New screen/tab | screen widget → branch in `app_router.dart` → destination in `main_shell.dart` |
| WiFi/BLE adapters | new `ObdInterface` implementation; nothing above the interface changes |
