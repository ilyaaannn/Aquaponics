import 'package:flutter/material.dart';

class ParameterRange {
  final double min;
  final double max;
  final String unit;

  const ParameterRange({
    required this.min,
    required this.max,
    required this.unit,
  });

  bool isInRange(double value) => value >= min && value <= max;

  String get rangeText {
    if (unit == 'mg/l' && min == 0) return '≥ ${max.toStringAsFixed(0)} $unit';
    return '${min % 1 == 0 ? min.toInt() : min} – ${max % 1 == 0 ? max.toInt() : max} $unit';
  }

  static ParameterRange? intersect(ParameterRange a, ParameterRange b) {
    final lo = a.min > b.min ? a.min : b.min;
    final hi = a.max < b.max ? a.max : b.max;
    if (lo > hi) return null;
    return ParameterRange(min: lo, max: hi, unit: a.unit);
  }
}

enum WaterStatus { ideal, normal, bahaya }

extension WaterStatusExt on WaterStatus {
  String get label {
    switch (this) {
      case WaterStatus.ideal:
        return 'Ideal';
      case WaterStatus.normal:
        return 'Normal';
      case WaterStatus.bahaya:
        return 'Bahaya';
    }
  }

  Color get color {
    switch (this) {
      case WaterStatus.ideal:
        return const Color.fromARGB(255, 0, 122, 81);
      case WaterStatus.normal:
        return const Color.fromARGB(255, 255, 179, 0);
      case WaterStatus.bahaya:
        return const Color.fromARGB(255, 167, 4, 4);
    }
  }
}

class SensorRange {
  final double min;
  final double max;

  SensorRange({required this.min, required this.max});

  bool isInRange(double value) {
    return value >= min && value <= max;
  }
}

class FishSpecies {
  final String id;
  final String name;
  final ParameterRange phRange;
  final ParameterRange tempRange;
  final ParameterRange tdsRange;
  final ParameterRange doRange;

  const FishSpecies({
    required this.id,
    required this.name,
    required this.phRange,
    required this.tempRange,
    required this.tdsRange,
    required this.doRange,
  });
}

class PlantSpecies {
  final String id;
  final String name;
  final ParameterRange phRange;
  final ParameterRange tempRange;
  final ParameterRange tdsRange;
  final ParameterRange doRange;

  const PlantSpecies({
    required this.id,
    required this.name,
    required this.phRange,
    required this.tempRange,
    required this.tdsRange,
    required this.doRange,
  });
}

class AquaponicEcosystem {
  final FishSpecies fish;
  final PlantSpecies plant;

  const AquaponicEcosystem({required this.fish, required this.plant});

  String get id => '${fish.id}_${plant.id}';
  String get name => '${fish.name} & ${plant.name}';
  String get fishName => fish.name;
  String get plantName => plant.name;

  ParameterRange get phRange =>
      ParameterRange.intersect(fish.phRange, plant.phRange) ??
      ParameterRange(min: fish.phRange.min, max: plant.phRange.max, unit: 'pH');
  ParameterRange get tempRange =>
      ParameterRange.intersect(fish.tempRange, plant.tempRange) ??
      ParameterRange(
        min: (fish.tempRange.min + plant.tempRange.min) / 2,
        max: (fish.tempRange.max + plant.tempRange.max) / 2,
        unit: '°C',
      );
  ParameterRange get tdsRange =>
      ParameterRange.intersect(fish.tdsRange, plant.tdsRange) ??
      ParameterRange(
        min: fish.tdsRange.min,
        max: plant.tdsRange.max,
        unit: 'ppm',
      );
  ParameterRange get doRange =>
      ParameterRange.intersect(fish.doRange, plant.doRange) ??
      ParameterRange(
        min: fish.doRange.min,
        max: plant.doRange.max,
        unit: 'mg/l',
      );
}

final List<FishSpecies> fishList = [
  FishSpecies(
    id: 'nila',
    name: 'Ikan Nila',
    phRange: ParameterRange(min: 6.5, max: 8.0, unit: 'pH'),
    tempRange: ParameterRange(min: 25.0, max: 30.0, unit: '°C'),
    tdsRange: ParameterRange(min: 200.0, max: 1000.0, unit: 'ppm'),
    doRange: ParameterRange(min: 4.0, max: 15.0, unit: 'mg/l'),
  ),
  FishSpecies(
    id: 'lele',
    name: 'Ikan Lele',
    phRange: ParameterRange(min: 6.5, max: 8.5, unit: 'pH'),
    tempRange: ParameterRange(min: 25.0, max: 32.0, unit: '°C'),
    tdsRange: ParameterRange(min: 400.0, max: 1500.0, unit: 'ppm'),
    doRange: ParameterRange(min: 3.0, max: 15.0, unit: 'mg/l'),
  ),
  FishSpecies(
    id: 'gurame',
    name: 'Ikan Gurame',
    phRange: ParameterRange(min: 6.5, max: 8.0, unit: 'pH'),
    tempRange: ParameterRange(min: 24.0, max: 28.0, unit: '°C'),
    tdsRange: ParameterRange(min: 200.0, max: 1200.0, unit: 'ppm'),
    doRange: ParameterRange(min: 4.0, max: 15.0, unit: 'mg/l'),
  ),
];

final List<PlantSpecies> plantList = [
  PlantSpecies(
    id: 'selada',
    name: 'Selada',
    phRange: ParameterRange(min: 6.0, max: 7.0, unit: 'pH'),
    tempRange: ParameterRange(min: 15.0, max: 25.0, unit: '°C'),
    tdsRange: ParameterRange(min: 200.0, max: 700.0, unit: 'ppm'),
    doRange: ParameterRange(min: 4.0, max: 15.0, unit: 'mg/l'),
  ),
  PlantSpecies(
    id: 'kangkung',
    name: 'Kangkung',
    phRange: ParameterRange(min: 6.0, max: 8.0, unit: 'pH'),
    tempRange: ParameterRange(min: 20.0, max: 35.0, unit: '°C'),
    tdsRange: ParameterRange(min: 300.0, max: 1500.0, unit: 'ppm'),
    doRange: ParameterRange(min: 3.0, max: 15.0, unit: 'mg/l'),
  ),
  PlantSpecies(
    id: 'pakcoy',
    name: 'Pakcoy',
    phRange: ParameterRange(min: 6.0, max: 7.0, unit: 'pH'),
    tempRange: ParameterRange(min: 18.0, max: 27.0, unit: '°C'),
    tdsRange: ParameterRange(min: 350.0, max: 1050.0, unit: 'ppm'),
    doRange: ParameterRange(min: 4.0, max: 15.0, unit: 'mg/l'),
  ),
];

/// 9 preset ecosystem: kombinasi 3 ikan (Nila, Lele, Gurame) x 3 tanaman (Selada, Kangkung, Pakcoy)
final List<AquaponicEcosystem> presetEcosystems = [
  for (final fish in fishList)
    for (final plant in plantList) AquaponicEcosystem(fish: fish, plant: plant),
];

/// Index preset aktif (0-8, mengikuti urutan presetEcosystems:
final ValueNotifier<int> activePresetIndex = ValueNotifier<int>(0);

/// Notifier ecosystem aktif
final ValueNotifier<AquaponicEcosystem> activeEcosystem =
    ValueNotifier<AquaponicEcosystem>(presetEcosystems[0]);

List<AquaponicEcosystem> get ecosystemList => presetEcosystems;
