# 🚗 Focus OBD2 Scanner

**A professional, modern car diagnostics app for Android** — connects to ELM327 OBD2 adapters over Bluetooth, shows live vehicle telemetry, reads & clears trouble codes, logs history with charts, generates daily PDF reports, and backs up to your own Google Drive. Offline-first, bilingual (العربية / English), no ads, no tracking.

**تطبيق تشخيص سيارات احترافي وحديث لأندرويد** — يتصل بأجهزة OBD2 (ELM327) عبر البلوتوث، يعرض بيانات السيارة الحية، يقرأ ويحذف أكواد الأعطال، يسجل البيانات مع رسوم بيانية، ينشئ تقارير PDF يومية، ويحفظ نسخاً احتياطية في حسابك الخاص على Google Drive. يعمل بدون إنترنت، ثنائي اللغة، بدون إعلانات وبدون تتبع.

---

## ✨ Features

| Screen | Highlights |
|---|---|
| 🏠 **Home** | Bluetooth device scan, paired & favorite devices, connection status, demo mode |
| 📊 **Dashboard** | Live gauges (engine temp, RPM, speedometer), fuel & throttle bars, battery health, O₂ sensor, intake air, check-engine light — refreshed every second with smooth animations |
| ⚠️ **DTC Codes** | Read Mode 03/07/0A (confirmed / pending / permanent), 200+ code descriptions in Arabic & English, severity classification, expandable cards, filtering, clear codes (Mode 04) with confirmation |
| 📈 **History** | Paginated records (50/page), date filters, line/bar/area charts, CSV/JSON export to Google Drive, WhatsApp sharing, delete with confirmation |
| 📋 **Reports** | Daily PDF report (auto at 11 PM, configurable), performance summary (avg/max/min), smart recommendations, last 30 reports, share & Drive upload |
| ⚙️ **Settings** | Instant Arabic/English switch (full RTL), dark/light theme, Google Drive account, per-alert notification toggles, report time, database stats |

### Smart data management
- SQLite + Hive cache, indexed queries, pagination
- Keeps the newest **500 records**; data older than **30 days** is compacted into daily averages, then pruned — runs automatically once per day
- Full **offline mode**: everything works without internet; Drive exports made while offline are queued and synced when connectivity returns

### Alerts
- 🌡️ Engine temperature > **110 °C** → critical notification (sound + vibration)
- ⚠️ New trouble code detected → warning notification
- 🛢️ Fuel < **15 %** → quiet warning
- 📋 Daily report ready → silent notification that deep-links to the Reports tab

## 🛠️ Tech stack

- **Flutter 3 / Dart 3**, Android 5.0+ (API 21+)
- Clean Architecture: presentation (Riverpod + GoRouter) / services / data (SQLite, Hive, Bluetooth)
- `flutter_bluetooth_serial` (classic SPP for ELM327), `fl_chart`, `pdf` + `printing`, `share_plus`, `google_sign_in` + `googleapis` (Drive, `drive.file` scope only), `flutter_local_notifications`

## 🚀 Quick start

```bash
git clone <this repo>
cd OBD-FOCUS
flutter create --platforms=android .   # regenerates gradle wrapper & launcher icons
flutter pub get
flutter run
```

See **[SETUP.md](SETUP.md)** for full instructions (including Google Drive OAuth setup) and **[ARCHITECTURE.md](ARCHITECTURE.md)** for the code tour.

> 💡 **No adapter handy?** Open the app and tap **Demo mode** on the Home screen — every feature runs against a built-in vehicle simulator.

## 🔒 Privacy

All data stays on your device. Nothing is uploaded unless you explicitly export to your **own** Google Drive (scoped so the app can only see files it created). No ads, no analytics, no tracking.

## 📄 License

Personal-use project. See repository owner for licensing.
