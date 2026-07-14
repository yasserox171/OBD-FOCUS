/// Parsing helpers for ELM327 / SAE J1979 responses.
///
/// ELM327 responses arrive as ASCII hex, e.g. `41 05 7B` for PID 0105
/// (coolant temp). These helpers normalize, validate and decode them.
abstract class ObdUtils {
  /// Strips prompt chars, echoes, whitespace and search chatter from a raw
  /// adapter response and returns clean uppercase hex (no spaces).
  static String normalize(String raw) {
    var s = raw
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('>', ' ')
        .replaceAll('SEARCHING...', ' ')
        .replaceAll('BUS INIT', ' ')
        .trim()
        .toUpperCase();
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s;
  }

  static bool isError(String raw) {
    final upper = raw.toUpperCase();
    return upper.contains('NO DATA') ||
        upper.contains('ERROR') ||
        upper.contains('UNABLE TO CONNECT') ||
        upper.contains('STOPPED') ||
        upper.contains('?');
  }

  /// Extracts the data bytes following the expected response header for
  /// [mode] and [pid] (e.g. mode 01, pid 05 → header "4105").
  /// Returns null when the response doesn't contain the header.
  static List<int>? dataBytes(String raw, int mode, int pid) {
    if (isError(raw)) return null;
    final hex = normalize(raw);
    final header = ((mode + 0x40) << 8 | pid)
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    final idx = hex.indexOf(header);
    if (idx < 0) return null;
    final data = hex.substring(idx + header.length);
    final bytes = <int>[];
    for (var i = 0; i + 2 <= data.length; i += 2) {
      final b = int.tryParse(data.substring(i, i + 2), radix: 16);
      if (b == null) break;
      bytes.add(b);
    }
    return bytes.isEmpty ? null : bytes;
  }

  // ── PID decoders (SAE J1979) ─────────────────────────────────────

  /// PID 0105 — engine coolant temperature: A − 40 (°C).
  static double? coolantTemp(String raw) {
    final b = dataBytes(raw, 0x01, 0x05);
    return b == null ? null : b[0] - 40.0;
  }

  /// PID 010C — engine RPM: (256·A + B) / 4.
  static int? rpm(String raw) {
    final b = dataBytes(raw, 0x01, 0x0C);
    if (b == null || b.length < 2) return null;
    return ((b[0] * 256 + b[1]) / 4).round();
  }

  /// PID 010D — vehicle speed: A (km/h).
  static int? speed(String raw) {
    final b = dataBytes(raw, 0x01, 0x0D);
    return b?[0];
  }

  /// PID 012F — fuel level: A · 100 / 255 (%).
  static double? fuelLevel(String raw) {
    final b = dataBytes(raw, 0x01, 0x2F);
    return b == null ? null : b[0] * 100 / 255;
  }

  /// PID 0111 — throttle position: A · 100 / 255 (%).
  static double? throttle(String raw) {
    final b = dataBytes(raw, 0x01, 0x11);
    return b == null ? null : b[0] * 100 / 255;
  }

  /// PID 010F — intake air temperature: A − 40 (°C).
  static double? intakeAirTemp(String raw) {
    final b = dataBytes(raw, 0x01, 0x0F);
    return b == null ? null : b[0] - 40.0;
  }

  /// PID 0114 — O2 sensor 1 voltage: A / 200 (V).
  static double? oxygenSensor(String raw) {
    final b = dataBytes(raw, 0x01, 0x14);
    return b == null ? null : b[0] / 200;
  }

  /// PID 0101 — monitor status: bit 7 of byte A = MIL (check engine light).
  static bool? milOn(String raw) {
    final b = dataBytes(raw, 0x01, 0x01);
    return b == null ? null : (b[0] & 0x80) != 0;
  }

  /// ATRV — adapter/battery voltage, e.g. "12.6V".
  static double? batteryVoltage(String raw) {
    final match = RegExp(r'(\d+\.?\d*)\s*V').firstMatch(raw.toUpperCase());
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  /// Decodes a Mode 03/07/0A response into DTC strings (e.g. "P0301").
  ///
  /// Each response line is one frame: `43 [count?] A1 A2 B1 B2 ...` where
  /// every DTC is two bytes and `0000` entries are padding. CAN frames carry
  /// a count byte right after the mode byte; legacy (K-line) frames do not.
  /// The count byte is only skipped when the remaining payload length is
  /// exactly `count * 2` bytes — the unambiguous CAN signature.
  static List<String> decodeDtcs(String raw, int mode) {
    if (isError(raw)) return const [];
    final marker =
        (mode + 0x40).toRadixString(16).padLeft(2, '0').toUpperCase();
    final codes = <String>{};

    for (final line in raw.split(RegExp(r'[\r\n>]+'))) {
      final hex = line
          .toUpperCase()
          .replaceAll('SEARCHING...', '')
          .replaceAll(RegExp(r'[^0-9A-F]'), '');
      final idx = hex.indexOf(marker);
      if (idx < 0) continue;

      var data = hex.substring(idx + marker.length);
      // Skip a CAN count byte only on an exact length match.
      if (data.length >= 2) {
        final maybeCount = int.tryParse(data.substring(0, 2), radix: 16);
        if (maybeCount != null &&
            maybeCount > 0 &&
            maybeCount <= 16 &&
            data.length - 2 == maybeCount * 4) {
          data = data.substring(2);
        }
      }
      for (var i = 0; i + 4 <= data.length; i += 4) {
        final pair = data.substring(i, i + 4);
        if (pair == '0000') continue;
        final code = _dtcFromPair(pair);
        if (code != null) codes.add(code);
      }
    }
    return codes.toList();
  }

  static String? _dtcFromPair(String pair) {
    final value = int.tryParse(pair, radix: 16);
    if (value == null) return null;
    const systems = ['P', 'C', 'B', 'U'];
    final system = systems[(value >> 14) & 0x03];
    final d1 = (value >> 12) & 0x03;
    final d2 = (value >> 8) & 0x0F;
    final d3 = (value >> 4) & 0x0F;
    final d4 = value & 0x0F;
    return '$system$d1${d2.toRadixString(16).toUpperCase()}'
        '${d3.toRadixString(16).toUpperCase()}'
        '${d4.toRadixString(16).toUpperCase()}';
  }
}
