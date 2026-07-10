# API Reference — Focus OBD2 Scanner

Internal API documentation for the main classes. All paths relative to `lib/`.

---

## Vehicle link

### `ObdInterface` — `data/datasources/bluetooth/obd2_service.dart`

Abstraction implemented by `Obd2Service` (real ELM327) and `DemoObdService` (simulator).

| Member | Description |
|---|---|
| `bool get isConnected` | Link state |
| `Future<void> connect(String address)` | Opens the link (MAC address; ignored by the demo) and initializes the adapter |
| `Future<void> disconnect()` | Closes the link |
| `Future<LiveDataFrame> readLiveData()` | Polls all 9 live values; unsupported PIDs come back `null` |
| `Future<DtcReadResult> readDtcs()` | Modes 03 (confirmed), 07 (pending), 0A (permanent) |
| `Future<bool> clearDtcs()` | Mode 04; `true` when the ECU acknowledged (`44`) |
| `String get protocolName` | e.g. `ISO 15765-4 (CAN 11/500)` after auto-detection |

**ELM327 init sequence:** `ATZ → ATE0 → ATL0 → ATS0 → ATH0 → ATSP0 → 0100 → ATDP`

### `ObdUtils` — `core/utils/obd_utils.dart` (pure static functions)

| Function | PID | Formula |
|---|---|---|
| `coolantTemp` | `0105` | `A − 40` °C |
| `rpm` | `010C` | `(256·A + B) / 4` |
| `speed` | `010D` | `A` km/h |
| `fuelLevel` | `012F` | `A·100/255` % |
| `throttle` | `0111` | `A·100/255` % |
| `intakeAirTemp` | `010F` | `A − 40` °C |
| `oxygenSensor` | `0114` | `A / 200` V |
| `milOn` | `0101` | bit 7 of byte A |
| `batteryVoltage` | `ATRV` | parses `12.6V` |
| `decodeDtcs(raw, mode)` | `03/07/0A` | 2-byte pairs → `P/C/B/U` + 4 digits |

---

## Storage

### `DatabaseHelper` — `data/datasources/local/database_helper.dart` (singleton `.instance`)

| Method | Notes |
|---|---|
| `insertRecord(Obd2Record)` | |
| `getRecords({limit, offset, from, to})` | Newest first; page size defaults to 50 |
| `recordStats({from, to})` → `RecordStats` | avg/max/min aggregates in SQL |
| `enforceRetention()` | Compacts >30-day rows to daily averages, caps at 500 rows |
| `upsertDtc(DtcCode)` → `bool` | `true` when the code is newly detected (drives alerts) |
| `getDtcs({activeOnly})` / `markDtcsCleared()` | Clearing stamps `cleared_date`, history preserved |
| `upsertReport` / `getReports` / `pruneReports()` | One report per day, newest 30 kept |
| `getDevices` / `saveDevice` / `recordConnection` / `setFavorite` | Adapter memory |
| `databaseSizeBytes()` | For the Settings screen |

### `PreferencesService` — Hive (singleton `.instance`)

Settings: `languageCode` (default `ar`), `isDarkMode` (default `true`), alert toggles, `reportHour/Minute` (default 23:00).
Cache: `lastDeviceAddress`, `lastRetentionRun`, `lastBackup`, `pendingExports` (offline queue).

### `DtcDatabase` — `data/dtc/dtc_database.dart`

`describeEn/describeAr/describe(code)` — 200+ known codes; unknown codes get a generated generic description from the SAE J2012 structure. `severityOf(code)` → `critical | moderate | low`.

---

## Services (singletons, `.instance`)

| Service | Key methods |
|---|---|
| `NotificationService` | `init()`, `showTempAlert/DtcAlert/FuelAlert/ReportReady`, `scheduleDailyReport({hour, minute, ...})`, `onNotificationTap` (deep-link hook) |
| `ReportService` | `generateDailyReport(day)` → aggregates, renders PDF, stores `DailyReport`; `buildRecommendations(stats, dtcCount)` → localization keys |
| `ExportService` | `exportCsv()` / `exportJson()` → `File` in app documents `/exports` |
| `ShareService` | `buildSummaryMessage({stats, dtcCount, from, to, arabic})` (spec template), `shareText`, `shareFile` |
| `DriveService` | `signIn/signOut/signInSilently`, `uploadFile(file, mimeType)` — creates/reuses the "Focus OBD2 Scanner" folder; `drive.file` scope |

---

## Providers (Riverpod)

| Provider | State | Purpose |
|---|---|---|
| `settingsProvider` | `SettingsState` | locale, theme, alert toggles, report time (persists + reschedules) |
| `connectionProvider` | `ObdConnectionState` | connect/disconnect/demo; exposes `notifier.obd` (`ObdInterface`) |
| `deviceScanProvider` | `DeviceScanState` | permissions, bonded + discovery merge, favorites |
| `liveDataProvider` | `LiveDataState` | 1 s polling loop, 30 s persistence, alert debouncing, daily retention |
| `dtcProvider` | `DtcState` | read/clear codes, filter, new-code alerts |
| `historyProvider` | `HistoryState` | pagination, range filter, stats, Drive export + offline queue |
| `reportsProvider` | `ReportsState` | list, generate (+ missed-day backfill), Drive upload |
| `connectivityProvider` | `Stream<bool>` | online/offline for the `StatusBanner` |

---

## Widgets

| Widget | Props |
|---|---|
| `CircularGauge` | `value, min, max, warnFrom, dangerFrom, label, unit, valueText, size` — animated needle + color zones |
| `LabeledProgressBar` | `label, value(0-100), icon, color, warnBelow` |
| `MetricTile` | `icon, label, value, subtitle, color, pulse` (pulse = check-engine halo) |
| `ExpandableDtcCard` | `dtc` — collapsed code/chips, expanded description + dates |
| `StatusBanner` | none — watches connection + connectivity |

## Localization

`context.tr('key')` / `context.l10n.isArabic` — see `core/localization/strings_en.dart` for all keys. `tr` supports `{placeholder}` substitution via an optional args map.
