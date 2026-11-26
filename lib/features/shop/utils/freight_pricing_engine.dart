import 'dart:math' as math;
import 'package:truck_booking/features/shop/models/pricing_config_model.dart';

class PricingBreakdownResult {
  final double rawBaseFare;
  final double effectiveBaseFare;
  final double baseFareMultiplier;
  final double distanceFare;
  final double effectiveDistanceKm;
  final String journeyCategory;
  final double weightFare;
  final double excessWeightKg;
  final double fragileSurcharge;
  final double hazardousSurcharge;
  final double roadAllowance;
  final double roundTripAdjustment;
  final double emptyContainerDiscount;
  final String containerSize; // '1x 20ft', '2x 20ft Twin', '1x 40ft'
  final double containerSizeSurcharge;
  final String containerStatus; // 'Loaded', '1 Loaded + 1 Empty', 'Empty'
  final String roundTripMode; // 'loaded_loaded', 'loaded_empty', 'empty_loaded', 'empty_empty'
  final double tareWeightKg;
  final double subtotal;
  final double platformCommissionPercent;
  final double platformCommission;
  final double driverPayout;
  final double totalPrice;

  PricingBreakdownResult({
    required this.rawBaseFare,
    required this.effectiveBaseFare,
    required this.baseFareMultiplier,
    required this.distanceFare,
    required this.effectiveDistanceKm,
    required this.journeyCategory,
    required this.weightFare,
    required this.excessWeightKg,
    required this.fragileSurcharge,
    required this.hazardousSurcharge,
    required this.roadAllowance,
    required this.roundTripAdjustment,
    required this.emptyContainerDiscount,
    required this.containerSize,
    required this.containerSizeSurcharge,
    required this.containerStatus,
    this.roundTripMode = 'loaded_empty',
    required this.tareWeightKg,
    required this.subtotal,
    required this.platformCommissionPercent,
    required this.platformCommission,
    required this.driverPayout,
    required this.totalPrice,
  });

  /// Backward-compatible getters
  double get baseFee => effectiveBaseFare;
  double get baseFare => effectiveBaseFare;
  double get distanceFee => distanceFare;
  double get containerDeckSurcharge => containerSizeSurcharge;
  double get emptyReturnDiscount => emptyContainerDiscount;
  double get excessWeightFee => weightFare;
  double get loadingLaborFee => 0.0;
  double get platformFee => platformCommission;
  double get driverTotalPayout => driverPayout;
  String get journeyCategoryLabel => '$journeyCategory ($effectiveDistanceKm km)';

  Map<String, dynamic> toJson() => {
        'baseFare': effectiveBaseFare,
        'rawBaseFare': rawBaseFare,
        'effectiveBaseFare': effectiveBaseFare,
        'baseFareMultiplier': baseFareMultiplier,
        'distanceFare': distanceFare,
        'effectiveDistanceKm': effectiveDistanceKm,
        'journeyCategory': journeyCategory,
        'weightFare': weightFare,
        'excessWeightKg': excessWeightKg,
        'fragileSurcharge': fragileSurcharge,
        'hazardousSurcharge': hazardousSurcharge,
        'roadAllowance': roadAllowance,
        'roundTripAdjustment': roundTripAdjustment,
        'emptyContainerDiscount': emptyContainerDiscount,
        'containerSize': containerSize,
        'containerSizeSurcharge': containerSizeSurcharge,
        'containerStatus': containerStatus,
        'roundTripMode': roundTripMode,
        'tareWeightKg': tareWeightKg,
        'subtotal': subtotal,
        'platformCommissionPercent': platformCommissionPercent,
        'platformCommission': platformCommission,
        'driverPayout': driverPayout,
        'totalPrice': totalPrice,
      };
}

typedef FreightPriceBreakdown = PricingBreakdownResult;

class FreightPricingEngine {
  /// Calculate Exact Industry-Standard Freight Price & Itemized Breakdown
  static PricingBreakdownResult calculatePrice({
    required String truckType,
    required double distanceKm,
    required double weightKg,
    required String tripType, // 'single' or 'round_trip'
    bool isFragile = false,
    bool isHazardous = false,
    bool requiresLoadingAssistance = false,
    String loadType = 'Container',
    String containerSize = '20ft', // '20ft', 'twin_20ft', '40ft'
    String containerStatus = 'Loaded', // 'Loaded', '1_Loaded_1_Empty', 'Empty'
    String roundTripMode = 'loaded_empty', // 'loaded_loaded', 'loaded_empty', 'empty_loaded', 'empty_empty'
    PricingConfigModel? config,
  }) {
    final activeConfig = config ?? PricingConfigModel.defaultDefaults();

    // 1. Find Truck Spec
    final truckConfig = activeConfig.truckRates[truckType] ??
        activeConfig.truckRates['Flatbed / Platform Truck'] ??
        activeConfig.truckRates['Flatbed / Container'] ??
        (activeConfig.truckRates.isNotEmpty
            ? activeConfig.truckRates.values.first
            : TruckRateConfig(baseFare: 200.0, perKmRate: 7.5, baseWeightIncludedKg: 10000.0));

    // Look up specific cargo rate under this truck!
    final cargoConfig = truckConfig.cargoRates[loadType] ??
        truckConfig.cargoRates['Container'] ??
        CargoRateConfig(
          baseFare: truckConfig.baseFare,
          perKmRate: truckConfig.perKmRate,
          baseWeightIncludedKg: truckConfig.baseWeightIncludedKg,
          excessWeightPerTonRate: truckConfig.excessWeightPerTonRate,
        );

    final double rawBaseFare = cargoConfig.baseFare;
    final double perKmRate = cargoConfig.perKmRate;
    final double baseWeightIncludedKg = cargoConfig.baseWeightIncludedKg;
    final double excessWeightPerTonRate = cargoConfig.excessWeightPerTonRate;

    // Resolved Effective Multipliers (Cascade: Custom Cargo Override > Global Config)
    final double effectiveSingleTripMult = (cargoConfig.enableCustomOverrides && cargoConfig.singleTripMultiplier != null)
        ? cargoConfig.singleTripMultiplier!
        : activeConfig.singleTripMultiplier;

    final double effectiveRoundTripMult = (cargoConfig.enableCustomOverrides && cargoConfig.roundTripMultiplier != null)
        ? cargoConfig.roundTripMultiplier!
        : activeConfig.roundTripMultiplier;

    final double effectiveEmptyDiscPercent = (cargoConfig.enableCustomOverrides && cargoConfig.emptyContainerDiscountPercent != null)
        ? cargoConfig.emptyContainerDiscountPercent!
        : activeConfig.emptyContainerDiscountPercent;

    final double effective20ftMult = (cargoConfig.enableCustomOverrides && cargoConfig.container20ftMultiplier != null)
        ? cargoConfig.container20ftMultiplier!
        : activeConfig.container20ftMultiplier;

    final double effective40ftMult = (cargoConfig.enableCustomOverrides && cargoConfig.container40ftMultiplier != null)
        ? cargoConfig.container40ftMultiplier!
        : activeConfig.container40ftMultiplier;

    final double effectiveTwin20ftMult = (cargoConfig.enableCustomOverrides && cargoConfig.twin20ftMultiplier != null)
        ? cargoConfig.twin20ftMultiplier!
        : activeConfig.twin20ftMultiplier;

    // Resolved Journey Categories List
    final List<JourneyCategoryConfig> activeCategories = (cargoConfig.enableCustomOverrides &&
            cargoConfig.journeyCategories != null &&
            cargoConfig.journeyCategories!.isNotEmpty)
        ? cargoConfig.journeyCategories!
        : activeConfig.journeyCategories;

    // 2. Journey Category, Journey Base Multiplier & Distance Multiplier
    JourneyCategoryConfig category = activeCategories.first;
    for (var cat in activeCategories) {
      if (distanceKm <= cat.maxDistanceKm) {
        category = cat;
        break;
      }
    }

    final String journeyCategory = category.categoryName;
    final double categoryMultiplier = category.rateMultiplier;
    final double baseFareMultiplier = category.baseFareMultiplier;
    final double roadAllowance = category.roadAllowance;

    // Apply Journey Base Multiplier (e.g. Short Journey = 1.0x Base, Long Journey = 1.5x Base)
    final double effectiveBaseFare = rawBaseFare * baseFareMultiplier;

    // 3. Distance & Leg Calculations
    final double billableDistance = (distanceKm - truckConfig.includedDistanceKm).clamp(0.0, double.infinity);
    final bool isRoundTrip = tripType.toLowerCase() == 'round_trip';

    final double singleTripFactor = isRoundTrip ? 1.0 : effectiveSingleTripMult;
    final double rawSingleDistanceFare = billableDistance * perKmRate * categoryMultiplier * singleTripFactor;
    final double singleLegFare = (effectiveBaseFare * singleTripFactor) + rawSingleDistanceFare;

    // 4. ISO Container Size Multipliers
    final bool isContainerCargo = loadType.toLowerCase().contains('container');
    double containerSizeSurcharge = 0.0;
    double tareWeightKg = 0.0;
    String displaySizeLabel = 'N/A';
    String displayStatusLabel = 'Loaded';

    if (isContainerCargo) {
      if (containerSize == '40ft') {
        displaySizeLabel = '1x 40ft / 40ft HC';
        containerSizeSurcharge = singleLegFare * (effective40ftMult - 1.0);
        tareWeightKg = activeConfig.tareWeight40ftKg;
      } else if (containerSize == 'twin_20ft') {
        displaySizeLabel = '2x 20ft Twin Containers';
        containerSizeSurcharge = singleLegFare * (effectiveTwin20ftMult - 1.0);
        tareWeightKg = activeConfig.tareWeight20ftKg * 2.0;
      } else {
        displaySizeLabel = '1x 20ft Standard Container';
        containerSizeSurcharge = singleLegFare * (effective20ftMult - 1.0);
        tareWeightKg = activeConfig.tareWeight20ftKg;
      }
    }

    final double fullSingleLegFare = singleLegFare + containerSizeSurcharge;

    double leg1Fare = fullSingleLegFare;
    double leg2Fare = 0.0;
    double roundTripAdjustment = 0.0;
    double emptyContainerDiscount = 0.0;
    final double discPercent = effectiveEmptyDiscPercent / 100.0;

    if (isRoundTrip) {
      // Round Trip: Fare is discounted via Round-Trip Factor. Empty Container Discount does NOT apply.
      final double leg2Factor = math.max(0.2, effectiveRoundTripMult - 1.0);
      leg2Fare = fullSingleLegFare * leg2Factor;
      roundTripAdjustment = fullSingleLegFare * (2.0 - effectiveRoundTripMult);
      emptyContainerDiscount = 0.0;

      switch (roundTripMode.toLowerCase()) {
        case 'loaded_loaded':
          displayStatusLabel = 'Round Trip: Loaded In - Loaded Out';
          break;
        case 'loaded_empty':
          displayStatusLabel = 'Round Trip: Loaded In - Empty Return Out';
          break;
        case 'empty_loaded':
          displayStatusLabel = 'Round Trip: Empty In - Loaded Return Out';
          break;
        case 'empty_empty':
          displayStatusLabel = 'Round Trip: Empty In - Empty Return Out';
          break;
        default:
          displayStatusLabel = 'Round Trip: Loaded In - Empty Return Out';
      }
    } else {
      // One-Way Single Trip
      if (isContainerCargo) {
        final String normStatus = containerStatus.toLowerCase();
        if (normStatus == 'empty' || normStatus.contains('2x empty')) {
          displayStatusLabel = 'Empty Return';
          emptyContainerDiscount = fullSingleLegFare * discPercent;
        } else if (normStatus == '1_loaded_1_empty' || normStatus.contains('1 loaded')) {
          displayStatusLabel = '1 Loaded + 1 Empty Return';
          emptyContainerDiscount = (fullSingleLegFare * 0.5) * discPercent;
        } else {
          displayStatusLabel = 'Loaded Container';
          emptyContainerDiscount = 0.0;
        }
      }
    }

    // 5. Excess Weight Calculation
    final bool isFullyEmpty = (isRoundTrip && roundTripMode == 'empty_empty') ||
        (!isRoundTrip && isContainerCargo && containerStatus.toLowerCase() == 'empty');
    final double effectiveWeightKg = isFullyEmpty
        ? math.min(weightKg, tareWeightKg > 0 ? tareWeightKg : 3800.0)
        : weightKg;
    final double excessWeightKg = (effectiveWeightKg - baseWeightIncludedKg).clamp(0.0, double.infinity);
    final double excessTons = excessWeightKg / 1000.0;
    final double weightFare = excessTons * excessWeightPerTonRate;

    // 6. Special Surcharges & Loading Assistance
    final double fragileSurcharge = isFragile ? (effectiveBaseFare * (activeConfig.fragileSurchargePercent / 100.0)) : 0.0;
    final double hazardousSurcharge = isHazardous ? (effectiveBaseFare * (activeConfig.hazardousSurchargePercent / 100.0)) : 0.0;
    final double loadingLaborFee = requiresLoadingAssistance ? 25.0 : 0.0;

    // 7. Subtotal & Total Calculation
    final double baseLegSubtotal = isRoundTrip ? (leg1Fare + leg2Fare) : fullSingleLegFare;
    final double rawSubtotal = baseLegSubtotal +
        weightFare +
        fragileSurcharge +
        hazardousSurcharge +
        roadAllowance +
        loadingLaborFee -
        emptyContainerDiscount;

    // Guarantee round trip floor fare: A round trip must be at least 1.25x of effective base fare
    final double minFloorFare = effectiveBaseFare * (isRoundTrip ? 1.25 : 0.5);
    final double subtotal = math.max(rawSubtotal, minFloorFare);
    final double totalPrice = double.parse(subtotal.toStringAsFixed(2));

    final double effectiveDistanceKm = isRoundTrip ? distanceKm * 2.0 : distanceKm;
    final double distanceFare = isRoundTrip ? (rawSingleDistanceFare * effectiveRoundTripMult) : rawSingleDistanceFare;

    // 8. Platform Commission & Driver Payout Split
    final double commissionPercent = category.platformCommissionPercent;
    final double commissionRate = commissionPercent / 100.0;
    final double platformCommission = double.parse((totalPrice * commissionRate).toStringAsFixed(2));
    final double driverPayout = double.parse((totalPrice - platformCommission).toStringAsFixed(2));

    return PricingBreakdownResult(
      rawBaseFare: rawBaseFare,
      effectiveBaseFare: double.parse(effectiveBaseFare.toStringAsFixed(2)),
      baseFareMultiplier: baseFareMultiplier,
      distanceFare: double.parse(distanceFare.toStringAsFixed(2)),
      effectiveDistanceKm: double.parse(effectiveDistanceKm.toStringAsFixed(1)),
      journeyCategory: journeyCategory,
      weightFare: double.parse(weightFare.toStringAsFixed(2)),
      excessWeightKg: excessWeightKg,
      fragileSurcharge: double.parse(fragileSurcharge.toStringAsFixed(2)),
      hazardousSurcharge: double.parse(hazardousSurcharge.toStringAsFixed(2)),
      roadAllowance: roadAllowance,
      roundTripAdjustment: double.parse(roundTripAdjustment.toStringAsFixed(2)),
      emptyContainerDiscount: double.parse(emptyContainerDiscount.toStringAsFixed(2)),
      containerSize: displaySizeLabel,
      containerSizeSurcharge: double.parse(containerSizeSurcharge.toStringAsFixed(2)),
      containerStatus: displayStatusLabel,
      roundTripMode: roundTripMode,
      tareWeightKg: tareWeightKg,
      subtotal: subtotal,
      platformCommissionPercent: commissionPercent,
      platformCommission: platformCommission,
      driverPayout: driverPayout,
      totalPrice: totalPrice,
    );
  }

  /// Backward-compatible signature
  static PricingBreakdownResult calculateWithConfig({
    required PricingConfigModel config,
    required double distanceInKm,
    required double weightInTons,
    required String truckType,
    required String cargoType,
    required String containerSize,
    required String containerStatus,
    required String tripType,
    String roundTripLegMode = 'loaded_empty',
    bool isFragile = false,
    bool isHazardous = false,
    bool requiresLoadingAssistance = false,
    String currency = 'USD',
    double exchangeRate = 1.0,
  }) {
    return calculatePrice(
      truckType: truckType,
      loadType: cargoType,
      containerSize: containerSize,
      containerStatus: containerStatus,
      roundTripMode: roundTripLegMode,
      distanceKm: distanceInKm,
      weightKg: weightInTons * 1000.0,
      tripType: tripType,
      isFragile: isFragile,
      isHazardous: isHazardous,
      requiresLoadingAssistance: requiresLoadingAssistance,
      config: config,
    );
  }
}
