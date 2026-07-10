import '../models/dtc_code.dart';

/// Offline reference database of diagnostic trouble codes.
///
/// Each entry maps a code to `[english description, arabic description]`.
/// [DtcDatabase.describe] resolves any code — known codes get their full
/// description, unknown codes get a generated generic description based on
/// the SAE J2012 code structure, so the UI never shows an empty entry.
abstract class DtcDatabase {
  /// English description for [code] (fallback: generic).
  static String describeEn(String code) =>
      _codes[code]?[0] ?? _generic(code, arabic: false);

  /// Arabic description for [code] (fallback: generic).
  static String describeAr(String code) =>
      _codes[code]?[1] ?? _generic(code, arabic: true);

  static String describe(String code, {required bool arabic}) =>
      arabic ? describeAr(code) : describeEn(code);

  static bool isKnown(String code) => _codes.containsKey(code);

  static int get knownCodeCount => _codes.length;

  /// Heuristic severity classification by code family.
  static DtcSeverity severityOf(String code) {
    if (_critical.contains(code)) return DtcSeverity.critical;
    if (code.startsWith('P03')) return DtcSeverity.critical; // misfires
    if (_low.contains(code)) return DtcSeverity.low;
    if (code.startsWith('P044') ||
        code.startsWith('P045') ||
        code.startsWith('P046')) {
      return DtcSeverity.low; // EVAP / fuel level sender
    }
    return DtcSeverity.moderate;
  }

  static const Set<String> _critical = {
    'P0087', 'P0088', 'P0190', 'P0192', 'P0193', // fuel rail pressure
    'P0217', 'P0218', 'P0219', // overheat / overspeed
    'P0520', 'P0521', 'P0522', 'P0523', // oil pressure
    'P0560', 'P0562', 'P0563', // system voltage
    'P0234', 'P0299', // turbo boost
    'P0335', 'P0336', 'P0340', 'P0341', // crank/cam position
    'U0100', 'U0101', 'U0121',
  };

  static const Set<String> _low = {
    'P0457', 'P0456', 'P0442', // small EVAP leaks / loose cap
    'P0460', 'P0461', 'P0462', 'P0463',
    'P0530', 'P0532', 'P0645', // A/C
    'P1000',
  };

  static String _generic(String code, {required bool arabic}) {
    final system = switch (code.isNotEmpty ? code[0] : 'P') {
      'P' => arabic ? 'نظام نقل الحركة/المحرك' : 'powertrain',
      'C' => arabic ? 'الشاسيه' : 'chassis',
      'B' => arabic ? 'الهيكل' : 'body',
      'U' => arabic ? 'شبكة الاتصال' : 'network communication',
      _ => arabic ? 'غير معروف' : 'unknown',
    };
    return arabic
        ? 'عطل في $system (كود غير موجود في قاعدة البيانات المحلية — راجع دليل الصيانة).'
        : 'Fault in the $system system (code not in the offline database — '
            'consult a service manual).';
  }

  // ───────────────────────────────────────────────────────────────────────
  // code → [EN, AR]
  // ───────────────────────────────────────────────────────────────────────
  static const Map<String, List<String>> _codes = {
    // ── P00xx: fuel & air metering, auxiliary emission controls ─────
    'P0010': ['"A" camshaft position actuator circuit (Bank 1)', 'دائرة مشغّل عمود الكامات "A" (الضفة 1)'],
    'P0011': ['"A" camshaft position — timing over-advanced (Bank 1)', 'توقيت عمود الكامات "A" متقدم أكثر من اللازم (الضفة 1)'],
    'P0012': ['"A" camshaft position — timing over-retarded (Bank 1)', 'توقيت عمود الكامات "A" متأخر أكثر من اللازم (الضفة 1)'],
    'P0013': ['"B" camshaft position actuator circuit (Bank 1)', 'دائرة مشغّل عمود الكامات "B" (الضفة 1)'],
    'P0014': ['"B" camshaft position — timing over-advanced (Bank 1)', 'توقيت عمود الكامات "B" متقدم أكثر من اللازم (الضفة 1)'],
    'P0016': ['Crankshaft/camshaft position correlation (Bank 1 Sensor A)', 'عدم توافق موضع عمود المرفق مع عمود الكامات (الضفة 1 حساس A)'],
    'P0017': ['Crankshaft/camshaft position correlation (Bank 1 Sensor B)', 'عدم توافق موضع عمود المرفق مع عمود الكامات (الضفة 1 حساس B)'],
    'P0020': ['"A" camshaft position actuator circuit (Bank 2)', 'دائرة مشغّل عمود الكامات "A" (الضفة 2)'],
    'P0030': ['O2 sensor heater control circuit (Bank 1 Sensor 1)', 'دائرة سخان حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0031': ['O2 sensor heater control circuit low (Bank 1 Sensor 1)', 'إشارة منخفضة في دائرة سخان حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0032': ['O2 sensor heater control circuit high (Bank 1 Sensor 1)', 'إشارة مرتفعة في دائرة سخان حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0036': ['O2 sensor heater control circuit (Bank 1 Sensor 2)', 'دائرة سخان حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0037': ['O2 sensor heater control circuit low (Bank 1 Sensor 2)', 'إشارة منخفضة في دائرة سخان حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0038': ['O2 sensor heater control circuit high (Bank 1 Sensor 2)', 'إشارة مرتفعة في دائرة سخان حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0068': ['MAP/MAF — throttle position correlation', 'عدم توافق حساس ضغط/تدفق الهواء مع موضع الخانق'],
    'P0069': ['MAP — barometric pressure correlation', 'عدم توافق ضغط مشعب السحب مع الضغط الجوي'],
    'P0087': ['Fuel rail/system pressure too low', 'ضغط الوقود في السكة منخفض جداً'],
    'P0088': ['Fuel rail/system pressure too high', 'ضغط الوقود في السكة مرتفع جداً'],
    'P0090': ['Fuel pressure regulator 1 control circuit', 'دائرة منظم ضغط الوقود 1'],
    'P0091': ['Fuel pressure regulator 1 control circuit low', 'إشارة منخفضة في دائرة منظم ضغط الوقود 1'],
    'P0092': ['Fuel pressure regulator 1 control circuit high', 'إشارة مرتفعة في دائرة منظم ضغط الوقود 1'],

    // ── P01xx: fuel & air metering ───────────────────────────────────
    'P0100': ['Mass air flow (MAF) sensor circuit malfunction', 'عطل في دائرة حساس تدفق الهواء (MAF)'],
    'P0101': ['MAF sensor circuit range/performance', 'أداء/مدى غير صحيح لحساس تدفق الهواء (MAF)'],
    'P0102': ['MAF sensor circuit low input', 'إشارة منخفضة من حساس تدفق الهواء (MAF)'],
    'P0103': ['MAF sensor circuit high input', 'إشارة مرتفعة من حساس تدفق الهواء (MAF)'],
    'P0104': ['MAF sensor circuit intermittent', 'إشارة متقطعة من حساس تدفق الهواء (MAF)'],
    'P0105': ['MAP/barometric pressure circuit malfunction', 'عطل في دائرة حساس ضغط مشعب السحب (MAP)'],
    'P0106': ['MAP/barometric pressure range/performance', 'أداء/مدى غير صحيح لحساس ضغط مشعب السحب (MAP)'],
    'P0107': ['MAP/barometric pressure circuit low input', 'إشارة منخفضة من حساس ضغط مشعب السحب (MAP)'],
    'P0108': ['MAP/barometric pressure circuit high input', 'إشارة مرتفعة من حساس ضغط مشعب السحب (MAP)'],
    'P0110': ['Intake air temperature (IAT) circuit malfunction', 'عطل في دائرة حساس حرارة هواء السحب (IAT)'],
    'P0111': ['IAT sensor circuit range/performance', 'أداء/مدى غير صحيح لحساس حرارة هواء السحب (IAT)'],
    'P0112': ['IAT sensor circuit low input', 'إشارة منخفضة من حساس حرارة هواء السحب (IAT)'],
    'P0113': ['IAT sensor circuit high input', 'إشارة مرتفعة من حساس حرارة هواء السحب (IAT)'],
    'P0115': ['Engine coolant temperature (ECT) circuit malfunction', 'عطل في دائرة حساس حرارة سائل التبريد (ECT)'],
    'P0116': ['ECT sensor circuit range/performance', 'أداء/مدى غير صحيح لحساس حرارة سائل التبريد (ECT)'],
    'P0117': ['ECT sensor circuit low input', 'إشارة منخفضة من حساس حرارة سائل التبريد (ECT)'],
    'P0118': ['ECT sensor circuit high input', 'إشارة مرتفعة من حساس حرارة سائل التبريد (ECT)'],
    'P0120': ['Throttle position sensor (TPS) A circuit malfunction', 'عطل في دائرة حساس موضع الخانق (TPS) A'],
    'P0121': ['TPS A circuit range/performance', 'أداء/مدى غير صحيح لحساس موضع الخانق A'],
    'P0122': ['TPS A circuit low input', 'إشارة منخفضة من حساس موضع الخانق A'],
    'P0123': ['TPS A circuit high input', 'إشارة مرتفعة من حساس موضع الخانق A'],
    'P0125': ['Insufficient coolant temperature for closed-loop fuel control', 'حرارة سائل التبريد غير كافية للتحكم المغلق بالوقود'],
    'P0128': ['Coolant thermostat below regulating temperature', 'الثرموستات لا يصل بالحرارة إلى درجة التشغيل المطلوبة'],
    'P0130': ['O2 sensor circuit (Bank 1 Sensor 1)', 'دائرة حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0131': ['O2 sensor circuit low voltage (Bank 1 Sensor 1)', 'جهد منخفض من حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0132': ['O2 sensor circuit high voltage (Bank 1 Sensor 1)', 'جهد مرتفع من حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0133': ['O2 sensor circuit slow response (Bank 1 Sensor 1)', 'استجابة بطيئة من حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0134': ['O2 sensor circuit no activity detected (Bank 1 Sensor 1)', 'لا توجد إشارة من حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0135': ['O2 sensor heater circuit (Bank 1 Sensor 1)', 'دائرة سخان حساس الأكسجين (الضفة 1 حساس 1)'],
    'P0136': ['O2 sensor circuit (Bank 1 Sensor 2)', 'دائرة حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0137': ['O2 sensor circuit low voltage (Bank 1 Sensor 2)', 'جهد منخفض من حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0138': ['O2 sensor circuit high voltage (Bank 1 Sensor 2)', 'جهد مرتفع من حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0140': ['O2 sensor circuit no activity detected (Bank 1 Sensor 2)', 'لا توجد إشارة من حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0141': ['O2 sensor heater circuit (Bank 1 Sensor 2)', 'دائرة سخان حساس الأكسجين (الضفة 1 حساس 2)'],
    'P0150': ['O2 sensor circuit (Bank 2 Sensor 1)', 'دائرة حساس الأكسجين (الضفة 2 حساس 1)'],
    'P0151': ['O2 sensor circuit low voltage (Bank 2 Sensor 1)', 'جهد منخفض من حساس الأكسجين (الضفة 2 حساس 1)'],
    'P0152': ['O2 sensor circuit high voltage (Bank 2 Sensor 1)', 'جهد مرتفع من حساس الأكسجين (الضفة 2 حساس 1)'],
    'P0155': ['O2 sensor heater circuit (Bank 2 Sensor 1)', 'دائرة سخان حساس الأكسجين (الضفة 2 حساس 1)'],
    'P0170': ['Fuel trim malfunction (Bank 1)', 'عطل في معايرة خليط الوقود (الضفة 1)'],
    'P0171': ['System too lean (Bank 1)', 'خليط الوقود فقير جداً (الضفة 1)'],
    'P0172': ['System too rich (Bank 1)', 'خليط الوقود غني جداً (الضفة 1)'],
    'P0174': ['System too lean (Bank 2)', 'خليط الوقود فقير جداً (الضفة 2)'],
    'P0175': ['System too rich (Bank 2)', 'خليط الوقود غني جداً (الضفة 2)'],
    'P0180': ['Fuel temperature sensor A circuit', 'دائرة حساس حرارة الوقود A'],
    'P0190': ['Fuel rail pressure sensor circuit', 'دائرة حساس ضغط سكة الوقود'],
    'P0191': ['Fuel rail pressure sensor range/performance', 'أداء/مدى غير صحيح لحساس ضغط سكة الوقود'],
    'P0192': ['Fuel rail pressure sensor circuit low input', 'إشارة منخفضة من حساس ضغط سكة الوقود'],
    'P0193': ['Fuel rail pressure sensor circuit high input', 'إشارة مرتفعة من حساس ضغط سكة الوقود'],

    // ── P02xx: injectors, fuel pump, turbo ──────────────────────────
    'P0200': ['Injector circuit malfunction', 'عطل في دائرة البخاخات'],
    'P0201': ['Injector circuit — cylinder 1', 'دائرة بخاخ الأسطوانة 1'],
    'P0202': ['Injector circuit — cylinder 2', 'دائرة بخاخ الأسطوانة 2'],
    'P0203': ['Injector circuit — cylinder 3', 'دائرة بخاخ الأسطوانة 3'],
    'P0204': ['Injector circuit — cylinder 4', 'دائرة بخاخ الأسطوانة 4'],
    'P0205': ['Injector circuit — cylinder 5', 'دائرة بخاخ الأسطوانة 5'],
    'P0206': ['Injector circuit — cylinder 6', 'دائرة بخاخ الأسطوانة 6'],
    'P0207': ['Injector circuit — cylinder 7', 'دائرة بخاخ الأسطوانة 7'],
    'P0208': ['Injector circuit — cylinder 8', 'دائرة بخاخ الأسطوانة 8'],
    'P0217': ['Engine overheat condition', 'ارتفاع حرارة المحرك فوق الحد المسموح'],
    'P0218': ['Transmission over-temperature condition', 'ارتفاع حرارة ناقل الحركة فوق الحد المسموح'],
    'P0219': ['Engine overspeed condition', 'تجاوز المحرك حد الدورات الأقصى'],
    'P0221': ['Throttle position sensor B range/performance', 'أداء/مدى غير صحيح لحساس موضع الخانق B'],
    'P0222': ['Throttle position sensor B circuit low input', 'إشارة منخفضة من حساس موضع الخانق B'],
    'P0223': ['Throttle position sensor B circuit high input', 'إشارة مرتفعة من حساس موضع الخانق B'],
    'P0230': ['Fuel pump primary circuit', 'الدائرة الأساسية لمضخة الوقود'],
    'P0234': ['Turbocharger/supercharger overboost condition', 'ضغط التيربو أعلى من الحد المسموح'],
    'P0235': ['Turbocharger boost sensor A circuit', 'دائرة حساس ضغط التيربو A'],
    'P0243': ['Turbocharger wastegate solenoid A', 'صمام بوابة تصريف التيربو A'],
    'P0261': ['Cylinder 1 injector circuit low', 'إشارة منخفضة في دائرة بخاخ الأسطوانة 1'],
    'P0262': ['Cylinder 1 injector circuit high', 'إشارة مرتفعة في دائرة بخاخ الأسطوانة 1'],
    'P0299': ['Turbocharger/supercharger underboost condition', 'ضغط التيربو أقل من الحد المطلوب'],

    // ── P03xx: ignition & misfires ───────────────────────────────────
    'P0300': ['Random/multiple cylinder misfire detected', 'رعشة/تقطيع عشوائي في أكثر من أسطوانة'],
    'P0301': ['Cylinder 1 misfire detected', 'تقطيع في الأسطوانة 1'],
    'P0302': ['Cylinder 2 misfire detected', 'تقطيع في الأسطوانة 2'],
    'P0303': ['Cylinder 3 misfire detected', 'تقطيع في الأسطوانة 3'],
    'P0304': ['Cylinder 4 misfire detected', 'تقطيع في الأسطوانة 4'],
    'P0305': ['Cylinder 5 misfire detected', 'تقطيع في الأسطوانة 5'],
    'P0306': ['Cylinder 6 misfire detected', 'تقطيع في الأسطوانة 6'],
    'P0307': ['Cylinder 7 misfire detected', 'تقطيع في الأسطوانة 7'],
    'P0308': ['Cylinder 8 misfire detected', 'تقطيع في الأسطوانة 8'],
    'P0309': ['Cylinder 9 misfire detected', 'تقطيع في الأسطوانة 9'],
    'P0310': ['Cylinder 10 misfire detected', 'تقطيع في الأسطوانة 10'],
    'P0311': ['Cylinder 11 misfire detected', 'تقطيع في الأسطوانة 11'],
    'P0312': ['Cylinder 12 misfire detected', 'تقطيع في الأسطوانة 12'],
    'P0325': ['Knock sensor 1 circuit (Bank 1)', 'دائرة حساس الصفع/الطرق 1 (الضفة 1)'],
    'P0327': ['Knock sensor 1 circuit low input (Bank 1)', 'إشارة منخفضة من حساس الصفع 1 (الضفة 1)'],
    'P0328': ['Knock sensor 1 circuit high input (Bank 1)', 'إشارة مرتفعة من حساس الصفع 1 (الضفة 1)'],
    'P0335': ['Crankshaft position sensor A circuit', 'دائرة حساس موضع عمود المرفق A'],
    'P0336': ['Crankshaft position sensor A range/performance', 'أداء/مدى غير صحيح لحساس موضع عمود المرفق A'],
    'P0340': ['Camshaft position sensor A circuit (Bank 1)', 'دائرة حساس موضع عمود الكامات A (الضفة 1)'],
    'P0341': ['Camshaft position sensor A range/performance (Bank 1)', 'أداء/مدى غير صحيح لحساس موضع عمود الكامات A'],
    'P0350': ['Ignition coil primary/secondary circuit', 'دائرة كويل الإشعال الأولية/الثانوية'],
    'P0351': ['Ignition coil A primary/secondary circuit', 'دائرة كويل الإشعال A'],
    'P0352': ['Ignition coil B primary/secondary circuit', 'دائرة كويل الإشعال B'],
    'P0353': ['Ignition coil C primary/secondary circuit', 'دائرة كويل الإشعال C'],
    'P0354': ['Ignition coil D primary/secondary circuit', 'دائرة كويل الإشعال D'],
    'P0355': ['Ignition coil E primary/secondary circuit', 'دائرة كويل الإشعال E'],
    'P0356': ['Ignition coil F primary/secondary circuit', 'دائرة كويل الإشعال F'],
    'P0357': ['Ignition coil G primary/secondary circuit', 'دائرة كويل الإشعال G'],
    'P0358': ['Ignition coil H primary/secondary circuit', 'دائرة كويل الإشعال H'],

    // ── P04xx: emissions (EGR, catalyst, EVAP) ──────────────────────
    'P0400': ['Exhaust gas recirculation (EGR) flow malfunction', 'عطل في تدفق نظام إعادة تدوير العادم (EGR)'],
    'P0401': ['EGR insufficient flow detected', 'تدفق غير كافٍ في نظام EGR'],
    'P0402': ['EGR excessive flow detected', 'تدفق زائد في نظام EGR'],
    'P0403': ['EGR circuit malfunction', 'عطل في دائرة نظام EGR'],
    'P0404': ['EGR circuit range/performance', 'أداء/مدى غير صحيح لدائرة نظام EGR'],
    'P0405': ['EGR sensor A circuit low', 'إشارة منخفضة من حساس نظام EGR A'],
    'P0410': ['Secondary air injection system malfunction', 'عطل في نظام حقن الهواء الثانوي'],
    'P0411': ['Secondary air injection — incorrect flow detected', 'تدفق غير صحيح في نظام حقن الهواء الثانوي'],
    'P0420': ['Catalyst system efficiency below threshold (Bank 1)', 'كفاءة الكتلايزر (البيئة) أقل من الحد المطلوب (الضفة 1)'],
    'P0430': ['Catalyst system efficiency below threshold (Bank 2)', 'كفاءة الكتلايزر (البيئة) أقل من الحد المطلوب (الضفة 2)'],
    'P0440': ['Evaporative emission (EVAP) system malfunction', 'عطل في نظام التحكم بأبخرة الوقود (EVAP)'],
    'P0441': ['EVAP incorrect purge flow', 'تدفق تنقية غير صحيح في نظام EVAP'],
    'P0442': ['EVAP system small leak detected', 'تسريب صغير في نظام أبخرة الوقود EVAP'],
    'P0443': ['EVAP purge control valve circuit', 'دائرة صمام تنقية نظام EVAP'],
    'P0446': ['EVAP vent control circuit', 'دائرة صمام تهوية نظام EVAP'],
    'P0455': ['EVAP system large leak detected', 'تسريب كبير في نظام أبخرة الوقود EVAP'],
    'P0456': ['EVAP system very small leak detected', 'تسريب صغير جداً في نظام أبخرة الوقود EVAP'],
    'P0457': ['EVAP leak detected (fuel cap loose/off)', 'تسريب في نظام EVAP (غطاء الوقود غير محكم)'],
    'P0460': ['Fuel level sensor circuit', 'دائرة حساس مستوى الوقود'],
    'P0461': ['Fuel level sensor circuit range/performance', 'أداء/مدى غير صحيح لحساس مستوى الوقود'],
    'P0462': ['Fuel level sensor circuit low input', 'إشارة منخفضة من حساس مستوى الوقود'],
    'P0463': ['Fuel level sensor circuit high input', 'إشارة مرتفعة من حساس مستوى الوقود'],
    'P0480': ['Cooling fan 1 control circuit', 'دائرة التحكم بمروحة التبريد 1'],

    // ── P05xx: speed, idle, oil pressure, voltage ───────────────────
    'P0500': ['Vehicle speed sensor A malfunction', 'عطل في حساس سرعة السيارة A'],
    'P0501': ['Vehicle speed sensor A range/performance', 'أداء/مدى غير صحيح لحساس سرعة السيارة A'],
    'P0505': ['Idle air control system malfunction', 'عطل في نظام التحكم بدورات الوقوف (الحرة)'],
    'P0506': ['Idle control system — RPM lower than expected', 'دورات الوقوف أقل من المطلوب'],
    'P0507': ['Idle control system — RPM higher than expected', 'دورات الوقوف أعلى من المطلوب'],
    'P0510': ['Closed throttle position switch', 'مفتاح وضع الخانق المغلق'],
    'P0520': ['Engine oil pressure sensor/switch circuit', 'دائرة حساس ضغط زيت المحرك'],
    'P0521': ['Engine oil pressure sensor range/performance', 'أداء/مدى غير صحيح لحساس ضغط زيت المحرك'],
    'P0522': ['Engine oil pressure sensor circuit low voltage', 'ضغط زيت المحرك منخفض (إشارة منخفضة)'],
    'P0523': ['Engine oil pressure sensor circuit high voltage', 'إشارة مرتفعة من حساس ضغط زيت المحرك'],
    'P0530': ['A/C refrigerant pressure sensor circuit', 'دائرة حساس ضغط فريون المكيف'],
    'P0532': ['A/C refrigerant pressure sensor circuit low', 'إشارة منخفضة من حساس ضغط فريون المكيف'],
    'P0545': ['Exhaust gas temperature sensor circuit low (Bank 1)', 'إشارة منخفضة من حساس حرارة العادم (الضفة 1)'],
    'P0546': ['Exhaust gas temperature sensor circuit high (Bank 1)', 'إشارة مرتفعة من حساس حرارة العادم (الضفة 1)'],
    'P0560': ['System voltage malfunction', 'عطل في جهد النظام الكهربائي'],
    'P0562': ['System voltage low', 'جهد النظام الكهربائي منخفض'],
    'P0563': ['System voltage high', 'جهد النظام الكهربائي مرتفع'],
    'P0571': ['Brake switch A circuit', 'دائرة مفتاح الفرامل A'],
    'P0572': ['Brake switch A circuit low', 'إشارة منخفضة من مفتاح الفرامل A'],
    'P0573': ['Brake switch A circuit high', 'إشارة مرتفعة من مفتاح الفرامل A'],

    // ── P06xx: ECU & outputs ─────────────────────────────────────────
    'P0600': ['Serial communication link malfunction', 'عطل في وصلة الاتصال التسلسلي'],
    'P0601': ['Internal control module memory checksum error', 'خطأ في ذاكرة كمبيوتر المحرك (checksum)'],
    'P0602': ['Control module programming error', 'خطأ في برمجة كمبيوتر المحرك'],
    'P0603': ['Internal control module keep-alive memory error', 'خطأ في ذاكرة KAM لكمبيوتر المحرك'],
    'P0604': ['Internal control module RAM error', 'خطأ في ذاكرة RAM لكمبيوتر المحرك'],
    'P0605': ['Internal control module ROM error', 'خطأ في ذاكرة ROM لكمبيوتر المحرك'],
    'P0606': ['ECM/PCM processor fault', 'عطل في معالج كمبيوتر المحرك'],
    'P0615': ['Starter relay circuit', 'دائرة ريليه السلف (بادئ الحركة)'],
    'P0620': ['Generator (alternator) control circuit', 'دائرة التحكم بالدينامو'],
    'P0625': ['Generator field terminal circuit low', 'إشارة منخفضة من طرف مجال الدينامو'],
    'P0630': ['VIN not programmed or incompatible — ECM/PCM', 'رقم الهيكل غير مبرمج أو غير متوافق مع كمبيوتر المحرك'],
    'P0645': ['A/C clutch relay control circuit', 'دائرة ريليه قابض ضاغط المكيف'],
    'P0650': ['Malfunction indicator lamp (MIL) control circuit', 'دائرة لمبة فحص المحرك (MIL)'],
    'P0660': ['Intake manifold tuning valve control circuit (Bank 1)', 'دائرة صمام ضبط مشعب السحب (الضفة 1)'],
    'P0685': ['ECM/PCM power relay control circuit', 'دائرة ريليه تغذية كمبيوتر المحرك'],

    // ── P07xx: transmission ─────────────────────────────────────────
    'P0700': ['Transmission control system malfunction', 'عطل في نظام التحكم بناقل الحركة'],
    'P0701': ['Transmission control system range/performance', 'أداء/مدى غير صحيح لنظام التحكم بناقل الحركة'],
    'P0702': ['Transmission control system electrical', 'عطل كهربائي في نظام التحكم بناقل الحركة'],
    'P0703': ['Torque converter/brake switch B circuit', 'دائرة مفتاح الفرامل/محول العزم B'],
    'P0705': ['Transmission range sensor circuit (PRNDL input)', 'دائرة حساس وضعية ناقل الحركة (PRNDL)'],
    'P0710': ['Transmission fluid temperature sensor circuit', 'دائرة حساس حرارة زيت ناقل الحركة'],
    'P0715': ['Input/turbine speed sensor circuit', 'دائرة حساس سرعة الدخل/التوربين'],
    'P0720': ['Output speed sensor circuit', 'دائرة حساس سرعة الخرج'],
    'P0730': ['Incorrect gear ratio', 'نسبة تعشيق غير صحيحة'],
    'P0731': ['Gear 1 incorrect ratio', 'نسبة تعشيق غير صحيحة للغيار 1'],
    'P0732': ['Gear 2 incorrect ratio', 'نسبة تعشيق غير صحيحة للغيار 2'],
    'P0733': ['Gear 3 incorrect ratio', 'نسبة تعشيق غير صحيحة للغيار 3'],
    'P0734': ['Gear 4 incorrect ratio', 'نسبة تعشيق غير صحيحة للغيار 4'],
    'P0740': ['Torque converter clutch circuit malfunction', 'عطل في دائرة قابض محول العزم'],
    'P0741': ['Torque converter clutch performance or stuck off', 'أداء ضعيف لقابض محول العزم أو عالق مفصولاً'],
    'P0743': ['Torque converter clutch circuit electrical', 'عطل كهربائي في دائرة قابض محول العزم'],
    'P0750': ['Shift solenoid A malfunction', 'عطل في صمام التعشيق A'],
    'P0755': ['Shift solenoid B malfunction', 'عطل في صمام التعشيق B'],
    'P0760': ['Shift solenoid C malfunction', 'عطل في صمام التعشيق C'],
    'P0765': ['Shift solenoid D malfunction', 'عطل في صمام التعشيق D'],
    'P0770': ['Shift solenoid E malfunction', 'عطل في صمام التعشيق E'],

    // ── Manufacturer / readiness ────────────────────────────────────
    'P1000': ['OBD systems readiness test not complete (Ford)', 'اختبارات جاهزية OBD لم تكتمل (فورد)'],

    // ── C: chassis ──────────────────────────────────────────────────
    'C0035': ['Left front wheel speed sensor circuit', 'دائرة حساس سرعة العجلة الأمامية اليسرى'],
    'C0040': ['Right front wheel speed sensor circuit', 'دائرة حساس سرعة العجلة الأمامية اليمنى'],
    'C0045': ['Left rear wheel speed sensor circuit', 'دائرة حساس سرعة العجلة الخلفية اليسرى'],
    'C0050': ['Right rear wheel speed sensor circuit', 'دائرة حساس سرعة العجلة الخلفية اليمنى'],

    // ── B: body ─────────────────────────────────────────────────────
    'B0001': ['Driver frontal stage 1 deployment control', 'دائرة نشر الوسادة الهوائية الأمامية للسائق (مرحلة 1)'],
    'B0100': ['Electronic front end sensor 1 performance', 'أداء حساس المقدمة الإلكتروني 1'],

    // ── U: network ──────────────────────────────────────────────────
    'U0001': ['High speed CAN communication bus', 'عطل في ناقل CAN عالي السرعة'],
    'U0100': ['Lost communication with ECM/PCM', 'فقدان الاتصال مع كمبيوتر المحرك (ECM/PCM)'],
    'U0101': ['Lost communication with TCM', 'فقدان الاتصال مع كمبيوتر ناقل الحركة (TCM)'],
    'U0121': ['Lost communication with ABS control module', 'فقدان الاتصال مع وحدة تحكم ABS'],
    'U0140': ['Lost communication with body control module', 'فقدان الاتصال مع وحدة تحكم الهيكل (BCM)'],
    'U0155': ['Lost communication with instrument cluster', 'فقدان الاتصال مع طبلون العدادات'],
    'U1000': ['Manufacturer-specific CAN communication fault', 'عطل اتصال CAN خاص بالشركة المصنعة'],
  };
}
