import 'package:flutter/material.dart';
import '../model/model_ekosistem.dart';

/// Tingkat keparahan satu parameter sensor, dipakai untuk memilih
enum SensorSeverity { Ideal, Normal, Bahaya }

class SensorIssue {
  final String param; // 'pH' | 'Temp' | 'TDS' | 'DO'
  final String label; // label tampilan
  final double value;
  final SensorSeverity severity;
  final String solution; // kalimat solusi/saran tindakan
  final String shortDetail; // dipakai di notifikasi ringkas

  const SensorIssue({
    required this.param,
    required this.label,
    required this.value,
    required this.severity,
    required this.solution,
    required this.shortDetail,
  });

  bool get isCritical => severity == SensorSeverity.Bahaya;

  Color get color => severity == SensorSeverity.Bahaya
      ? WaterQualityReference.criticalColor
      : WaterQualityReference.warningColor;
}

class WaterQualityReference {
  WaterQualityReference._();

  static const Color criticalColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);

  static const Map<String, Map<String, double>> _criticalThresholds = {
    'pH': {'dangerLow': 5.5, 'dangerHigh': 8.5},
    'Temp': {'dangerLow': 20.0, 'dangerHigh': 34.0},
    'TDS': {'dangerMin': 1300.0},
    'DO': {'dangerMax': 3.0},
  };

  /// Cek apakah di luar rentang berdasarkan PRESET EKOSISTEM AKTIF
  static bool isOutOfRange(String param, double value) {
    final currentEco = activeEcosystem.value;
    switch (param) {
      case 'pH':
        return !currentEco.phRange.isInRange(value);
      case 'Temp':
        return !currentEco.tempRange.isInRange(value);
      case 'TDS':
        return !currentEco.tdsRange.isInRange(value);
      case 'DO':
        return !currentEco.doRange.isInRange(value);
      default:
        return false;
    }
  }

  static bool isCriticalRealtime(String param, double value) {
    final thresholds = _criticalThresholds[param];
    if (thresholds == null) return false;

    switch (param) {
      case 'pH':
        return value < thresholds['dangerLow']! ||
            value > thresholds['dangerHigh']!;
      case 'Temp':
        return value < thresholds['dangerLow']! ||
            value > thresholds['dangerHigh']!;
      case 'TDS':
        return value > thresholds['dangerMin']!;
      case 'DO':
        return value < thresholds['dangerMax']!;
      default:
        return false;
    }
  }

  /// Label tampilan untuk tiap kode parameter.
  static String labelFor(String param) {
    switch (param) {
      case 'pH':
        return 'pH';
      case 'Temp':
        return 'Suhu';
      case 'TDS':
        return 'TDS';
      case 'DO':
        return 'DO';
      default:
        return param;
    }
  }

  // Tabel saran statis
  static const Map<String, Map<String, String>> _saranMap = {
    'pH': {
      'normal':
          'pH sedikit di luar kisaran ideal aquaponik. Periksa sirkulasi dan keseimbangan nitrat/ammonia. tambahkan buffer bila perlu',
      'bahaya':
          'pH kritis untuk ikan dan tanaman!! Lakukan penggantian sebagian air, gunakan buffer pH yang aman dan cek sistem biofilter serta nitrifikasi.',
    },
    'Temp': {
      'normal':
          'Suhu kurang optimal untuk ikan/tanaman. Periksa naungan, ventilasi, atau pemanas, dan pastikan aliran air stabil.',
      'bahaya':
          'Suhu berbahaya bagi ikan dan akar tanaman! Segera dinginkan/hangatkan dan pantau stres ikan',
    },
    'TDS': {
      'normal':
          'Kadar padatan terlarut mendekati batas, nutrisi mungkin kurang/berlebih. Sesuaikan pemberian pakan dan fertilisasi organik.',
      'bahaya':
          'TDS terlalu tinggi! Kuras sebagian air, isi dengan air bersih, dan cek akumulasi garam atau larutan nutrisi.',
    },
    'DO': {
      'normal':
          'Oksigen terlarut agak rendah, cek pompa dan aerator, serta kurangi kepadatan ikan bila perlu.',
      'bahaya':
          'DO sangat rendah! risiko kematian ikan tinggi. Aktifkan aerator cadangan, tingkatkan aliran air, dan lakukan aerasi permukaan segera.',
    },
  };

  static String solutionFor(String param, double value) {
    final isCrit = isCriticalRealtime(param, value);
    final statusKey = isCrit ? 'bahaya' : 'normal';
    return _saranMap[param]?[statusKey] ?? 'Segera periksa parameter $param.';
  }

  /// Bangun SensorIssue untuk satu parameter, atau null jika dalam
  static SensorIssue? evaluateParam(String param, double value) {
    if (!isOutOfRange(param, value)) return null;
    final critical = isCriticalRealtime(param, value);
    return SensorIssue(
      param: param,
      label: labelFor(param),
      value: value,
      severity: critical ? SensorSeverity.Bahaya : SensorSeverity.Normal,
      solution: solutionFor(param, value),
      shortDetail: '${labelFor(param)} ${value.toStringAsFixed(1)}',
    );
  }

  /// Evaluasi keempat parameter sekaligus, dipakai dashboard & history.
  static List<SensorIssue> evaluateAll({
    required double ph,
    required double temp,
    required double tds,
    required double doVal,
  }) {
    final issues = <SensorIssue?>[
      evaluateParam('pH', ph),
      evaluateParam('Temp', temp),
      evaluateParam('TDS', tds),
      evaluateParam('DO', doVal),
    ];
    return issues.whereType<SensorIssue>().toList();
  }

  /// Judul notifikasi bahaya
  static const String dangerNotificationTitle = 'Status Kualitas Air: BAHAYA!';

  /// Isi notifikasi bahaya berdasarkan daftar issue kritis yang terdeteksi.
  static String dangerNotificationBody({
    required List<SensorIssue> criticalIssues,
    required int consecutiveReadings,
  }) {
    if (criticalIssues.isEmpty) {
      return 'Status kualitas air: BAHAYA selama $consecutiveReadings '
          'pembacaan berturut-turut!';
    }
    final detailParts = criticalIssues.map((e) => e.shortDetail).join(', ');
    return 'Parameter abnormal: $detailParts. Segera periksa ekosistem '
        'akuaponik Anda!';
  }

  /// Pesan ringkas untuk daftar History (1 baris per pembacaan bahaya).
  static String historySummary(List<SensorIssue> issues) {
    if (issues.isEmpty) return '';
    return issues.map((e) => e.shortDetail).join(', ');
  }
}
