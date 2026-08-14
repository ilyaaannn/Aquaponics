import 'package:flutter/material.dart';
import '../helper/app_theme.dart';

class DesktopParam {
  final String jsonKey;
  final String label;
  final String shortLabel;
  final String unit;
  final IconData icon;
  final Color color;
  final int decimals;

  const DesktopParam({
    required this.jsonKey,
    required this.label,
    required this.shortLabel,
    required this.unit,
    required this.icon,
    required this.color,
    this.decimals = 1,
  });

  String format(num value) {
    final v = value.toStringAsFixed(decimals);
    return unit.isEmpty ? v : '$v $unit';
  }
}

/// 11 parameter yang ditampilkan di halaman Data Desktop.
const List<DesktopParam> kDesktopParams = [
  DesktopParam(
    jsonKey: 'temp_water',
    label: 'Suhu Air',
    shortLabel: 'Suhu Air',
    unit: '°C',
    icon: Icons.thermostat_rounded,
    color: AppTheme.tempColor,
    decimals: 1,
  ),
  DesktopParam(
    jsonKey: 'ph',
    label: 'pH',
    shortLabel: 'pH',
    unit: '',
    icon: Icons.water_drop_rounded,
    color: AppTheme.phColor,
    decimals: 1,
  ),
  DesktopParam(
    jsonKey: 'tds',
    label: 'TDS',
    shortLabel: 'TDS',
    unit: 'ppm',
    icon: Icons.scatter_plot_rounded,
    color: AppTheme.tdsColor,
    decimals: 0,
  ),
  DesktopParam(
    jsonKey: 'do_value',
    label: 'DO (Oksigen Terlarut)',
    shortLabel: 'DO',
    unit: 'mg/L',
    icon: Icons.bubble_chart_rounded,
    color: AppTheme.doColor,
    decimals: 1,
  ),
  DesktopParam(
    jsonKey: 'turbidity',
    label: 'Kekeruhan',
    shortLabel: 'Turb.',
    unit: 'NTU',
    icon: Icons.blur_on_rounded,
    color: AppTheme.paramTurbidity,
    decimals: 0,
  ),
  DesktopParam(
    jsonKey: 'water_lvl',
    label: 'Level Air',
    shortLabel: 'Level',
    unit: 'cm',
    icon: Icons.waves_rounded,
    color: AppTheme.paramWaterLevel,
    decimals: 1,
  ),
  DesktopParam(
    jsonKey: 'temp_air',
    label: 'Suhu Udara',
    shortLabel: 'Suhu Udara',
    unit: '°C',
    icon: Icons.device_thermostat_rounded,
    color: AppTheme.paramAirTemp,
    decimals: 1,
  ),
  DesktopParam(
    jsonKey: 'humidity',
    label: 'Kelembaban',
    shortLabel: 'Hum.',
    unit: '%',
    icon: Icons.opacity_rounded,
    color: AppTheme.paramHumidity,
    decimals: 1,
  ),
  DesktopParam(
    jsonKey: 'co2',
    label: 'CO₂',
    shortLabel: 'CO₂',
    unit: 'ppm',
    icon: Icons.cloud_outlined,
    color: AppTheme.paramCO2,
    decimals: 0,
  ),
  DesktopParam(
    jsonKey: 'eco2',
    label: 'eCO₂',
    shortLabel: 'eCO₂',
    unit: 'ppm',
    icon: Icons.eco_rounded,
    color: AppTheme.paramECO2,
    decimals: 0,
  ),
  DesktopParam(
    jsonKey: 'tvoc',
    label: 'TVOC',
    shortLabel: 'TVOC',
    unit: 'ppb',
    icon: Icons.science_outlined,
    color: AppTheme.paramTVOC,
    decimals: 0,
  ),
];

/// Ambil nilai numerik dari 1 baris log (Map hasil decode JSON), aman
/// terhadap null / tipe String / tipe num.
double numFromLog(Map<String, dynamic> log, String key) {
  final v = log[key];
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
