import 'package:flutter_test/flutter_test.dart';

import 'package:focus_obd2_scanner/core/utils/obd_utils.dart';
import 'package:focus_obd2_scanner/data/dtc/dtc_database.dart';
import 'package:focus_obd2_scanner/data/models/dtc_code.dart';

void main() {
  group('ObdUtils PID decoding (SAE J1979)', () {
    test('coolant temperature: 41 05 7B → 83°C', () {
      expect(ObdUtils.coolantTemp('41 05 7B\r>'), 0x7B - 40);
    });

    test('RPM: 41 0C 1A F8 → 1726', () {
      expect(ObdUtils.rpm('41 0C 1A F8\r>'), ((0x1A * 256 + 0xF8) / 4).round());
    });

    test('speed: 41 0D 4B → 75 km/h', () {
      expect(ObdUtils.speed('41 0D 4B\r>'), 0x4B);
    });

    test('fuel level: 41 2F 80 → ~50.2%', () {
      expect(ObdUtils.fuelLevel('41 2F 80\r>'), closeTo(50.2, 0.1));
    });

    test('battery voltage: parses ATRV response', () {
      expect(ObdUtils.batteryVoltage('12.6V\r>'), 12.6);
    });

    test('MIL flag from monitor status byte', () {
      expect(ObdUtils.milOn('41 01 83 07 65 04\r>'), isTrue);
      expect(ObdUtils.milOn('41 01 03 07 65 04\r>'), isFalse);
    });

    test('NO DATA and errors return null', () {
      expect(ObdUtils.coolantTemp('NO DATA\r>'), isNull);
      expect(ObdUtils.rpm('UNABLE TO CONNECT\r>'), isNull);
    });

    test('DTC decoding: 43 01 03 01 41 → P0103, P0141', () {
      final codes = ObdUtils.decodeDtcs('43 01 03 01 41 00 00\r>', 0x03);
      expect(codes, containsAll(['P0103', 'P0141']));
    });

    test('DTC decoding: C/B/U system prefixes', () {
      // 0x4104 → C0104, 0x8104 → B0104, 0xC104 → U0104
      final codes = ObdUtils.decodeDtcs('43 41 04 81 04 C1 04\r>', 0x03);
      expect(codes, containsAll(['C0104', 'B0104', 'U0104']));
    });
  });

  group('DtcDatabase', () {
    test('contains 200+ known codes', () {
      expect(DtcDatabase.knownCodeCount, greaterThanOrEqualTo(200));
    });

    test('known code has bilingual descriptions', () {
      expect(DtcDatabase.describeEn('P0301'), contains('misfire'));
      expect(DtcDatabase.describeAr('P0301'), isNotEmpty);
    });

    test('unknown code falls back to a generic description', () {
      expect(DtcDatabase.describeEn('P9999'), contains('powertrain'));
    });

    test('misfires are classified critical', () {
      expect(DtcDatabase.severityOf('P0301'), DtcSeverity.critical);
      expect(DtcDatabase.severityOf('P0457'), DtcSeverity.low);
    });
  });
}
