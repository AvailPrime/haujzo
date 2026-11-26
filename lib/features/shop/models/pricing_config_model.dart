class CargoRateConfig {
  bool isActive;
  double baseFare;
  double perKmRate;
  double baseWeightIncludedKg;
  double excessWeightPerTonRate;

  // Custom Overrides per Vehicle + Cargo pair
  bool enableCustomOverrides;
  double? singleTripMultiplier;
  double? roundTripMultiplier;
  double? emptyContainerDiscountPercent;
  double? container20ftMultiplier;
  double? container40ftMultiplier;
  double? twin20ftMultiplier;
  List<JourneyCategoryConfig>? journeyCategories;

  CargoRateConfig({
    this.isActive = true,
    required this.baseFare,
    required this.perKmRate,
    required this.baseWeightIncludedKg,
    this.excessWeightPerTonRate = 12.0,
    this.enableCustomOverrides = false,
    this.singleTripMultiplier,
    this.roundTripMultiplier,
    this.emptyContainerDiscountPercent,
    this.container20ftMultiplier,
    this.container40ftMultiplier,
    this.twin20ftMultiplier,
    this.journeyCategories,
  });

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'baseFare': baseFare,
        'perKmRate': perKmRate,
        'baseWeightIncludedKg': baseWeightIncludedKg,
        'excessWeightPerTonRate': excessWeightPerTonRate,
        'enableCustomOverrides': enableCustomOverrides,
        if (singleTripMultiplier != null) 'singleTripMultiplier': singleTripMultiplier,
        if (roundTripMultiplier != null) 'roundTripMultiplier': roundTripMultiplier,
        if (emptyContainerDiscountPercent != null) 'emptyContainerDiscountPercent': emptyContainerDiscountPercent,
        if (container20ftMultiplier != null) 'container20ftMultiplier': container20ftMultiplier,
        if (container40ftMultiplier != null) 'container40ftMultiplier': container40ftMultiplier,
        if (twin20ftMultiplier != null) 'twin20ftMultiplier': twin20ftMultiplier,
        if (journeyCategories != null) 'journeyCategories': journeyCategories!.map((c) => c.toJson()).toList(),
      };

  factory CargoRateConfig.fromJson(Map<String, dynamic> json, [CargoRateConfig? fallback]) {
    final List<JourneyCategoryConfig>? parsedCategories = json['journeyCategories'] is List
        ? (json['journeyCategories'] as List).map((c) => JourneyCategoryConfig.fromJson(Map<String, dynamic>.from(c))).toList()
        : null;

    return CargoRateConfig(
      isActive: json['isActive'] == null ? (fallback?.isActive ?? true) : json['isActive'] == true,
      baseFare: (json['baseFare'] ?? fallback?.baseFare ?? 150.0).toDouble(),
      perKmRate: (json['perKmRate'] ?? fallback?.perKmRate ?? 1.65).toDouble(),
      baseWeightIncludedKg: (json['baseWeightIncludedKg'] ?? fallback?.baseWeightIncludedKg ?? 10000.0).toDouble(),
      excessWeightPerTonRate: (json['excessWeightPerTonRate'] ?? fallback?.excessWeightPerTonRate ?? 9.0).toDouble(),
      enableCustomOverrides: json['enableCustomOverrides'] == true,
      singleTripMultiplier: (json['singleTripMultiplier'] as num?)?.toDouble(),
      roundTripMultiplier: (json['roundTripMultiplier'] as num?)?.toDouble(),
      emptyContainerDiscountPercent: (json['emptyContainerDiscountPercent'] as num?)?.toDouble(),
      container20ftMultiplier: (json['container20ftMultiplier'] as num?)?.toDouble(),
      container40ftMultiplier: (json['container40ftMultiplier'] as num?)?.toDouble(),
      twin20ftMultiplier: (json['twin20ftMultiplier'] as num?)?.toDouble(),
      journeyCategories: parsedCategories,
    );
  }
}

class TruckRateConfig {
  bool isActive;
  double baseFare;
  double includedDistanceKm;
  double perKmRate;
  double baseWeightIncludedKg;
  double excessWeightPerTonRate;
  Map<String, CargoRateConfig> cargoRates;

  TruckRateConfig({
    this.isActive = true,
    required this.baseFare,
    this.includedDistanceKm = 5.0,
    required this.perKmRate,
    required this.baseWeightIncludedKg,
    this.excessWeightPerTonRate = 12.0,
    Map<String, CargoRateConfig>? cargoRates,
  }) : cargoRates = cargoRates ?? {};

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> cargoJson = {};
    cargoRates.forEach((key, value) => cargoJson[key] = value.toJson());

    return {
      'isActive': isActive,
      'baseFare': baseFare,
      'includedDistanceKm': includedDistanceKm,
      'perKmRate': perKmRate,
      'baseWeightIncludedKg': baseWeightIncludedKg,
      'excessWeightPerTonRate': excessWeightPerTonRate,
      'cargoRates': cargoJson,
    };
  }

  factory TruckRateConfig.fromJson(Map<String, dynamic> json, [TruckRateConfig? fallback, String? truckName]) {
    final defaultBase = fallback?.baseFare ?? 50.0;
    final defaultIncDist = fallback?.includedDistanceKm ?? 5.0;
    final defaultPerKm = fallback?.perKmRate ?? 1.65;
    final defaultBaseWeight = fallback?.baseWeightIncludedKg ?? 1000.0;
    final defaultExcessRate = fallback?.excessWeightPerTonRate ?? 9.0;

    final baseFareVal = (json['baseFare'] ?? defaultBase).toDouble();
    final perKmVal = (json['perKmRate'] ?? defaultPerKm).toDouble();
    final weightVal = (json['baseWeightIncludedKg'] ?? defaultBaseWeight).toDouble();
    final excessVal = (json['excessWeightPerTonRate'] ?? defaultExcessRate).toDouble();

    final Map<String, CargoRateConfig> parsedCargo = {};
    if (json['cargoRates'] is Map) {
      (json['cargoRates'] as Map).forEach((k, v) {
        if (v is Map) {
          parsedCargo[k.toString()] = CargoRateConfig.fromJson(
            Map<String, dynamic>.from(v),
            CargoRateConfig(baseFare: baseFareVal, perKmRate: perKmVal, baseWeightIncludedKg: weightVal, excessWeightPerTonRate: excessVal),
          );
        }
      });
    }

    final allowedCargoTypes = PricingConfigModel.getCompatibleCargoTypesForTruck(truckName ?? '');

    for (var cargoType in allowedCargoTypes) {
      if (!parsedCargo.containsKey(cargoType)) {
        parsedCargo[cargoType] = CargoRateConfig(
          baseFare: baseFareVal,
          perKmRate: perKmVal,
          baseWeightIncludedKg: weightVal,
          excessWeightPerTonRate: excessVal,
        );
      }
    }

    // Retain only compatible cargo types for this truck
    parsedCargo.removeWhere((key, _) => !allowedCargoTypes.contains(key));

    return TruckRateConfig(
      isActive: json['isActive'] == null ? (fallback?.isActive ?? true) : json['isActive'] == true,
      baseFare: baseFareVal,
      includedDistanceKm: (json['includedDistanceKm'] ?? defaultIncDist).toDouble(),
      perKmRate: perKmVal,
      baseWeightIncludedKg: weightVal,
      excessWeightPerTonRate: excessVal,
      cargoRates: parsedCargo,
    );
  }
}

class JourneyCategoryConfig {
  String categoryName;
  double maxDistanceKm; // e.g. 50, 200, 500, 99999
  double rateMultiplier; // e.g. 1.0, 0.95, 0.90, 0.85
  double baseFareMultiplier; // e.g. 1.0, 1.25, 0.70, 0.60
  double platformCommissionPercent; // e.g. 15.0, 15.0, 8.0, 8.0
  double roadAllowance; // Driver allowance for long-haul

  JourneyCategoryConfig({
    required this.categoryName,
    required this.maxDistanceKm,
    required this.rateMultiplier,
    this.baseFareMultiplier = 1.0,
    this.platformCommissionPercent = 15.0,
    required this.roadAllowance,
  });

  Map<String, dynamic> toJson() => {
        'categoryName': categoryName,
        'maxDistanceKm': maxDistanceKm,
        'rateMultiplier': rateMultiplier,
        'baseFareMultiplier': baseFareMultiplier,
        'platformCommissionPercent': platformCommissionPercent,
        'roadAllowance': roadAllowance,
      };

  factory JourneyCategoryConfig.fromJson(Map<String, dynamic> json) {
    final name = json['categoryName'] ?? 'Short Journey';
    double defaultBaseMult = 1.0;
    double defaultRateMult = 1.0;
    double defaultCommPercent = 15.0;
    double defaultRoadAllow = 0.0;

    if (name.contains('Medium')) {
      defaultBaseMult = 1.00;
      defaultRateMult = 0.95;
      defaultCommPercent = 12.0;
      defaultRoadAllow = 25.0;
    } else if (name.contains('Long')) {
      defaultBaseMult = 0.70;
      defaultRateMult = 0.90;
      defaultCommPercent = 8.0;
      defaultRoadAllow = 60.0;
    } else if (name.contains('Interstate') || name.contains('Cross')) {
      defaultBaseMult = 0.60;
      defaultRateMult = 0.85;
      defaultCommPercent = 8.0;
      defaultRoadAllow = 120.0;
    }

    return JourneyCategoryConfig(
      categoryName: name,
      maxDistanceKm: (json['maxDistanceKm'] ?? 50.0).toDouble(),
      rateMultiplier: (json['rateMultiplier'] ?? defaultRateMult).toDouble(),
      baseFareMultiplier: (json['baseFareMultiplier'] ?? defaultBaseMult).toDouble(),
      platformCommissionPercent: (json['platformCommissionPercent'] ?? defaultCommPercent).toDouble(),
      roadAllowance: (json['roadAllowance'] ?? defaultRoadAllow).toDouble(),
    );
  }
}

class PricingConfigModel {
  double platformCommissionPercent;
  double singleTripMultiplier;
  double roundTripMultiplier;
  double emptyContainerDiscountPercent;
  double container20ftMultiplier;
  double container40ftMultiplier;
  double twin20ftMultiplier;
  double tareWeight20ftKg;
  double tareWeight40ftKg;
  double fragileSurchargePercent;
  double hazardousSurchargePercent;
  Map<String, TruckRateConfig> truckRates;
  List<JourneyCategoryConfig> journeyCategories;

  PricingConfigModel({
    this.platformCommissionPercent = 15.0,
    this.singleTripMultiplier = 1.00,
    this.roundTripMultiplier = 1.80,
    this.emptyContainerDiscountPercent = 25.0,
    this.container20ftMultiplier = 1.00,
    this.container40ftMultiplier = 1.65,
    this.twin20ftMultiplier = 1.75,
    this.tareWeight20ftKg = 2300.0,
    this.tareWeight40ftKg = 3800.0,
    this.fragileSurchargePercent = 12.0,
    this.hazardousSurchargePercent = 20.0,
    required this.truckRates,
    required this.journeyCategories,
  });

  /// Freight domain rules: Allowed cargo load types per vehicle type
  static List<String> getCompatibleCargoTypesForTruck(String truckName) {
    switch (truckName) {
      case 'Pickup / Mini Truck':
        return ['General Freight', 'Bulk / Loose Material', 'Refrigerated Goods'];
      case 'Tipper / Dumper':
        return ['Bulk / Loose Material', 'General Freight'];
      case 'Flatbed / Platform Truck':
      case 'Flatbed / Container':
        return ['Container', 'General Freight', 'Bulk / Loose Material', 'Heavy Machinery'];
      case 'Refrigerated Truck':
        return ['Refrigerated Goods', 'General Freight'];
      case 'Heavy Duty / 30-Ton':
        return ['Container', 'Heavy Machinery', 'General Freight', 'Bulk / Loose Material'];
      default:
        return ['General Freight', 'Bulk / Loose Material', 'Container', 'Heavy Machinery'];
    }
  }

  /// List of truck type names currently active in the platform
  List<String> get activeTruckTypes =>
      truckRates.entries.where((e) => e.value.isActive).map((e) => e.key).toList();

  /// Check whether a truck type is active
  bool isTruckActive(String truckName) => truckRates[truckName]?.isActive ?? false;

  /// Get active cargo types for a specific truck
  List<String> getActiveCargoTypesForTruck(String truckName) {
    final truck = truckRates[truckName];
    if (truck == null) return getCompatibleCargoTypesForTruck(truckName);
    final activeList = truck.cargoRates.entries
        .where((e) => e.value.isActive)
        .map((e) => e.key)
        .toList();
    return activeList.isNotEmpty ? activeList : getCompatibleCargoTypesForTruck(truckName);
  }

  /// Check whether a cargo type is active for a truck
  bool isCargoActiveForTruck(String truckName, String cargoType) =>
      truckRates[truckName]?.cargoRates[cargoType]?.isActive ?? true;

  static PricingConfigModel defaultConfig() => defaultDefaults();

  static PricingConfigModel defaultDefaults() {
    final Map<String, TruckRateConfig> defaultTrucks = {
      'Pickup / Mini Truck': TruckRateConfig(
        isActive: false, // Dormant for market investigation
        baseFare: 40.0,
        includedDistanceKm: 5.0,
        perKmRate: 0.85,
        baseWeightIncludedKg: 1000.0,
        excessWeightPerTonRate: 5.0,
      ),
      'Tipper / Dumper': TruckRateConfig(
        isActive: false, // Dormant for market investigation
        baseFare: 90.0,
        includedDistanceKm: 5.0,
        perKmRate: 1.20,
        baseWeightIncludedKg: 5000.0,
        excessWeightPerTonRate: 7.0,
      ),
      'Flatbed / Platform Truck': TruckRateConfig(
        isActive: true, // Primary Shipping & Drayage vehicle
        baseFare: 150.0,
        includedDistanceKm: 10.0,
        perKmRate: 1.65,
        baseWeightIncludedKg: 10000.0,
        excessWeightPerTonRate: 9.0,
      ),
      'Refrigerated Truck': TruckRateConfig(
        isActive: false, // Dormant for market investigation
        baseFare: 180.0,
        includedDistanceKm: 10.0,
        perKmRate: 2.00,
        baseWeightIncludedKg: 10000.0,
        excessWeightPerTonRate: 10.0,
      ),
      'Heavy Duty / 30-Ton': TruckRateConfig(
        isActive: true, // Heavy Shipping & Outsized container vehicle
        baseFare: 250.0,
        includedDistanceKm: 10.0,
        perKmRate: 2.80,
        baseWeightIncludedKg: 25000.0,
        excessWeightPerTonRate: 14.0,
      ),
    };

    defaultTrucks.forEach((truckName, truckSpec) {
      final base = truckSpec.baseFare;
      final perKm = truckSpec.perKmRate;
      final weight = truckSpec.baseWeightIncludedKg;
      final excess = truckSpec.excessWeightPerTonRate;

      final allowedTypes = getCompatibleCargoTypesForTruck(truckName);
      final Map<String, CargoRateConfig> cMap = {};

      for (var type in allowedTypes) {
        double baseMult = 1.0;
        double kmMult = 1.0;
        bool cargoActive = true;

        if (type == 'General Freight') {
          baseMult = 0.95;
          cargoActive = true;
        } else if (type == 'Bulk / Loose Material') {
          baseMult = 1.10;
          kmMult = 1.05;
          cargoActive = false;
        } else if (type == 'Refrigerated Goods') {
          baseMult = 1.25;
          kmMult = 1.15;
          cargoActive = false;
        } else if (type == 'Heavy Machinery') {
          baseMult = 1.40;
          kmMult = 1.30;
          cargoActive = truckName.contains('Heavy Duty');
        } else if (type == 'Container') {
          cargoActive = true;
        }

        cMap[type] = CargoRateConfig(
          isActive: cargoActive,
          baseFare: base * baseMult,
          perKmRate: perKm * kmMult,
          baseWeightIncludedKg: weight,
          excessWeightPerTonRate: excess,
        );
      }
      truckSpec.cargoRates = cMap;
    });

    return PricingConfigModel(
      platformCommissionPercent: 15.0,
      singleTripMultiplier: 1.00,
      roundTripMultiplier: 1.80,
      emptyContainerDiscountPercent: 25.0,
      container20ftMultiplier: 1.00,
      container40ftMultiplier: 1.65,
      twin20ftMultiplier: 1.75,
      tareWeight20ftKg: 2300.0,
      tareWeight40ftKg: 3800.0,
      fragileSurchargePercent: 12.0,
      hazardousSurchargePercent: 20.0,
      truckRates: defaultTrucks,
      journeyCategories: [
        JourneyCategoryConfig(
          categoryName: 'Short Journey',
          maxDistanceKm: 50.0,
          rateMultiplier: 1.0,
          baseFareMultiplier: 1.0,
          platformCommissionPercent: 15.0,
          roadAllowance: 0.0,
        ),
        JourneyCategoryConfig(
          categoryName: 'Medium Journey',
          maxDistanceKm: 200.0,
          rateMultiplier: 0.95,
          baseFareMultiplier: 1.00,
          platformCommissionPercent: 12.0,
          roadAllowance: 25.0,
        ),
        JourneyCategoryConfig(
          categoryName: 'Long Journey',
          maxDistanceKm: 500.0,
          rateMultiplier: 0.90,
          baseFareMultiplier: 0.70,
          platformCommissionPercent: 8.0,
          roadAllowance: 60.0,
        ),
        JourneyCategoryConfig(
          categoryName: 'Interstate / Cross-Country',
          maxDistanceKm: 99999.0,
          rateMultiplier: 0.85,
          baseFareMultiplier: 0.60,
          platformCommissionPercent: 8.0,
          roadAllowance: 120.0,
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> ratesJson = {};
    truckRates.forEach((key, value) => ratesJson[key] = value.toJson());

    return {
      'platformCommissionPercent': platformCommissionPercent,
      'singleTripMultiplier': singleTripMultiplier,
      'roundTripMultiplier': roundTripMultiplier,
      'emptyContainerDiscountPercent': emptyContainerDiscountPercent,
      'container20ftMultiplier': container20ftMultiplier,
      'container40ftMultiplier': container40ftMultiplier,
      'twin20ftMultiplier': twin20ftMultiplier,
      'tareWeight20ftKg': tareWeight20ftKg,
      'tareWeight40ftKg': tareWeight40ftKg,
      'fragileSurchargePercent': fragileSurchargePercent,
      'hazardousSurchargePercent': hazardousSurchargePercent,
      'truckRates': ratesJson,
      'journeyCategories': journeyCategories.map((c) => c.toJson()).toList(),
    };
  }

  factory PricingConfigModel.fromJson(Map<String, dynamic> json) {
    final defaults = defaultDefaults();

    final Map<String, TruckRateConfig> ratesMap = Map.from(defaults.truckRates);
    if (json['truckRates'] is Map) {
      (json['truckRates'] as Map).forEach((key, value) {
        String keyStr = key.toString();
        if (keyStr == 'Flatbed / Container') {
          keyStr = 'Flatbed / Platform Truck';
        }
        final fallback = defaults.truckRates[keyStr];
        if (value is Map<String, dynamic>) {
          ratesMap[keyStr] = TruckRateConfig.fromJson(value, fallback, keyStr);
        } else if (value is Map) {
          ratesMap[keyStr] = TruckRateConfig.fromJson(Map<String, dynamic>.from(value), fallback, keyStr);
        }
      });
    }

    final List<JourneyCategoryConfig> categories = [];
    if (json['journeyCategories'] is List && (json['journeyCategories'] as List).isNotEmpty) {
      for (var c in (json['journeyCategories'] as List)) {
        if (c is Map) {
          categories.add(JourneyCategoryConfig.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }

    return PricingConfigModel(
      platformCommissionPercent: (json['platformCommissionPercent'] ?? defaults.platformCommissionPercent).toDouble(),
      singleTripMultiplier: (json['singleTripMultiplier'] ?? defaults.singleTripMultiplier).toDouble(),
      roundTripMultiplier: (json['roundTripMultiplier'] ?? defaults.roundTripMultiplier).toDouble(),
      emptyContainerDiscountPercent: (json['emptyContainerDiscountPercent'] ?? defaults.emptyContainerDiscountPercent).toDouble(),
      container20ftMultiplier: (json['container20ftMultiplier'] ?? defaults.container20ftMultiplier).toDouble(),
      container40ftMultiplier: (json['container40ftMultiplier'] ?? defaults.container40ftMultiplier).toDouble(),
      twin20ftMultiplier: (json['twin20ftMultiplier'] ?? defaults.twin20ftMultiplier).toDouble(),
      tareWeight20ftKg: (json['tareWeight20ftKg'] ?? defaults.tareWeight20ftKg).toDouble(),
      tareWeight40ftKg: (json['tareWeight40ftKg'] ?? defaults.tareWeight40ftKg).toDouble(),
      fragileSurchargePercent: (json['fragileSurchargePercent'] ?? defaults.fragileSurchargePercent).toDouble(),
      hazardousSurchargePercent: (json['hazardousSurchargePercent'] ?? defaults.hazardousSurchargePercent).toDouble(),
      truckRates: ratesMap,
      journeyCategories: categories.isNotEmpty ? categories : defaults.journeyCategories,
    );
  }
}
