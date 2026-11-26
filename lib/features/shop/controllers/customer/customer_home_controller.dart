import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:truck_booking/commons/widgets/id_generator/id_generator.dart';
import 'package:truck_booking/commons/widgets/loader/loaders.dart';
import 'package:truck_booking/data/repositories/authentication/authentication_repository.dart';
import 'package:truck_booking/data/repositories/bookings/booking_repository.dart';
import 'package:truck_booking/navigation_menu.dart';
import 'package:truck_booking/routes/routes.dart';
import 'package:truck_booking/utils/constants/api_constants.dart';
import 'package:truck_booking/utils/constants/colors.dart';
import 'package:truck_booking/utils/popups/full_screen_loader.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:truck_booking/features/authentication/models/driver_model.dart';
import 'package:truck_booking/features/personalization/controllers/localization_controller.dart';
import 'package:truck_booking/features/shop/models/booking_model.dart';
import 'package:truck_booking/features/shop/models/pricing_config_model.dart';
import 'package:truck_booking/features/shop/utils/freight_pricing_engine.dart';
import 'package:truck_booking/features/shop/screens/customer_home/job_dispatch_screen.dart';
import 'package:truck_booking/features/personalization/controllers/user_controller.dart';
import 'package:truck_booking/features/personalization/screens/verification/didit_verification_screen.dart';
import 'package:truck_booking/data/services/routing/smart_routing_engine.dart';
import 'package:truck_booking/utils/constants/map_styles.dart';
import 'package:truck_booking/data/repositories/address/address_repository.dart';
import 'package:truck_booking/utils/notifications/trip_payment_alert_service.dart';

class CustomerHomeController extends GetxController {
  static CustomerHomeController get instance => Get.find();

  /// Gatekeeper: Checks if shipper has completed Didit verification AND received Admin approval
  bool checkShipperVerificationAndApproval({bool showDialog = true}) {
    final userController = Get.isRegistered<UserController>() ? UserController.instance : Get.put(UserController());
    final user = userController.user.value;

    // If fully approved by admin and identity verified, they are allowed to work
    if (user.canWork) {
      return true;
    }

    if (showDialog) {
      showVerificationRequiredBottomSheet(user);
    }
    return false;
  }

  /// Displays an informative bottom sheet detailing why shipper cannot book freight yet
  void showVerificationRequiredBottomSheet(dynamic user) {
    final bool isVerified = user.isVerified as bool? ?? false;
    final bool isAdminApproved = user.isApprovedByAdmin as bool? ?? false;
    final bool isAdminRejected = user.isAdminRejected as bool? ?? false;
    final String rejectionReason = (user.adminRejectionReason as String? ?? '').trim();
    final bool isBusiness = user.isBusiness as bool? ?? false;

    Color badgeColor;
    IconData icon;
    String title;
    String message;
    String buttonText;

    if (isAdminRejected) {
      badgeColor = Colors.red;
      icon = Iconsax.close_circle;
      title = 'Shipper Account Declined';
      message = rejectionReason.isNotEmpty
          ? 'Your account application was declined by Fleet Operations Admin for the following reason:\n\n"$rejectionReason"\n\nPlease update your credentials or contact operations support to proceed.'
          : 'Your account was declined by the administration. Please update your verification documents or contact operations.';
      buttonText = 'Update Verification Details';
    } else if (isVerified && !isAdminApproved) {
      badgeColor = Colors.orange;
      icon = Iconsax.clock;
      title = 'Account Under Admin Review';
      message = 'Your cryptographic ${isBusiness ? "Corporate (KYB)" : "Identity (KYC)"} verification has passed! '
          'In accordance with commercial freight regulations, an operations administrator is reviewing your declared profile before activating truck booking.\n\n'
          'You will receive a notification as soon as your account is approved.';
      buttonText = 'Check Verification Status';
    } else {
      badgeColor = AvailColors.primary;
      icon = Iconsax.shield_security;
      title = isBusiness ? 'Corporate KYB Verification Required' : 'Identity Verification Required';
      message = 'To create freight shipments and dispatch commercial trucks, your account must be verified. '
          'Please complete our quick automated ${isBusiness ? "Business (KYB)" : "Identity (KYC)"} verification to unlock booking.';
      buttonText = 'Start Verification';
    }

    final isDark = Get.isDarkMode;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: badgeColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isVerified && !isAdminApproved ? 'Operations Approval Pending' : 'Freight Security Compliance',
                          style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Get.toNamed(AvailRoutes.diditVerification);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Iconsax.verify, color: Colors.white, size: 18),
                      label: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // Pricing Config & Firestore Realtime Listener
  final Rx<PricingConfigModel> pricingConfig = PricingConfigModel.defaultConfig().obs;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pricingConfigSubscription;

  /// List of truck type names currently active in the platform
  List<String> get activeTruckTypes =>
      pricingConfig.value.truckRates.entries.where((e) => e.value.isActive).map((e) => e.key).toList();

  /// Get active cargo types for a specific truck
  List<String> getActiveCargoTypesForTruck(String truckName) {
    final truck = pricingConfig.value.truckRates[truckName];
    if (truck == null) return PricingConfigModel.getCompatibleCargoTypesForTruck(truckName);
    final activeList = truck.cargoRates.entries
        .where((e) => e.value.isActive)
        .map((e) => e.key)
        .toList();
    return activeList.isNotEmpty ? activeList : PricingConfigModel.getCompatibleCargoTypesForTruck(truckName);
  }

  final RxString selectedCargoType = 'Container'.obs;
  final RxString selectedContainerSize = '20ft'.obs;
  final containerSizeDisplayController = TextEditingController(text: 'ISO 20ft');
  final RxString selectedContainerStatus = 'Empty'.obs; // 'Empty' or 'Loaded'
  final RxString selectedTruckType = 'Flatbed / Platform Truck'.obs;
  final RxDouble loadWeight = 2.3.obs;
  final weightController = TextEditingController(text: '2.30');
  final cargoValueController = TextEditingController();
  final loadDescriptionController = TextEditingController();
  final senderNameController = TextEditingController();
  final senderPhoneController = TextEditingController();
  final receiverNameController = TextEditingController();
  final receiverPhoneController = TextEditingController();
  final pickupAddressController = TextEditingController();
  final dropoffAddressController = TextEditingController();
  final materialTypeController = TextEditingController();
  final heavyEquipmentModelController = TextEditingController();
  final containerNumberController = TextEditingController();
  final additionalNotesController = TextEditingController();

  final RxString estimatedDistance = '0 km'.obs;
  final RxDouble calculatedPrice = 0.0.obs;

  // Round Trip & Hazard & Currency Controls
  final RxString tripType = 'single'.obs; // 'single' or 'round_trip'
  final RxString selectedLegMode = 'loaded_loaded'.obs; // 'loaded_loaded', 'loaded_empty', 'empty_loaded', 'empty_empty'
  final RxBool isHazardous = false.obs;
  final RxString selectedCurrency = 'GHS'.obs;
  final RxDouble exchangeRate = 1.0.obs;

  // Inventory List
  final RxList<Map<String, dynamic>> inventoryItems = <Map<String, dynamic>>[].obs;
  final inventoryItemNameController = TextEditingController();
  final inventoryItemQuantityController = TextEditingController();

  // Logistics Options
  final RxBool isFragile = false.obs;
  final RxBool isInsured = false.obs;
  final RxBool requiresAssistance = false.obs;

  final RxList<Map<String, dynamic>> pickedDocuments = <Map<String, dynamic>>[].obs;
  final RxBool isContainerNumberValid = true.obs;
  final RxString selectedRefrigeratedTemp = 'Chilled (2°C - 8°C)'.obs;

  // Price Breakdown (Logistics Pricing Engine Itemized Components)
  final RxDouble baseFee = 0.0.obs;
  final RxDouble distanceFee = 0.0.obs;
  final RxDouble containerDeckSurcharge = 0.0.obs;
  final RxDouble emptyReturnDiscount = 0.0.obs;
  final RxDouble excessWeightFee = 0.0.obs;
  final RxDouble roadAllowance = 0.0.obs;
  final RxDouble fragileSurcharge = 0.0.obs;
  final RxDouble hazardousSurcharge = 0.0.obs;
  final RxDouble loadingLaborFee = 0.0.obs;
  final RxDouble platformFee = 0.0.obs;
  final RxDouble driverTotalPayout = 0.0.obs;
  final RxString journeyCategoryLabel = ''.obs;

  final RxDouble cargoTypePremium = 0.0.obs;
  final RxDouble trafficRiskFee = 0.0.obs;
  final RxDouble optionsFee = 0.0.obs;

  /// Live Breakdown Result in Base USD ($)
  PricingBreakdownResult get calculatedBreakdown {
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    final currentWeightKg = loadWeight.value > 0
        ? loadWeight.value * 1000.0
        : ((double.tryParse(weightController.text) ?? 0.0) * 1000.0);

    return FreightPricingEngine.calculatePrice(
      truckType: selectedTruckType.value.isEmpty ? 'Flatbed / Platform Truck' : selectedTruckType.value,
      loadType: selectedCargoType.value.isEmpty ? 'Container' : selectedCargoType.value,
      containerSize: selectedContainerSize.value,
      containerStatus: selectedContainerStatus.value,
      roundTripMode: selectedLegMode.value,
      distanceKm: distKm,
      weightKg: currentWeightKg,
      tripType: tripType.value,
      isFragile: isFragile.value,
      isHazardous: isHazardous.value,
      requiresLoadingAssistance: requiresAssistance.value,
      config: pricingConfig.value,
    );
  }

  /// Formatted Price in User's Selected Local Currency
  String get formattedTotalPrice {
    return LocalizationController.instance.getFormattedPrice(calculatedBreakdown.totalPrice);
  }

  /// Helper for Route Locations & Distance Updating
  void updateRouteLocations({
    required String pickup,
    required String dropoff,
    String? locationType,
    double? lat,
    double? lng,
    double? distanceInKm,
  }) {
    if (pickup.isNotEmpty) {
      pickupName.value = pickup;
      pickupAddressController.text = pickup;
      if (locationType == 'pickup' && lat != null && lng != null) {
        pickupLocation.value = LatLng(lat, lng);
      }
    }
    if (dropoff.isNotEmpty && dropoff != 'Where to?') {
      destinationName.value = dropoff;
      dropoffAddressController.text = dropoff;
      if (locationType == 'dropoff' && lat != null && lng != null) {
        destinationLocation.value = LatLng(lat, lng);
      }
    }
    if (distanceInKm != null && distanceInKm > 0) {
      estimatedDistance.value = '${distanceInKm.toStringAsFixed(1)} km';
    }
    drawRoute();
    final dist = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(dist);
  }
  
  GlobalKey<FormState> bookingFormKey = GlobalKey<FormState>();

  // Scheduled Booking
  final Rxn<DateTime> scheduledDateTime = Rxn<DateTime>();
  final RxString selectedPaymentMethod = 'Cash on Delivery'.obs;

  // Map related fields
  final Rxn<LatLng> currentPosition = Rxn<LatLng>();
  final Rxn<LatLng> pickupLocation = Rxn<LatLng>();
  final Rxn<LatLng> destinationLocation = Rxn<LatLng>();
  final RxList<Map<String, dynamic>> additionalStops = <Map<String, dynamic>>[].obs;
  
  final RxString pickupName = ''.obs;
  final RxString destinationName = 'Where to?'.obs;
  final RxString estimatedTime = '0 mins'.obs;
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  final Rxn<RouteDataModel> currentRouteData = Rxn<RouteDataModel>();
  final RxList<RouteDataModel> suggestedRoutes = <RouteDataModel>[].obs;
  final RxInt selectedRouteIndex = 0.obs;
  final RxString trafficCondition = 'Smooth Traffic Flow'.obs;
  final RxBool isRouteHUDVisible = false.obs;
  final RxBool isJobCardExpanded = false.obs; // Collapsible active job overlay for massive map area
  final RxBool isMapFullscreen = false.obs; // Zen Fullscreen Map Mode

  final Rxn<BookingModel> selectedJobOnMap = Rxn<BookingModel>();
  final Rx<Offset> draggableButtonPosition = const Offset(20, 450).obs;

  // Editing existing booking
  final RxString editingBookingId = ''.obs;
  final RxString editingCustomBookingId = ''.obs;

  // Analytics for Cargo Owner
  final RxInt activeJobsCount = 0.obs;
  final RxDouble totalTonsShipped = 0.0.obs;

  // Pin on map mode
  final RxBool isSelectingOnMap = false.obs;
  final RxString selectingLocationType = 'pickup'.obs; // 'pickup' or 'destination'
  final Rxn<LatLng> pinnedLocation = Rxn<LatLng>();
  final RxString pinnedAddress = ''.obs;

  GoogleMapController? mapController;
  GoogleMapController? homeMapController;
  
  StreamSubscription<BookingModel>? _jobSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverLocationSubscription;
  StreamSubscription<DatabaseEvent>? _rtdbDriverLocationSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nearbyDriversSubscription;

  final Rx<LatLng?> driverLocation = Rx<LatLng?>(null);
  final RxList<DriverModel> availableDrivers = <DriverModel>[].obs;

  final Map<String, double> driverRotations = {};
  final Map<String, LatLng> driverLastPositions = {};
  LatLng? _lastActiveDriverPos;
  double _activeDriverBearing = 0.0;

  late BitmapDescriptor pickupIcon;
  late BitmapDescriptor destinationIcon;
  BitmapDescriptor? customPickupMarkerIcon;
  BitmapDescriptor? customDropoffMarkerIcon;
  BitmapDescriptor? customDriverMarkerIcon;

  final Map<String, List<LatLng>> _routeCache = {};

  @override
  void onInit() {
    super.onInit();
    _listenToPricingConfig();
    ever(selectedContainerSize, (String val) {
      if (val.isEmpty) {
        containerSizeDisplayController.clear();
      } else {
        final String formatted = val.toUpperCase().startsWith('ISO') ? val : 'ISO $val';
        if (containerSizeDisplayController.text != formatted) {
          containerSizeDisplayController.text = formatted;
        }
      }
    });
    _loadCustomMarkers();
    loadCustomMarkerIcons();
    _determinePosition();
    _listenToPricingConfig();
    _listenToGlobalStats();
    _listenToOnlineDrivers();
  }

  void _listenToPricingConfig() {
    try {
      _pricingConfigSubscription = FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pricing_config')
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          pricingConfig.value = PricingConfigModel.fromJson(doc.data()!);
          // Automatically synchronize with Admin active/dormant status
          final activeTrucks = activeTruckTypes;
          if (activeTrucks.isNotEmpty && !activeTrucks.contains(selectedTruckType.value)) {
            selectedTruckType.value = activeTrucks.first;
            final activeCargo = getActiveCargoTypesForTruck(selectedTruckType.value);
            if (!activeCargo.contains(selectedCargoType.value) && activeCargo.isNotEmpty) {
              selectedCargoType.value = activeCargo.first;
            }
          }
          final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
          calculatePrice(distKm);
        }
      }, onError: (e) {
        debugPrint("CustomerHomeController: Pricing config stream error: $e");
      });
    } catch (e) {
      debugPrint("CustomerHomeController: Could not listen to pricing_config. $e");
    }
  }

  void _listenToGlobalStats() {
    try {
      if (Get.isRegistered<BookingRepository>()) {
        BookingRepository.instance.getUserBookingsStream().listen((bookings) {
          activeJobsCount.value = bookings.where((b) => ['confirmed', 'pickedUp', 'inTransit'].contains(b.status)).length;
          totalTonsShipped.value = bookings.where((b) => b.status == 'delivered').fold(0.0, (prev, b) => prev + b.weight);

          // Trigger loud alert + online payment sheet automatically if any booking is loaded on truck & unpaid
          for (final b in bookings) {
            if (b.requiresOnlinePaymentPrompt) {
              TripPaymentAlertService.instance.triggerLoadedPaymentAlert(b);
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("CustomerHomeController: Could not initialize global stats listener. $e");
    }
  }

  Future<void> loadCustomMarkerIcons() async {
    try {
      customPickupMarkerIcon = await buildPickupMarkerIcon();
      customDropoffMarkerIcon = await buildDropoffMarkerIcon();
      customDriverMarkerIcon = await getCachedTopDownTruckMarker(
        containerColor: const Color(0xFF0F172A),
        cabColor: const Color(0xFF10B981),
        label: 'TRUCK',
      );
      pickupIcon = customPickupMarkerIcon!;
      destinationIcon = customDropoffMarkerIcon!;
    } catch (_) {
      customPickupMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      customDropoffMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      customDriverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      pickupIcon = customPickupMarkerIcon!;
      destinationIcon = customDropoffMarkerIcon!;
    }
  }

  /// Mathematical Anchor Ratio for Pin Markers: (cx / logicalWidth, tipY / logicalHeight)
  /// logicalWidth = 54, logicalHeight = 70, tipY = 66 -> Offset(0.5, 66 / 70) = Offset(0.5, 0.943)
  static const Offset pinAnchor = Offset(0.5, 66.0 / 70.0);

  /// Advanced 3D Vector Pin Builder with Ground Halo, Top Badge, Gloss Sheen & Precision Needle Anchor
  Future<BitmapDescriptor> _buildCustomPinMarker({
    required Color mainColor,
    required Color secondaryColor,
    required Color accentColor,
    required String badgeText,
    String? letter,
    IconData? iconData,
  }) async {
    const double pixelRatio = 3.0;
    const double logicalWidth = 54;
    const double logicalHeight = 70;

    final double width = logicalWidth * pixelRatio;
    final double height = logicalHeight * pixelRatio;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(pixelRatio);

    const double cx = logicalWidth / 2;
    const double cy = 27;
    const double radius = 17;
    const double tipY = 66.0;

    // 1. Ground Contact Shadow & Radar Target Pulse Rings
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, tipY + 1.0), width: 16, height: 5),
      shadowPaint,
    );

    // Subtle Ground Target Ring centered at exact needle tip contact point
    final Paint pulseRingPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, tipY + 1.0), width: 12, height: 4),
      pulseRingPaint,
    );

    // 2. High-Precision Teardrop Pin Path with Smooth Bezier Shoulders
    final Path pinPath = Path();
    pinPath.moveTo(cx, tipY);
    // Left curve up into circular head
    pinPath.cubicTo(cx - 3, tipY - 8, cx - radius, cy + 12, cx - radius, cy);
    // Circular arc around the top
    pinPath.arcToPoint(
      const Offset(cx + radius, cy),
      radius: const Radius.circular(radius),
      clockwise: true,
    );
    // Right curve down into needle tip
    pinPath.cubicTo(cx + radius, cy + 12, cx + 3, tipY - 8, cx, tipY);
    pinPath.close();

    // 3. Rich Gradient Pin Fill (Main Color to Deep Tone)
    final Paint pinPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy - radius),
        const Offset(cx, tipY),
        [mainColor, secondaryColor],
      );
    canvas.drawPath(pinPath, pinPaint);

    // 4. Dark Outer Contrast Casing Outline (Ensures high visibility on satellite and vector maps)
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(pinPath, borderPaint);

    // 5. Specular 3D Gloss Highlight on Top Rim
    final Path glossPath = Path();
    glossPath.addArc(
      Rect.fromCircle(center: const Offset(cx, cy), radius: radius - 1.5),
      3.14 * 1.15,
      3.14 * 0.70,
    );
    final Paint glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(glossPath, glossPaint);

    // 6. Inner Core Circular Base
    final Paint coreShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(const Offset(cx, cy + 1), 10.5, coreShadow);

    final Paint whiteCorePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(cx, cy), 10.5, whiteCorePaint);

    final Paint innerRingPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(const Offset(cx, cy), 9.0, innerRingPaint);

    // 7. Center Emblem (Bold Letter A / B or Icon)
    if (letter != null && letter.isNotEmpty) {
      final TextPainter letterPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      letterPainter.text = TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: secondaryColor,
          letterSpacing: -0.5,
        ),
      );
      letterPainter.layout();
      letterPainter.paint(
        canvas,
        Offset(cx - (letterPainter.width / 2), cy - (letterPainter.height / 2)),
      );
    } else if (iconData != null) {
      final TextPainter iconPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      iconPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 12,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: secondaryColor,
        ),
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(cx - (iconPainter.width / 2), cy - (iconPainter.height / 2)),
      );
    }

    // 8. Floating Top Micro-Pill Tag ("PICKUP" / "DROPOFF" / "STOP")
    if (badgeText.isNotEmpty) {
      const double pillWidth = 42;
      const double pillHeight = 13;
      final RRect pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 8), width: pillWidth, height: pillHeight),
        const Radius.circular(6.5),
      );

      final Paint pillShadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(pillRect.shift(const Offset(0, 1)), pillShadow);

      final Paint pillBg = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(pillRect, pillBg);

      final Paint pillBorder = Paint()
        ..color = mainColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(pillRect, pillBorder);

      final TextPainter pillTextPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      pillTextPainter.text = TextSpan(
        text: badgeText,
        style: const TextStyle(
          fontSize: 7.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.6,
        ),
      );
      pillTextPainter.layout();
      pillTextPainter.paint(
        canvas,
        Offset(cx - (pillTextPainter.width / 2), 8 - (pillTextPainter.height / 2)),
      );
    }

    final ui.Image image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return BitmapDescriptor.bytes(
        byteData.buffer.asUint8List(),
        imagePixelRatio: pixelRatio,
      );
    }
    return BitmapDescriptor.defaultMarker;
  }

  /// Builds high-definition custom Emerald Green Pickup Point pin (Origin 'A')
  Future<BitmapDescriptor> buildPickupMarkerIcon() async {
    return _buildCustomPinMarker(
      mainColor: const Color(0xFF10B981),      // Vivid Emerald
      secondaryColor: const Color(0xFF047857),  // Deep Forest Green
      accentColor: const Color(0xFF34D399),     // Mint highlight
      badgeText: 'PICKUP',
      letter: 'A',
    );
  }

  /// Builds high-definition custom Crimson Red Dropoff Point pin (Destination 'B')
  Future<BitmapDescriptor> buildDropoffMarkerIcon() async {
    return _buildCustomPinMarker(
      mainColor: const Color(0xFFEF4444),      // Crimson Red
      secondaryColor: const Color(0xFFB91C1C),  // Deep Ruby Red
      accentColor: const Color(0xFFF87171),     // Coral highlight
      badgeText: 'DROPOFF',
      letter: 'B',
    );
  }

  /// Builds numbered Amber Gold Intermediate Stop pin (Stop '1', '2', etc.)
  Future<BitmapDescriptor> buildStopMarkerIcon(int index) async {
    return _buildCustomPinMarker(
      mainColor: const Color(0xFFF59E0B),      // Amber Gold
      secondaryColor: const Color(0xFFB45309),  // Deep Amber Bronze
      accentColor: const Color(0xFFFBBF24),     // Golden highlight
      badgeText: 'STOP $index',
      letter: '$index',
    );
  }

  Future<BitmapDescriptor> _buildDriverLocationMarker({String label = 'DRIVER'}) async {
    return getCachedTopDownTruckMarker(
      containerColor: const Color(0xFF0F172A),
      cabColor: const Color(0xFF0088FF),
      label: label,
    );
  }

  final Map<String, BitmapDescriptor> _topDownTruckCache = {};

  Future<BitmapDescriptor> getCachedTopDownTruckMarker({
    Color containerColor = const Color(0xFF0F172A),
    Color cabColor = const Color(0xFF10B981),
    Color roofAccentColor = Colors.white,
    String label = '',
    double scale = 0.55,
  }) async {
    final String key = '${containerColor.toARGB32()}_${cabColor.toARGB32()}_${roofAccentColor.toARGB32()}_${label}_$scale';
    if (_topDownTruckCache.containsKey(key)) {
      return _topDownTruckCache[key]!;
    }
    final icon = await buildTopDownTruckMarker(
      containerColor: containerColor,
      cabColor: cabColor,
      roofAccentColor: roofAccentColor,
      label: label,
      scale: scale,
    );
    _topDownTruckCache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> buildTopDownTruckMarker({
    Color containerColor = const Color(0xFF0F172A),
    Color cabColor = const Color(0xFF10B981),
    Color roofAccentColor = Colors.white,
    String label = '',
    double scale = 0.44,
  }) async {
    const double pixelRatio = 3.0;
    const double logicalWidth = 56;
    const double logicalHeight = 112;

    final double width = (logicalWidth * scale) * pixelRatio;
    final double height = (logicalHeight * scale) * pixelRatio;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(pixelRatio * scale);

    const double cx = logicalWidth / 2;
    const double cy = logicalHeight / 2;

    // 1. Headlight Night/Day Beam Cone Glow (Projected onto Road Ahead)
    final Path headlightBeamPath = Path();
    headlightBeamPath.moveTo(cx - 12, cy - 48);
    headlightBeamPath.lineTo(cx - 24, cy - 72);
    headlightBeamPath.lineTo(cx + 24, cy - 72);
    headlightBeamPath.lineTo(cx + 12, cy - 48);
    headlightBeamPath.close();

    final Paint beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy - 48),
        const Offset(cx, cy - 72),
        [const Color(0xFFFEF08A).withOpacity(0.45), const Color(0xFFFEF08A).withOpacity(0.0)],
      );
    canvas.drawPath(headlightBeamPath, beamPaint);

    // 2. Realistic Multi-Layered Drop Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx + 2.5, cy + 3.5), width: 38, height: 96),
        const Radius.circular(10),
      ),
      shadowPaint,
    );

    // 3. Heavy Triple Axle Wheels / Tires with Alloy Rims
    final Paint tirePaint = Paint()..color = const Color(0xFF111827);
    final Paint rimPaint = Paint()..color = const Color(0xFF64748B);

    // Front Steering Axle
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx - 22, cy - 35, 6, 14), const Radius.circular(2.5)), tirePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx + 16, cy - 35, 6, 14), const Radius.circular(2.5)), tirePaint);
    canvas.drawRect(const Rect.fromLTWH(cx - 21, cy - 30, 4, 4), rimPaint);
    canvas.drawRect(const Rect.fromLTWH(cx + 17, cy - 30, 4, 4), rimPaint);

    // Rear Dual Axle Drive 1
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx - 22, cy + 14, 6, 16), const Radius.circular(2.5)), tirePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx + 16, cy + 14, 6, 16), const Radius.circular(2.5)), tirePaint);
    canvas.drawRect(const Rect.fromLTWH(cx - 21, cy + 20, 4, 4), rimPaint);
    canvas.drawRect(const Rect.fromLTWH(cx + 17, cy + 20, 4, 4), rimPaint);

    // Rear Dual Axle Drive 2
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx - 22, cy + 34, 6, 15), const Radius.circular(2.5)), tirePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx + 16, cy + 34, 6, 15), const Radius.circular(2.5)), tirePaint);
    canvas.drawRect(const Rect.fromLTWH(cx - 21, cy + 39, 4, 4), rimPaint);
    canvas.drawRect(const Rect.fromLTWH(cx + 17, cy + 39, 4, 4), rimPaint);

    // 4. Side View Mirrors & Antenna Guards
    final Paint mirrorPaint = Paint()..color = const Color(0xFF1E293B);
    final Paint mirrorGlassPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx - 24, cy - 43, 5, 9), const Radius.circular(1.5)), mirrorPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx + 19, cy - 43, 5, 9), const Radius.circular(1.5)), mirrorPaint);
    canvas.drawRect(const Rect.fromLTWH(cx - 23, cy - 42, 2, 7), mirrorGlassPaint);
    canvas.drawRect(const Rect.fromLTWH(cx + 21, cy - 42, 2, 7), mirrorGlassPaint);

    // 5. Rear Freight Container Body (Corrugated Steel)
    final RRect containerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(cx - 17, cy - 14, 34, 66),
      const Radius.circular(6),
    );

    final Paint containerShaderPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx - 17, cy),
        const Offset(cx + 17, cy),
        [
          containerColor,
          Color.lerp(containerColor, Colors.white, 0.18)!,
          containerColor,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(containerRect, containerShaderPaint);

    // Container Roof Rib Lines
    final Paint ribPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (double y = cy - 8; y <= cy + 46; y += 8) {
      canvas.drawLine(Offset(cx - 14, y), Offset(cx + 14, y), ribPaint);
    }

    // Metallic Center Top Rib Highlight
    final Paint roofHighlightPaint = Paint()..color = Colors.white.withOpacity(0.22);
    canvas.drawRect(const Rect.fromLTWH(cx - 3, cy - 12, 6, 62), roofHighlightPaint);

    // Rear Container Door Lock Bars
    final Paint doorBarPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRect(const Rect.fromLTWH(cx - 8, cy + 50, 2, 3), doorBarPaint);
    canvas.drawRect(const Rect.fromLTWH(cx + 6, cy + 50, 2, 3), doorBarPaint);

    // 6. Aerodynamic Front Cabin / Engine Hood
    final Path cabPath = Path();
    cabPath.moveTo(cx - 17, cy - 14);
    cabPath.lineTo(cx - 17, cy - 38);
    cabPath.quadraticBezierTo(cx - 17, cy - 48, cx - 8, cy - 49);
    cabPath.lineTo(cx + 8, cy - 49);
    cabPath.quadraticBezierTo(cx + 17, cy - 48, cx + 17, cy - 38);
    cabPath.lineTo(cx + 17, cy - 14);
    cabPath.close();

    final Paint cabShaderPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy - 49),
        const Offset(cx, cy - 14),
        [
          Color.lerp(cabColor, Colors.white, 0.28)!,
          cabColor,
          Color.lerp(cabColor, Colors.black, 0.25)!,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawPath(cabPath, cabShaderPaint);

    // Cabin Border Casing
    final Paint cabBorderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(cabPath, cabBorderPaint);

    // Curved Tinted Windshield Glass
    final Path windshieldPath = Path();
    windshieldPath.moveTo(cx - 13, cy - 31);
    windshieldPath.lineTo(cx + 13, cy - 31);
    windshieldPath.quadraticBezierTo(cx + 12, cy - 41, cx + 5, cy - 42);
    windshieldPath.lineTo(cx - 5, cy - 42);
    windshieldPath.quadraticBezierTo(cx - 12, cy - 41, cx - 13, cy - 31);
    windshieldPath.close();

    final Paint glassPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawPath(windshieldPath, glassPaint);

    final Paint glassGlarePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawLine(const Offset(cx - 9, cy - 34), const Offset(cx - 3, cy - 40), glassGlarePaint);

    // Xenon Headlights
    final Paint headlightPaint = Paint()..color = const Color(0xFFFEF08A);
    final Paint headlightGlowPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(cx - 12, cy - 49), 2.8, headlightPaint);
    canvas.drawCircle(const Offset(cx + 12, cy - 49), 2.8, headlightPaint);
    canvas.drawCircle(const Offset(cx - 12, cy - 49), 1.2, headlightGlowPaint);
    canvas.drawCircle(const Offset(cx + 12, cy - 49), 1.2, headlightGlowPaint);

    // 7. Floating HD Label Pill Tag
    if (label.isNotEmpty) {
      final String tagText = label.length > 8 ? label.substring(0, 8).toUpperCase() : label.toUpperCase();
      final RRect tagRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 12), width: 38, height: 14),
        const Radius.circular(5),
      );
      final Paint tagBgPaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.92);
      final Paint tagBorderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawRRect(tagRect, tagBgPaint);
      canvas.drawRRect(tagRect, tagBorderPaint);

      final TextPainter tagPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      tagPainter.text = TextSpan(
        text: tagText,
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          color: roofAccentColor,
          letterSpacing: 0.5,
        ),
      );
      tagPainter.layout();
      tagPainter.paint(canvas, Offset(cx - (tagPainter.width / 2), (cy + 12) - (tagPainter.height / 2)));
    }

    final ui.Image image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return BitmapDescriptor.bytes(
        byteData.buffer.asUint8List(),
        imagePixelRatio: pixelRatio,
      );
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  Future<BitmapDescriptor> buildCustomTruckMarker({
    Color bodyColor = const Color(0xFF0F172A),
    Color badgeColor = const Color(0xFF10B981),
    String truckLabel = 'TRUCK',
  }) async {
    const double pixelRatio = 3.0;
    const double logicalWidth = 64;
    const double logicalHeight = 64;

    final double width = logicalWidth * pixelRatio;
    final double height = logicalHeight * pixelRatio;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(pixelRatio);

    const double cx = logicalWidth / 2;
    const double cy = logicalHeight / 2 - 4;

    // 1. Oval Drop Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, logicalHeight - 6), width: 38, height: 10),
      shadowPaint,
    );

    // 2. Main Outer Container Circle Badge
    final Paint outerBorderPaint = Paint()
      ..color = badgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final Paint bgCirclePaint = Paint()..color = Colors.white;

    canvas.drawCircle(const Offset(cx, cy), 22, bgCirclePaint);
    canvas.drawCircle(const Offset(cx, cy), 22, outerBorderPaint);

    // 3. Inner Dark Circle Background
    final Paint innerCirclePaint = Paint()..color = bodyColor;
    canvas.drawCircle(const Offset(cx, cy), 18, innerCirclePaint);

    // 4. Truck Icon
    final TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Iconsax.truck_fast.codePoint),
      style: TextStyle(
        fontSize: 20,
        fontFamily: Iconsax.truck_fast.fontFamily,
        package: Iconsax.truck_fast.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx - (textPainter.width / 2), cy - (textPainter.height / 2)));

    // 5. Bottom Truck Type Tag (e.g. "40FT" / "TRUCK")
    if (truckLabel.isNotEmpty) {
      final String tagText = truckLabel.length > 8 ? truckLabel.substring(0, 8).toUpperCase() : truckLabel.toUpperCase();
      final RRect tagRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy + 18), width: 44, height: 13),
        const Radius.circular(6),
      );
      final Paint tagBgPaint = Paint()..color = badgeColor;
      canvas.drawRRect(tagRect, tagBgPaint);

      final TextPainter tagPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      tagPainter.text = TextSpan(
        text: tagText,
        style: const TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      );
      tagPainter.layout();
      tagPainter.paint(canvas, Offset(cx - (tagPainter.width / 2), (cy + 18) - (tagPainter.height / 2)));
    }

    final ui.Image image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return BitmapDescriptor.bytes(
        byteData.buffer.asUint8List(),
        imagePixelRatio: pixelRatio,
      );
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  /// Create Ultra-Compact Google Maps Style Callout Badge Pins for Midpoint Route Callouts
  Future<BitmapDescriptor> _buildRouteCalloutBadge({
    required String timeText,
    required String subText,
    required bool isSelected,
    required Color trafficColor,
  }) async {
    const double pixelRatio = 3.0;
    const double logicalWidth = 68;
    const double logicalHeight = 24;

    final double width = logicalWidth * pixelRatio;
    final double height = logicalHeight * pixelRatio;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(pixelRatio);

    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, logicalWidth - 2, logicalHeight - 2),
      const Radius.circular(11),
    );

    // Soft Drop Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isSelected ? 0.30 : 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(rect.shift(const Offset(0, 1.5)), shadowPaint);

    // Background Pill Fill
    final Paint bgPaint = Paint()
      ..color = isSelected ? const Color(0xFF0F172A) : Colors.white;
    canvas.drawRRect(rect, bgPaint);

    // Border Stroke
    final Paint borderPaint = Paint()
      ..color = isSelected ? trafficColor : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.8 : 1.0;
    canvas.drawRRect(rect, borderPaint);

    // Small Traffic Status Dot
    final Paint dotPaint = Paint()..color = trafficColor;
    canvas.drawCircle(const Offset(9, logicalHeight / 2), 2.8, dotPaint);

    // Clean Compact Time Text (e.g. "24 mins" -> "24m")
    String cleanTime = timeText
        .replaceAll('mins', 'm')
        .replaceAll('min', 'm')
        .replaceAll('hours', 'h')
        .replaceAll('hour', 'h')
        .trim();
    if (cleanTime.length > 8) {
      cleanTime = cleanTime.substring(0, 8);
    }

    final TextPainter timePainter = TextPainter(textDirection: ui.TextDirection.ltr);
    timePainter.text = TextSpan(
      text: cleanTime,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
      ),
    );
    timePainter.layout();
    timePainter.paint(canvas, const Offset(16, 2.5));

    // Subtext (e.g. "Fastest" or "+4m" or "Shortest")
    String cleanSub = subText.replaceAll('via ', '').trim();
    if (cleanSub.length > 9) {
      cleanSub = '${cleanSub.substring(0, 8)}…';
    }

    final TextPainter subPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    subPainter.text = TextSpan(
      text: cleanSub,
      style: TextStyle(
        fontSize: 7.5,
        fontWeight: FontWeight.w800,
        color: isSelected ? trafficColor : const Color(0xFF64748B),
      ),
    );
    subPainter.layout();
    subPainter.paint(canvas, const Offset(16, 13));

    final ui.Image image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return BitmapDescriptor.bytes(
        byteData.buffer.asUint8List(),
        imagePixelRatio: pixelRatio,
      );
    }
    return BitmapDescriptor.defaultMarker;
  }

  /// Public builder for custom midpoint callout badge pins
  Future<BitmapDescriptor> buildRouteCalloutBadge({
    required String timeText,
    required String subText,
    required bool isSelected,
    required Color trafficColor,
  }) => _buildRouteCalloutBadge(
    timeText: timeText,
    subText: subText,
    isSelected: isSelected,
    trafficColor: trafficColor,
  );

  /// Generates Google Maps style interactive midpoint route callout badges for all suggested routes
  Future<void> _updateRouteBadgeMarkers() async {
    if (suggestedRoutes.isEmpty) return;

    final Map<String, Marker> markerMap = {
      for (final m in markers)
        if (!m.markerId.value.startsWith('route_badge')) m.markerId.value: m,
    };

    final safeSelected = selectedRouteIndex.value.clamp(0, suggestedRoutes.length - 1);

    for (int i = 0; i < suggestedRoutes.length; i++) {
      final route = suggestedRoutes[i];
      final isSelected = (i == safeSelected);
      final subText = isSelected
          ? (i == 0 ? 'Fastest' : 'Active')
          : (route.relativeDistanceText.isNotEmpty
              ? route.relativeDistanceText
              : '+${(route.trafficDelaySeconds / 60).round()}m');

      final badgeIcon = await _buildRouteCalloutBadge(
        timeText: route.durationInTrafficText,
        subText: subText,
        isSelected: isSelected,
        trafficColor: route.trafficStatusColor,
      );

      markerMap['route_badge_$i'] = Marker(
        markerId: MarkerId('route_badge_$i'),
        position: route.midpoint,
        icon: badgeIcon,
        anchor: const Offset(0.5, 0.5),
        consumeTapEvents: true,
        onTap: () => selectSuggestedRoute(i),
      );
    }

    markers.assignAll(markerMap.values.toSet());
  }

  Future<void> _loadCustomMarkers() async {
    pickupIcon = await _createCircularMarker(Colors.blue, Colors.white);
    destinationIcon = await _createCircularMarker(Colors.red, Colors.white);
  }

  Future<BitmapDescriptor> _createCircularMarker(Color color, Color borderColor) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 60.0;
    
    // Shadow
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.5, shadowPaint);

    // Border
    final Paint borderPaint = Paint()..color = borderColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.5, borderPaint);

    // Inner Circle
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 3.5, paint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  /// Retrieves user's live GPS coordinates, checking and requesting permissions if needed
  Future<LatLng?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return currentPosition.value;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return currentPosition.value;
      }
      if (permission == LocationPermission.deniedForever) return currentPosition.value;

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      currentPosition.value = latLng;
      return latLng;
    } catch (e) {
      debugPrint('CustomerHomeController getCurrentLocation error: $e');
      return currentPosition.value;
    }
  }

  Future<void> _determinePosition() async {
    final pos = await getCurrentLocation();
    if (pos == null) return;
    
    if (homeMapController != null && currentPosition.value != null) {
      _safeAnimateCamera(homeMapController, CameraUpdate.newLatLngZoom(currentPosition.value!, 15));
    }
  }

  /// Geocode an address string into LatLng
  Future<LatLng?> geocodeAddressToLatLng(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final encoded = Uri.encodeComponent(address.trim());
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=${APIConstants.googleMapsAPIKey}';
      final response = await GetConnect().get(url);
      if (response.statusCode == 200 && response.body['status'] == 'OK') {
        final results = response.body['results'] as List;
        if (results.isNotEmpty) {
          final loc = results[0]['geometry']['location'];
          return LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
        }
      }
    } catch (e) {
      debugPrint('CustomerHomeController geocodeAddressToLatLng error: $e');
    }
    return null;
  }

  /// Automatically retrieves and prefills default location from Firebase saved addresses or company headquarters
  Future<void> prefillFromFirebaseDefaultAddress() async {
    try {
      if (pickupLocation.value != null && pickupName.value.isNotEmpty && pickupName.value != 'My Current Location' && pickupName.value != 'Current Location' && pickupAddressController.text.isNotEmpty) {
        return;
      }

      // 1. Check if user has saved addresses in Firebase AddressRepository
      final addressRepo = Get.isRegistered<AddressRepository>() ? AddressRepository.instance : Get.put(AddressRepository());
      final defaultId = await addressRepo.getDefaultAddressId();
      final addresses = await addressRepo.fetchUserAddresses();
      if (addresses.isNotEmpty) {
        final defaultAddr = addresses.firstWhere((a) => a.id == defaultId, orElse: () => addresses.first);
        final fullAddr = '${defaultAddr.street}, ${defaultAddr.city}, ${defaultAddr.country}';
        final label = defaultAddr.name.isNotEmpty ? '${defaultAddr.name} (${defaultAddr.city})' : fullAddr;
        final coords = await geocodeAddressToLatLng(fullAddr) ?? currentPosition.value ?? const LatLng(5.6037, -0.1870);
        setPickup(coords, label);
        return;
      }

      // 2. Check if user has businessAddress in Firebase UserAccountModel
      final userCtrl = Get.isRegistered<UserController>() ? UserController.instance : Get.put(UserController());
      final bAddr = userCtrl.user.value.businessAddress.trim();
      if (bAddr.isNotEmpty) {
        final coords = await geocodeAddressToLatLng(bAddr) ?? currentPosition.value ?? const LatLng(5.6037, -0.1870);
        setPickup(coords, bAddr);
        return;
      }

      // 3. Fallback to reverse-geocoded current GPS location
      if (currentPosition.value != null) {
        final currentAddr = await reverseGeocode(currentPosition.value!);
        final label = currentAddr.isNotEmpty ? currentAddr : 'My Current Location';
        setPickup(currentPosition.value!, label);
      }
    } catch (e) {
      debugPrint('CustomerHomeController: prefillFromFirebaseDefaultAddress error: $e');
    }
  }

  void onHomeMapCreated(GoogleMapController controller) {
    homeMapController = controller;
    mapController = controller;
    AvailMapStyles.applyThemeStyle(controller, Get.isDarkMode);
    if (pickupLocation.value != null && destinationLocation.value != null) {
      drawRoute();
    } else if (currentPosition.value != null) {
      _safeAnimateCamera(homeMapController, CameraUpdate.newLatLngZoom(currentPosition.value!, 15));
    }
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    AvailMapStyles.applyThemeStyle(controller, Get.isDarkMode);
    if (isSelectingOnMap.value) {
      // If we're selecting on map, use current pinned location if exists
      final target = pinnedLocation.value ?? currentPosition.value;
      if (target != null) {
        _safeAnimateCamera(mapController, CameraUpdate.newLatLngZoom(target, 15));
      }
      return;
    }
    if (pickupLocation.value != null && destinationLocation.value != null) {
      drawRoute();
    } else if (currentPosition.value != null) {
      _safeAnimateCamera(mapController, CameraUpdate.newLatLngZoom(currentPosition.value!, 15));
    }
  }

  final RxBool wasOpenedFromDispatchForm = false.obs;

  void enterMapSelectionMode(String type, {int? stopIndex, bool fromDispatch = false}) {
    isSelectingOnMap.value = true;
    selectingLocationType.value = type;
    wasOpenedFromDispatchForm.value = fromDispatch;
    
    // Initial pin position - always guaranteed non-null
    if (type == 'pickup') {
      pinnedLocation.value = pickupLocation.value ?? currentPosition.value ?? const LatLng(5.6037, -0.1870);
      pinnedAddress.value = (pickupName.value.isNotEmpty &&
              pickupName.value != 'Select pickup point' &&
              pickupName.value != 'Current Location' &&
              pickupName.value != 'My Current Location')
          ? pickupName.value
          : '';
    } else if (type == 'destination') {
      pinnedLocation.value = destinationLocation.value ?? currentPosition.value ?? const LatLng(5.6037, -0.1870);
      pinnedAddress.value = (destinationName.value.isNotEmpty && destinationName.value != 'Where to?' && destinationName.value != 'Select destination / dropoff') ? destinationName.value : '';
    } else if (type == 'stop' && stopIndex != null && stopIndex < additionalStops.length) {
      final stop = additionalStops[stopIndex];
      pinnedLocation.value = LatLng(stop['lat'] ?? 5.6037, stop['lng'] ?? -0.1870);
      pinnedAddress.value = stop['address'] ?? '';
    } else {
      pinnedLocation.value = currentPosition.value ?? const LatLng(5.6037, -0.1870);
      pinnedAddress.value = '';
    }

    // Use home map controller if available to avoid "disposed" errors
    if (homeMapController != null) mapController = homeMapController;
    
    if (pinnedLocation.value != null) {
      _safeAnimateCamera(mapController, CameraUpdate.newLatLngZoom(pinnedLocation.value!, 17));
      if (pinnedAddress.value.isEmpty || pinnedAddress.value == 'Where to?') {
        updatePinnedAddress(pinnedLocation.value!);
      }
    }
  }

  void exitMapSelectionMode() {
    isSelectingOnMap.value = false;
    if (pickupLocation.value != null && destinationLocation.value != null) {
      drawRoute();
    }
    if (wasOpenedFromDispatchForm.value) {
      wasOpenedFromDispatchForm.value = false;
      if (Get.previousRoute.contains('JobDispatchScreen') || Get.previousRoute.contains(AvailRoutes.jobDispatch) || Get.currentRoute.contains('JobDispatchScreen') || Get.currentRoute.contains(AvailRoutes.jobDispatch)) {
        Get.back();
      } else {
        Get.toNamed(AvailRoutes.jobDispatch);
      }
    }
  }

  void confirmPinnedLocation({int? stopIndex}) {
    final loc = pinnedLocation.value ?? currentPosition.value ?? const LatLng(5.6037, -0.1870);

    final resolvedAddress = pinnedAddress.value.isNotEmpty && pinnedAddress.value != 'Locating address...' && pinnedAddress.value != 'Where to?'
        ? pinnedAddress.value
        : 'GPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';

    if (selectingLocationType.value == 'pickup') {
      setPickup(loc, resolvedAddress);
    } else if (selectingLocationType.value == 'destination') {
      setDestination(loc, resolvedAddress);
    } else if (selectingLocationType.value == 'stop') {
      if (stopIndex != null && stopIndex < additionalStops.length) {
        additionalStops[stopIndex] = {
          'address': resolvedAddress,
          'lat': loc.latitude,
          'lng': loc.longitude,
        };
      } else {
        additionalStops.add({
          'address': resolvedAddress,
          'lat': loc.latitude,
          'lng': loc.longitude,
        });
      }
      drawRoute();
    }
    
    isSelectingOnMap.value = false;

    // Return to JobDispatchScreen cleanly without duplicate screen stacking
    if (wasOpenedFromDispatchForm.value) {
      wasOpenedFromDispatchForm.value = false;
      if (Get.previousRoute.contains('JobDispatchScreen') || Get.previousRoute.contains(AvailRoutes.jobDispatch) || Get.currentRoute.contains('JobDispatchScreen') || Get.currentRoute.contains(AvailRoutes.jobDispatch)) {
        Get.back();
      } else {
        Get.toNamed(AvailRoutes.jobDispatch);
      }
    }
  }

  Future<String> reverseGeocode(LatLng position) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${APIConstants.googleMapsAPIKey}';
      final response = await GetConnect().get(url);
      
      if (response.statusCode == 200 && response.body['status'] == 'OK') {
        final results = response.body['results'] as List;
        if (results.isNotEmpty) {
          final addr = results[0]['formatted_address'] as String?;
          if (addr != null && addr.isNotEmpty) return addr;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  Future<void> reverseGeocodeAndSetPickup(LatLng position) async {
    pickupLocation.value = position;
    final address = await reverseGeocode(position);
    pickupName.value = address;
    pickupAddressController.text = address;
    drawRoute();
  }

  Future<void> reverseGeocodeAndSetDestination(LatLng position) async {
    destinationLocation.value = position;
    final address = await reverseGeocode(position);
    destinationName.value = address;
    dropoffAddressController.text = address;
    drawRoute();
  }

  Future<void> updatePinnedAddress(LatLng position) async {
    pinnedLocation.value = position;
    
    try {
      final String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${APIConstants.googleMapsAPIKey}';
      final response = await GetConnect().get(url);
      
      if (response.statusCode == 200 && response.body['status'] == 'OK') {
        final results = response.body['results'] as List;
        if (results.isNotEmpty) {
          // Use the formatted address but keep it concise for the UI
          pinnedAddress.value = results[0]['formatted_address'];
        }
      } else {
        pinnedAddress.value = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      pinnedAddress.value = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    }
  }

  final RxBool isTrafficEnabled = false.obs;
  final Rx<MapType> mapType = MapType.normal.obs;

  void toggleTraffic() {
    isTrafficEnabled.value = !isTrafficEnabled.value;
    AvailLoaders.customToast(
      message: isTrafficEnabled.value ? 'Live Traffic Overlay Active' : 'Traffic Overlay Disabled',
    );
  }

  void toggleMapType() {
    mapType.value = mapType.value == MapType.normal ? MapType.hybrid : MapType.normal;
  }

  void recenterToCurrentLocation() {
    if (selectedJobOnMap.value != null && pickupLocation.value != null && destinationLocation.value != null) {
      final List<LatLng> fitPoints = [pickupLocation.value!, destinationLocation.value!];
      if (driverLocation.value != null) fitPoints.add(driverLocation.value!);
      
      double minLat = fitPoints.first.latitude;
      double maxLat = fitPoints.first.latitude;
      double minLng = fitPoints.first.longitude;
      double maxLng = fitPoints.first.longitude;

      for (var p in fitPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.005, minLng - 0.005),
        northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
      );
      _safeAnimateCamera(homeMapController ?? mapController, CameraUpdate.newLatLngBounds(bounds, 80));
    } else if (currentPosition.value != null) {
      _safeAnimateCamera(homeMapController ?? mapController, CameraUpdate.newLatLngZoom(currentPosition.value!, 15));
      AvailLoaders.customToast(message: 'Centered on current location');
    }
  }

  Future<void> _safeAnimateCamera(GoogleMapController? controller, CameraUpdate update) async {
    try {
      if (controller != null) {
        await controller.animateCamera(update);
      }
    } catch (e) {
      debugPrint('Map Controller Error: $e');
      // This usually happens when the map widget is disposed but the controller is still being used.
      // We catch it to prevent app crashes.
    }
  }

  void showJobOnMap(BookingModel booking) {
    if (booking.pickupLocation == null || booking.dropoffLocation == null) return;
    
    selectedJobOnMap.value = booking;
    pickupLocation.value = LatLng(booking.pickupLocation!.latitude, booking.pickupLocation!.longitude);
    destinationLocation.value = LatLng(booking.dropoffLocation!.latitude, booking.dropoffLocation!.longitude);
    pickupName.value = booking.pickupAddress;
    destinationName.value = booking.dropoffAddress;
    
    // Start Real-time listener for this manifest
    _jobSubscription?.cancel();
    if (booking.id.trim().isNotEmpty) {
      _jobSubscription = BookingRepository.instance.getBookingStream(booking.id).listen((updatedJob) {
        selectedJobOnMap.value = updatedJob;

        if (updatedJob.driverId != null && updatedJob.driverId!.isNotEmpty) {
          _listenToDriverLocation(updatedJob.driverId!);
        }

        if (updatedJob.requiresOnlinePaymentPrompt) {
          TripPaymentAlertService.instance.triggerLoadedPaymentAlert(updatedJob);
        }

        // If status changes to 'delivered' or 'cancelled', we might want to alert the user
        if (updatedJob.status == 'delivered') {
          AvailLoaders.successSnackBar(title: 'Manifest Delivered', message: 'Your freight has arrived at the destination.');
        }
      });
    }

    if (booking.driverId != null && booking.driverId!.isNotEmpty) {
      _listenToDriverLocation(booking.driverId!);
    }

    // Ensure we are using the home map controller for tracking on the home screen
    if (homeMapController != null) mapController = homeMapController;
    
    drawRouteForActiveJob(booking);
  }

  final RxBool is3DFollowMode = true.obs;

  Future<void> _updateDriverMarkerOnly(LatLng newPos, double newBearing) async {
    final booking = selectedJobOnMap.value;
    final String truckLabel = (booking != null && booking.truckType.isNotEmpty) ? booking.truckType : 'DRIVER';

    final double truckScale = is3DFollowMode.value ? 0.53 : 0.44;
    final driverTruckIcon = await getCachedTopDownTruckMarker(
      containerColor: const Color(0xFF0F172A),
      cabColor: const Color(0xFF0088FF),
      label: truckLabel,
      scale: truckScale,
    );

    final Set<Marker> currentMarkers = Set<Marker>.from(markers);
    currentMarkers.removeWhere((m) => m.markerId.value == 'driver');
    currentMarkers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: newPos,
        rotation: newBearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: (booking != null && booking.driverName != null && booking.driverName!.isNotEmpty)
              ? 'Driver: ${booking.driverName}'
              : 'Driver Location',
          snippet: (booking != null && booking.vehiclePlate != null) ? 'Plate: ${booking.vehiclePlate}' : '',
        ),
        icon: driverTruckIcon,
      ),
    );
    markers.assignAll(currentMarkers);

    // Dynamic Approach Route update from truck location to pickup point
    if (pickupLocation.value != null) {
      final List<LatLng> approachPoints = _getSmartApproachPoints(newPos, pickupLocation.value!);
      if (approachPoints.length >= 2) {
        final Set<Polyline> currentPolylines = Set<Polyline>.from(polylines);
        currentPolylines.removeWhere((p) => p.polylineId.value.contains('driver_pickup'));
        currentPolylines.addAll(
          SmartRoutingEngine.instance.buildMultiLayeredPolylines(
            baseId: 'driver_pickup',
            points: approachPoints,
            source: RouteSource.googleDirections,
            primaryColor: const Color(0xFF0088FF),
            coreWidth: 3.8,
            baseZIndex: 20,
          ),
        );
        polylines.assignAll(currentPolylines);
      }
    }

    if (is3DFollowMode.value && mapController != null) {
      try {
        mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPos,
              zoom: 18.0,
              tilt: 58.0,
              bearing: newBearing,
            ),
          ),
        );
      } catch (_) {}
    }
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();
    _rtdbDriverLocationSubscription?.cancel();
    if (driverId.isEmpty) return;

    // 1. High-Speed Sub-50ms Stream from Firebase Realtime Database
    try {
      final rtdbRef = FirebaseDatabase.instance.ref('drivers_live/$driverId');
      _rtdbDriverLocationSubscription = rtdbRef.onValue.listen((event) async {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          final double? lat = (data['lat'] as num?)?.toDouble();
          final double? lng = (data['lng'] as num?)?.toDouble();

          if (lat != null && lng != null) {
            final LatLng newPos = LatLng(lat, lng);
            final double newBearing = (data['heading'] as num?)?.toDouble() ?? (data['bearing'] as num?)?.toDouble() ?? _activeDriverBearing;

            _lastActiveDriverPos = newPos;
            _activeDriverBearing = newBearing;
            driverLocation.value = newPos;

            await _updateDriverMarkerOnly(newPos, newBearing);
          }
        }
      });
    } catch (_) {}

    // 2. Fallback to Cloud Firestore Document Listener
    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data['currentLocation'] is GeoPoint) {
          final GeoPoint geo = data['currentLocation'] as GeoPoint;
          final LatLng newPos = LatLng(geo.latitude, geo.longitude);

          double newBearing = 0.0;
          if (data['heading'] != null) {
            newBearing = (data['heading'] as num).toDouble();
          } else if (data['bearing'] != null) {
            newBearing = (data['bearing'] as num).toDouble();
          } else if (_lastActiveDriverPos != null) {
            if (_lastActiveDriverPos!.latitude != newPos.latitude || _lastActiveDriverPos!.longitude != newPos.longitude) {
              newBearing = Geolocator.bearingBetween(
                _lastActiveDriverPos!.latitude, _lastActiveDriverPos!.longitude,
                newPos.latitude, newPos.longitude,
              );
            } else {
              newBearing = _activeDriverBearing;
            }
          }

          _lastActiveDriverPos = newPos;
          _activeDriverBearing = newBearing;
          driverLocation.value = newPos;

          await _updateDriverMarkerOnly(newPos, newBearing);
        }
      }
    });
  }

  void _listenToOnlineDrivers() {
    _nearbyDriversSubscription?.cancel();
    _nearbyDriversSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs;
      final List<DriverModel> drivers = docs
          .map((doc) => DriverModel.fromSnapshot(doc))
          .where((driver) => driver.status != 'offline' && driver.currentLocation != null)
          .toList();

      availableDrivers.assignAll(drivers);
      _updateHomeMapTruckMarkers();
    });
  }

  Future<void> _updateHomeMapTruckMarkers() async {
    if (selectedJobOnMap.value != null) return;

    final Map<String, Marker> updatedMarkers = {};

    for (var m in markers) {
      if (['pickup', 'destination'].contains(m.markerId.value) || m.markerId.value.startsWith('stop_')) {
        updatedMarkers[m.markerId.value] = m;
      }
    }

    final String targetTruck = selectedTruckType.value.toLowerCase().trim();

    for (var driver in availableDrivers) {
      if (driver.currentLocation == null) continue;

      final driverPos = LatLng(driver.currentLocation!.latitude, driver.currentLocation!.longitude);
      final oldPos = driverLastPositions[driver.id];
      double bearing = driverRotations[driver.id] ?? 0.0;

      if (oldPos != null && (oldPos.latitude != driverPos.latitude || oldPos.longitude != driverPos.longitude)) {
        bearing = Geolocator.bearingBetween(
          oldPos.latitude, oldPos.longitude,
          driverPos.latitude, driverPos.longitude,
        );
        driverRotations[driver.id] = bearing;
      }
      driverLastPositions[driver.id] = driverPos;

      final driverVehicle = driver.vehicleType.toLowerCase().trim();
      final isMatching = targetTruck.isEmpty || driverVehicle.contains(targetTruck) || targetTruck.contains(driverVehicle);

      final Color cabColor = isMatching ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
      final String label = driver.vehicleType.isNotEmpty ? driver.vehicleType : 'Truck';

      final truckIcon = await getCachedTopDownTruckMarker(
        containerColor: const Color(0xFF0F172A),
        cabColor: cabColor,
        label: label,
      );

      updatedMarkers['driver_truck_${driver.id}'] = Marker(
        markerId: MarkerId('driver_truck_${driver.id}'),
        position: driverPos,
        rotation: bearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        icon: truckIcon,
        infoWindow: InfoWindow(
          title: driver.fullName.isNotEmpty ? driver.fullName : 'Verified Driver',
          snippet: '${driver.vehicleType.toUpperCase()} • ${driver.licensePlate}',
        ),
        onTap: () => showTruckDetailsBottomSheet(driver),
      );
    }

    markers.assignAll(updatedMarkers.values.toSet());
  }

  void showTruckDetailsBottomSheet(DriverModel driver) {
    HapticFeedback.selectionClick();
    final LatLng driverPos = LatLng(driver.currentLocation!.latitude, driver.currentLocation!.longitude);

    String distanceStr = '';
    if (pickupLocation.value != null) {
      final double distMeters = Geolocator.distanceBetween(
        pickupLocation.value!.latitude, pickupLocation.value!.longitude,
        driverPos.latitude, driverPos.longitude,
      );
      final double distKm = distMeters / 1000;
      distanceStr = '${distKm.toStringAsFixed(1)} KM away from Pickup';
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? AvailColors.dark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.truck_fast, color: AvailColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName.isNotEmpty ? driver.fullName : 'Verified Freight Driver',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${driver.vehicleType.toUpperCase()} ${driver.licensePlate.isNotEmpty ? "• ${driver.licensePlate}" : ""}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        if (distanceStr.isNotEmpty)
                          Text(distanceStr, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.green),
                        SizedBox(width: 4),
                        Text('AVAILABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  if (driver.vehicleType.isNotEmpty) {
                    selectedTruckType.value = driver.vehicleType;
                  }
                  drawRoute();
                  AvailLoaders.successSnackBar(
                    title: 'Truck Selected',
                    message: 'Configured job for ${driver.fullName}\'s ${driver.vehicleType.toUpperCase()}.',
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AvailColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('SELECT THIS TRUCK FOR FREIGHT JOB', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void clearMapTracking() {
    _jobSubscription?.cancel();
    _jobSubscription = null;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    driverLocation.value = null;
    selectedJobOnMap.value = null;
    polylines.clear();
    markers.clear();
    destinationLocation.value = null;
    destinationName.value = 'Where to?';
    if (currentPosition.value != null) {
      pickupLocation.value = currentPosition.value;
      _safeAnimateCamera(homeMapController ?? mapController, CameraUpdate.newLatLngZoom(currentPosition.value!, 15));
    }
  }

  @override
  void onClose() {
    _pricingConfigSubscription?.cancel();
    _jobSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _nearbyDriversSubscription?.cancel();
    loadDescriptionController.dispose();
    senderNameController.dispose();
    senderPhoneController.dispose();
    receiverNameController.dispose();
    receiverPhoneController.dispose();
    pickupAddressController.dispose();
    dropoffAddressController.dispose();
    materialTypeController.dispose();
    weightController.dispose();
    super.onClose();
  }

  Future<void> callDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      AvailLoaders.errorSnackBar(title: 'Call Error', message: 'Could not launch dialer');
    }
  }

  void shareManifest(BookingModel job) {
    final String bookingId = job.bookingId;
    String displayId = "FT-";
    if (bookingId.length >= 8) {
      displayId += "${bookingId.substring(0, 4)}-${bookingId.substring(4, 8)}".toUpperCase();
    } else {
      displayId += bookingId.toUpperCase();
    }

    final message = '''
📜 FREIGHT MANIFEST: $displayId
🚛 Status: ${job.status.toUpperCase()}
📦 Cargo: ${job.cargoType} (${job.weight} Tons)
📍 Pickup: ${job.pickupAddress}
🏁 Destination: ${job.dropoffAddress}
💰 Total Rate: GHS ${job.price.toStringAsFixed(2)}
${job.driverName != null ? '👨‍✈️ Driver: ${job.driverName} (${job.driverPhone})' : '⌛ Waiting for driver assignment...'}
Powered by Truck Booking App
''';
    
    Share.share(message);
  }

  void swapPickupAndDestination() {
    final tempLoc = pickupLocation.value;
    final tempName = pickupName.value;
    final tempText = pickupAddressController.text;

    pickupLocation.value = destinationLocation.value;
    pickupName.value = destinationName.value;
    pickupAddressController.text = dropoffAddressController.text;

    destinationLocation.value = tempLoc;
    destinationName.value = tempName;
    dropoffAddressController.text = tempText;

    drawRoute();
    AvailLoaders.customToast(message: 'Route directions reversed');
  }

  void reverseRoute() => swapPickupAndDestination();

  void setPickup(LatLng pos, String name) {
    pickupLocation.value = pos;
    pickupName.value = name;
    pickupAddressController.text = name;
    drawRoute();

    if (name.toLowerCase().contains('current location') || name.trim().isEmpty) {
      reverseGeocode(pos).then((resolved) {
        if (resolved.isNotEmpty && !resolved.toLowerCase().contains('current location')) {
          pickupName.value = resolved;
          pickupAddressController.text = resolved;
        }
      });
    }
  }

  void setDestination(LatLng pos, String name) {
    destinationLocation.value = pos;
    destinationName.value = name;
    dropoffAddressController.text = name;
    drawRoute();

    if (name.toLowerCase().contains('current location') || name.trim().isEmpty) {
      reverseGeocode(pos).then((resolved) {
        if (resolved.isNotEmpty && !resolved.toLowerCase().contains('current location')) {
          destinationName.value = resolved;
          dropoffAddressController.text = resolved;
        }
      });
    }
  }

  void addStop(LatLng pos, String name) {
    additionalStops.add({'address': name, 'lat': pos.latitude, 'lng': pos.longitude});
    drawRoute();
  }

  void removeStop(int index) {
    if (index >= 0 && index < additionalStops.length) {
      additionalStops.removeAt(index);
      drawRoute();
    }
  }

  void reorderStop(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex >= 0 && oldIndex < additionalStops.length && newIndex >= 0 && newIndex <= additionalStops.length) {
      final item = additionalStops.removeAt(oldIndex);
      additionalStops.insert(newIndex, item);
      drawRoute();
    }
  }

  List<LatLng>? getRouteFromCache(LatLng origin, LatLng destination) {
    final cacheKey = '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}_${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';
    return _routeCache[cacheKey];
  }

  Future<List<LatLng>> fetchRoutePoints(LatLng origin, LatLng destination) async {
    return _fetchRoutePoints(origin, destination);
  }

  List<LatLng> _lastApproachRoutePoints = [];

  LatLng _projectPointOntoSegment(LatLng P, LatLng A, LatLng B) {
    final double ax = A.longitude;
    final double ay = A.latitude;
    final double bx = B.longitude;
    final double by = B.latitude;
    final double px = P.longitude;
    final double py = P.latitude;

    final double dx = bx - ax;
    final double dy = by - ay;

    if (dx == 0 && dy == 0) return A;

    final double t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final double clampedT = t.clamp(0.0, 1.0);

    return LatLng(ay + clampedT * dy, ax + clampedT * dx);
  }

  List<LatLng> _getSmartApproachPoints(LatLng driverPos, LatLng pickup) {
    if (_lastApproachRoutePoints.length >= 2) {
      int bestSegmentIndex = 0;
      double minPerpDist = double.infinity;
      LatLng bestSnapPoint = driverPos;

      for (int i = 0; i < _lastApproachRoutePoints.length - 1; i++) {
        final projected = _projectPointOntoSegment(driverPos, _lastApproachRoutePoints[i], _lastApproachRoutePoints[i + 1]);
        final dist = Geolocator.distanceBetween(
          driverPos.latitude, driverPos.longitude,
          projected.latitude, projected.longitude,
        );
        if (dist < minPerpDist) {
          minPerpDist = dist;
          bestSegmentIndex = i;
          bestSnapPoint = projected;
        }
      }

      final remainingWaypoints = _lastApproachRoutePoints.skip(bestSegmentIndex + 1).toList();
      if (remainingWaypoints.isNotEmpty) {
        final startPoint = minPerpDist <= 28 ? bestSnapPoint : driverPos;
        return [startPoint, ...remainingWaypoints];
      }
    }
    return [driverPos, pickup];
  }

  Future<List<LatLng>> _fetchRoutePoints(LatLng origin, LatLng destination) async {
    final route = await SmartRoutingEngine.instance.getRoute(
      origin: origin,
      destination: destination,
    );
    if (route.points.length > 2) {
      _lastApproachRoutePoints = route.points;
    }
    return route.points;
  }

  Future<void> drawRouteForActiveJob(BookingModel booking) async {
    final LatLng pickup = booking.pickupLocation != null && booking.pickupLocation!.latitude != 0
        ? LatLng(booking.pickupLocation!.latitude, booking.pickupLocation!.longitude)
        : (pickupLocation.value ?? const LatLng(5.6037, -0.1870));
    final LatLng dropoff = booking.dropoffLocation != null && booking.dropoffLocation!.latitude != 0
        ? LatLng(booking.dropoffLocation!.latitude, booking.dropoffLocation!.longitude)
        : (destinationLocation.value ?? LatLng(pickup.latitude + 0.015, pickup.longitude + 0.015));

    final LatLng? driverPos = driverLocation.value;

    final Map<String, Marker> newMarkers = {};

    // 1. Pickup Pin
    newMarkers['pickup'] = Marker(
      markerId: const MarkerId('pickup'),
      position: pickup,
      infoWindow: InfoWindow(title: 'Pickup: ${booking.pickupAddress}'),
      icon: customPickupMarkerIcon ?? pickupIcon,
      anchor: pinAnchor,
    );

    // 2. Dropoff Pin
    newMarkers['destination'] = Marker(
      markerId: const MarkerId('destination'),
      position: dropoff,
      infoWindow: InfoWindow(title: 'Dropoff: ${booking.dropoffAddress}'),
      icon: customDropoffMarkerIcon ?? destinationIcon,
      anchor: pinAnchor,
    );

    // 3. Intermediate Stops
    for (int i = 0; i < booking.stops.length; i++) {
      final stop = booking.stops[i];
      final stopIcon = await buildStopMarkerIcon(i + 1);
      newMarkers['stop_$i'] = Marker(
        markerId: MarkerId('stop_$i'),
        position: LatLng(stop['lat'], stop['lng']),
        infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
        icon: stopIcon,
        anchor: pinAnchor,
      );
    }

    // 4. Driver Marker
    if (driverPos != null) {
      if (_lastActiveDriverPos != null && (_lastActiveDriverPos!.latitude != driverPos.latitude || _lastActiveDriverPos!.longitude != driverPos.longitude)) {
        _activeDriverBearing = Geolocator.bearingBetween(
          _lastActiveDriverPos!.latitude, _lastActiveDriverPos!.longitude,
          driverPos.latitude, driverPos.longitude,
        );
      }
      _lastActiveDriverPos = driverPos;

      final double truckScale = is3DFollowMode.value ? 0.53 : 0.44;
      final driverTruckIcon = await getCachedTopDownTruckMarker(
        containerColor: const Color(0xFF0F172A),
        cabColor: const Color(0xFF0088FF),
        label: booking.truckType.isNotEmpty ? booking.truckType : 'DRIVER',
        scale: truckScale,
      );

      newMarkers['driver'] = Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        rotation: _activeDriverBearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: booking.driverName != null && booking.driverName!.isNotEmpty
              ? 'Driver: ${booking.driverName}'
              : 'Driver Location',
          snippet: booking.vehiclePlate != null ? 'Plate: ${booking.vehiclePlate}' : '',
        ),
        icon: driverTruckIcon,
      );
    }

    // 5. Polylines
    final Set<Polyline> newPolylines = {};

    // Approach Segment (Driver -> Pickup in Vibrant Blue)
    if (driverPos != null) {
      final approachRoute = await SmartRoutingEngine.instance.getRoute(
        origin: driverPos,
        destination: pickup,
      );
      if (approachRoute.points.length >= 2) {
        newPolylines.addAll(
          SmartRoutingEngine.instance.buildMultiLayeredPolylines(
            baseId: 'driver_pickup',
            points: approachRoute.points,
            source: approachRoute.source,
            primaryColor: const Color(0xFF0088FF),
            coreWidth: 3.8,
            baseZIndex: 20,
          ),
        );
      }
    }

    // Extract intermediate stops as strict waypoints
    final List<LatLng> waypointsList = booking.stops
        .where((s) => s['lat'] != null && s['lng'] != null)
        .map((s) => LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()))
        .toList();

    // Freight Route Segment (Pickup -> Dropoff with intermediate stops)
    final freightRoute = await SmartRoutingEngine.instance.getRoute(
      origin: pickup,
      destination: dropoff,
      waypoints: waypointsList,
      forceRefresh: true,
    );
    final allRoutes = [freightRoute, ...freightRoute.suggestedAlternatives];
    suggestedRoutes.assignAll(allRoutes);
    selectedRouteIndex.value = 0;
    currentRouteData.value = freightRoute;
    isRouteHUDVisible.value = true;
    final freightPoints = freightRoute.points;

    if (freightPoints.isNotEmpty) {
      newPolylines.addAll(
        SmartRoutingEngine.instance.buildMultiRoutePolylines(
          routes: suggestedRoutes,
          selectedIndex: selectedRouteIndex.value,
          onSelectRoute: (idx) => selectSuggestedRoute(idx),
          coreWidth: 3.8,
        ),
      );
    }

    markers.assignAll(newMarkers.values.toSet());
    polylines.assignAll(newPolylines);

    // 6. Interactive Route Midpoint Callout Badges
    await _updateRouteBadgeMarkers();

    // 7. Update Map Camera to fit bounds including all intermediate stops
    final List<LatLng> boundsPoints = [pickup, dropoff, ...waypointsList];
    if (driverPos != null) boundsPoints.add(driverPos);

    if (mapController != null && boundsPoints.isNotEmpty) {
      double minLat = boundsPoints.first.latitude;
      double maxLat = boundsPoints.first.latitude;
      double minLng = boundsPoints.first.longitude;
      double maxLng = boundsPoints.first.longitude;

      for (var p in boundsPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.005, minLng - 0.005),
        northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
      );

      _safeAnimateCamera(mapController, CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  Future<void> drawRoute() async {
    if (pickupLocation.value == null || destinationLocation.value == null) return;

    final start = pickupLocation.value!;
    final end = destinationLocation.value!;

    // 1. Set Markers
    final Set<Marker> newMarkers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: start,
        infoWindow: const InfoWindow(title: 'Pickup Location'),
        icon: customPickupMarkerIcon ?? pickupIcon,
        anchor: pinAnchor,
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: end,
        infoWindow: const InfoWindow(title: 'Destination Terminal'),
        icon: customDropoffMarkerIcon ?? destinationIcon,
        anchor: pinAnchor,
      ),
    };

    // Add intermediate stop markers
    for (int i = 0; i < additionalStops.length; i++) {
      final stopIcon = await buildStopMarkerIcon(i + 1);
      newMarkers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: LatLng((additionalStops[i]['lat'] as num).toDouble(), (additionalStops[i]['lng'] as num).toDouble()),
        infoWindow: InfoWindow(title: 'Stop ${i + 1}: ${additionalStops[i]['address']}'),
        icon: stopIcon,
        anchor: pinAnchor,
      ));
    }

    markers.assignAll(newMarkers);

    // 2. Compute route via Multi-Tier Smart Routing Engine (Cache -> Google -> OSRM -> Offline Curve)
    final List<LatLng> waypointsList = additionalStops
        .map((s) => LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()))
        .toList();

    final routeData = await SmartRoutingEngine.instance.getRoute(
      origin: start,
      destination: end,
      waypoints: waypointsList,
      forceRefresh: true,
    );

    // Guaranteed shortest/fastest route at index 0, with alternatives if available
    final allRoutes = [routeData, ...routeData.suggestedAlternatives];
    suggestedRoutes.assignAll(allRoutes);
    selectedRouteIndex.value = 0;
    currentRouteData.value = routeData;
    trafficCondition.value = routeData.trafficStatus;
    isRouteHUDVisible.value = true;
    estimatedDistance.value = routeData.distanceText;
    estimatedTime.value = routeData.durationInTrafficText;

    calculatePrice(routeData.distanceKm);

    // 3. Render Triple-Layered Glowing Neon Polylines with Suggested Alternatives
    _renderRoutePolylines();

    // 4. Render Interactive Midpoint Route Callout Badges on the Map
    await _updateRouteBadgeMarkers();

    // 5. Update Map Camera to fit bounds comfortably
    if (mapController != null && routeData.bounds != null) {
      _safeAnimateCamera(mapController, CameraUpdate.newLatLngBounds(routeData.bounds!, 85));
    }

    _updateHomeMapTruckMarkers();
  }

  /// Renders polylines for active route + clickable background alternative routes
  void _renderRoutePolylines() {
    if (suggestedRoutes.isEmpty) {
      polylines.clear();
      return;
    }
    final approachPolylines = polylines.where((p) => p.polylineId.value.startsWith('driver_pickup')).toSet();
    final multiPolylines = SmartRoutingEngine.instance.buildMultiRoutePolylines(
      routes: suggestedRoutes,
      selectedIndex: selectedRouteIndex.value,
      onSelectRoute: (idx) => selectSuggestedRoute(idx),
      coreWidth: 3.8,
    );
    polylines.assignAll({...approachPolylines, ...multiPolylines});
  }

  /// Switch active route between suggested alternatives with dynamic price & polyline update
  void selectSuggestedRoute(int index) async {
    HapticFeedback.selectionClick();
    if (index < 0 || index >= suggestedRoutes.length) return;
    selectedRouteIndex.value = index;
    final selectedRoute = suggestedRoutes[index];
    currentRouteData.value = selectedRoute;
    trafficCondition.value = selectedRoute.trafficStatus;
    estimatedDistance.value = selectedRoute.distanceText;
    estimatedTime.value = selectedRoute.durationInTrafficText;

    // Dynamically recalculate fare price based on selected route distance
    calculatePrice(selectedRoute.distanceKm);

    // Re-render polylines with the selected route brought forward in vivid traffic colors
    _renderRoutePolylines();

    // Re-render midpoint callout badges so active badge highlights
    await _updateRouteBadgeMarkers();

    // Smoothly animate camera bounds to the newly selected route
    if (mapController != null && selectedRoute.bounds != null) {
      _safeAnimateCamera(mapController, CameraUpdate.newLatLngBounds(selectedRoute.bounds!, 85));
    }
  }

  void clearCurrentRoute() {
    polylines.clear();
    currentRouteData.value = null;
    suggestedRoutes.clear();
    selectedRouteIndex.value = 0;
    trafficCondition.value = 'Smooth Traffic Flow';
    isRouteHUDVisible.value = false;
    estimatedDistance.value = '0 km';
    estimatedTime.value = '0 mins';
    pickupLocation.value = null;
    destinationLocation.value = null;
    pickupName.value = 'Current Location';
    destinationName.value = 'Where to?';
    pickupAddressController.clear();
    dropoffAddressController.clear();
    additionalStops.clear();
    _updateHomeMapTruckMarkers();
  }

  void recenterRoute() {
    final route = currentRouteData.value;
    if (mapController != null && route != null && route.bounds != null) {
      _safeAnimateCamera(mapController, CameraUpdate.newLatLngBounds(route.bounds!, 85));
    }
  }

  void validateContainerNumber(String value) {
    if (value.trim().isEmpty) {
      isContainerNumberValid.value = true;
      return;
    }
    isContainerNumberValid.value = isValidISOContainer(value);
  }

  static bool isValidISOContainer(String input) {
    final clean = input.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (clean.length < 10) return true; // Don't trigger error until at least 10 chars typed

    const Map<String, int> letterValues = {
      'A': 10, 'B': 12, 'C': 13, 'D': 14, 'E': 15, 'F': 16, 'G': 17, 'H': 18,
      'I': 19, 'J': 20, 'K': 21, 'L': 23, 'M': 24, 'N': 25, 'O': 26, 'P': 27,
      'Q': 28, 'R': 29, 'S': 30, 'T': 31, 'U': 32, 'V': 34, 'W': 35, 'X': 36, 'Y': 37, 'Z': 38,
    };
    const List<int> weights = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];

    final code10 = clean.substring(0, 10);
    if (!RegExp(r'^[A-Z]{4}\d{6}$').hasMatch(code10)) {
      return false;
    }

    int sum = 0;
    for (int i = 0; i < 10; i++) {
      final char = code10[i];
      int val;
      if (RegExp(r'^[A-Z]$').hasMatch(char)) {
        val = letterValues[char] ?? 0;
      } else {
        val = int.tryParse(char) ?? 0;
      }
      sum += val * weights[i];
    }

    int calculatedCheckDigit = sum % 11;
    if (calculatedCheckDigit == 10) calculatedCheckDigit = 0;

    if (clean.length >= 11) {
      final userCheckDigit = int.tryParse(clean[10]);
      if (userCheckDigit == null) return false;
      return userCheckDigit == calculatedCheckDigit;
    }

    return true;
  }

  static const Map<String, double> isoTareWeights = {
    '22G1': 2.23,
    '22V1': 2.38,
    '22U1': 2.35,
    '22R1': 3.05,
    '22P1': 2.75,
    '22T1': 3.60,
    '42G1': 3.78,
    '45G1': 3.90,
    '45R1': 4.52,
    '42U1': 3.85,
    '45P1': 4.90,
    'L5G1': 4.82,
  };

  double getIsoTareWeight(String code) {
    final cleanCode = code.replaceAll('ISO ', '').trim().toUpperCase();
    for (var entry in isoTareWeights.entries) {
      if (cleanCode.contains(entry.key)) return entry.value;
    }
    return (cleanCode.contains('40') || cleanCode.contains('42') || cleanCode.contains('45') || cleanCode.startsWith('L')) ? 3.90 : 2.23;
  }

  void updateTruckType(String truckName) {
    selectedTruckType.value = truckName;
    final allowedCargo = getActiveCargoTypesForTruck(truckName);
    if (!allowedCargo.contains(selectedCargoType.value)) {
      selectedCargoType.value = allowedCargo.isNotEmpty ? allowedCargo.first : 'General Freight';
    }
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void updateCargoType(String cargo) {
    selectedCargoType.value = cargo;
    if (cargo.toLowerCase().contains('container')) {
      if (selectedContainerSize.value.isEmpty) {
        selectedContainerSize.value = '20ft';
      }
      if (selectedContainerStatus.value.isEmpty) {
        selectedContainerStatus.value = 'Empty';
      }
      if (selectedContainerStatus.value == 'Empty') {
        snapTareWeight();
      }
    }
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void snapTareWeight() {
    if (!selectedCargoType.value.toLowerCase().contains('container') || selectedContainerStatus.value != 'Empty') {
      return;
    }
    final sizeCode = selectedContainerSize.value.toLowerCase();
    double tareKg = 2300.0;
    if (sizeCode.contains('40') || sizeCode.contains('hc')) {
      tareKg = pricingConfig.value.tareWeight40ftKg;
    } else if (sizeCode.contains('twin') || sizeCode.contains('2x')) {
      tareKg = pricingConfig.value.tareWeight20ftKg * 2.0;
    } else {
      tareKg = pricingConfig.value.tareWeight20ftKg;
    }
    final tareTons = tareKg / 1000.0;
    loadWeight.value = tareTons;
    weightController.text = tareTons.toStringAsFixed(2);
  }

  void updateContainerStatus(String status) {
    selectedContainerStatus.value = status;
    if (status == 'Empty') {
      snapTareWeight();
    }
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void updateContainerSize(String size) {
    selectedContainerSize.value = size;
    if (selectedCargoType.value.toLowerCase().contains('container') && selectedContainerStatus.value == 'Empty') {
      snapTareWeight();
    }
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void updateTripType(String type) {
    tripType.value = type;
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void updateLegMode(String legMode) {
    selectedLegMode.value = legMode;
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void updateCurrency(String newCurrency) {
    selectedCurrency.value = newCurrency;
    LocalizationController.instance.changeCurrency(newCurrency);
    final distKm = double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0;
    calculatePrice(distKm);
  }

  void calculatePrice(double distance) {
    final breakdown = calculatedBreakdown;

    baseFee.value = breakdown.baseFee;
    distanceFee.value = breakdown.distanceFee;
    containerDeckSurcharge.value = breakdown.containerDeckSurcharge;
    emptyReturnDiscount.value = breakdown.emptyReturnDiscount;
    excessWeightFee.value = breakdown.excessWeightFee;
    roadAllowance.value = breakdown.roadAllowance;
    fragileSurcharge.value = breakdown.fragileSurcharge;
    hazardousSurcharge.value = breakdown.hazardousSurcharge;
    loadingLaborFee.value = breakdown.loadingLaborFee;
    platformFee.value = breakdown.platformFee;
    driverTotalPayout.value = breakdown.driverTotalPayout;
    journeyCategoryLabel.value = breakdown.journeyCategoryLabel;

    cargoTypePremium.value = containerDeckSurcharge.value;
    optionsFee.value = fragileSurcharge.value + hazardousSurcharge.value + loadingLaborFee.value;

    calculatedPrice.value = breakdown.totalPrice; // STORED IN BASE USD ($)
  }

  Future<void> pickDocument(String source) async {
    try {
      if (source == 'CAMERA' || source == 'GALLERY') {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: source == 'CAMERA' ? ImageSource.camera : ImageSource.gallery,
        );
        if (image != null) {
          pickedDocuments.add({
            'name': '',
            'path': image.path,
            'url': '',
            'type': 'image',
          });
        }
      } else if (source == 'FILE') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
        );

        if (result != null) {
          for (var file in result.files) {
            if (file.path != null) {
              final isImage = ['jpg', 'jpeg', 'png'].contains(file.extension?.toLowerCase());
              pickedDocuments.add({
                'name': '',
                'path': file.path!,
                'url': '',
                'type': isImage ? 'image' : 'file',
              });
            }
          }
        }
      }
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Picker Error', message: e.toString());
    }
  }

  void removeDocument(int index) {
    pickedDocuments.removeAt(index);
  }

  void updateDocumentName(int index, String name) {
    pickedDocuments[index]['name'] = name;
  }

  void addInventoryItem() {
    if (inventoryItemNameController.text.isNotEmpty && inventoryItemQuantityController.text.isNotEmpty) {
      inventoryItems.add({
        'name': inventoryItemNameController.text.trim(),
        'quantity': inventoryItemQuantityController.text.trim(),
      });
      inventoryItemNameController.clear();
      inventoryItemQuantityController.clear();
    }
  }

  void removeInventoryItem(int index) {
    inventoryItems.removeAt(index);
  }

  void resetForm() {
    selectedCargoType.value = 'Container';
    selectedContainerSize.value = '20ft';
    containerSizeDisplayController.text = 'ISO 20ft';
    selectedContainerStatus.value = 'Empty';
    selectedTruckType.value = 'Flatbed / Platform Truck';
    loadWeight.value = 2.3;
    pickedDocuments.clear();
    inventoryItems.clear();
    inventoryItemNameController.clear();
    inventoryItemQuantityController.clear();
    loadDescriptionController.clear();
    senderNameController.clear();
    senderPhoneController.clear();
    receiverNameController.clear();
    receiverPhoneController.clear();
    materialTypeController.clear();
    heavyEquipmentModelController.clear();
    containerNumberController.clear();
    additionalNotesController.clear();
    weightController.text = '2.30';
    cargoValueController.clear();
    scheduledDateTime.value = null;
    selectedPaymentMethod.value = 'Cash on Delivery';
    pickupAddressController.clear();
    dropoffAddressController.clear();
    pickupLocation.value = null;
    pickupName.value = '';
    destinationLocation.value = null;
    destinationName.value = 'Where to?';
    markers.clear();
    polylines.clear();
    estimatedDistance.value = '0 km';
    
    tripType.value = 'single';
    selectedLegMode.value = 'loaded_loaded';
    isHazardous.value = false;
    selectedCurrency.value = 'GHS';
    exchangeRate.value = 1.0;
    baseFee.value = 0.0;
    distanceFee.value = 0.0;
    containerDeckSurcharge.value = 0.0;
    emptyReturnDiscount.value = 0.0;
    excessWeightFee.value = 0.0;
    roadAllowance.value = 0.0;
    fragileSurcharge.value = 0.0;
    hazardousSurcharge.value = 0.0;
    loadingLaborFee.value = 0.0;
    platformFee.value = 0.0;
    driverTotalPayout.value = 0.0;
    journeyCategoryLabel.value = '';
    cargoTypePremium.value = 0.0;
    trafficRiskFee.value = 0.0;
    optionsFee.value = 0.0;
    calculatedPrice.value = 0.0;

    selectedJobOnMap.value = null;
    isFragile.value = false;
    isInsured.value = false;
    requiresAssistance.value = false;
    additionalStops.clear();
    inventoryItems.clear();
    pickedDocuments.clear();
    editingBookingId.value = '';
    editingCustomBookingId.value = '';
  }

  /// Clears form fields only so newly created manifest routes and markers stay rendered on map
  void clearFormFieldsOnly() {
    selectedCargoType.value = 'Container';
    selectedContainerSize.value = '20ft';
    containerSizeDisplayController.text = 'ISO 20ft';
    selectedContainerStatus.value = 'Empty';
    selectedTruckType.value = 'Flatbed / Platform Truck';
    loadWeight.value = 2.3;
    pickedDocuments.clear();
    inventoryItems.clear();
    inventoryItemNameController.clear();
    inventoryItemQuantityController.clear();
    loadDescriptionController.clear();
    senderNameController.clear();
    senderPhoneController.clear();
    receiverNameController.clear();
    receiverPhoneController.clear();
    materialTypeController.clear();
    heavyEquipmentModelController.clear();
    containerNumberController.clear();
    additionalNotesController.clear();
    weightController.text = '2.30';
    cargoValueController.clear();
    scheduledDateTime.value = null;
    selectedPaymentMethod.value = 'Cash on Delivery';
    pickupAddressController.clear();
    dropoffAddressController.clear();
    pickupLocation.value = null;
    pickupName.value = '';
    destinationLocation.value = null;
    destinationName.value = 'Where to?';
    
    tripType.value = 'single';
    selectedLegMode.value = 'loaded_loaded';
    isHazardous.value = false;
    selectedCurrency.value = 'GHS';
    exchangeRate.value = 1.0;
    baseFee.value = 0.0;
    distanceFee.value = 0.0;
    containerDeckSurcharge.value = 0.0;
    emptyReturnDiscount.value = 0.0;
    excessWeightFee.value = 0.0;
    roadAllowance.value = 0.0;
    fragileSurcharge.value = 0.0;
    hazardousSurcharge.value = 0.0;
    loadingLaborFee.value = 0.0;
    platformFee.value = 0.0;
    driverTotalPayout.value = 0.0;
    journeyCategoryLabel.value = '';
    cargoTypePremium.value = 0.0;
    trafficRiskFee.value = 0.0;
    optionsFee.value = 0.0;
    calculatedPrice.value = 0.0;

    isFragile.value = false;
    isInsured.value = false;
    requiresAssistance.value = false;
    additionalStops.clear();
    editingBookingId.value = '';
    editingCustomBookingId.value = '';
  }

  void populateForEditing(BookingModel booking) {
    editingBookingId.value = booking.id;
    editingCustomBookingId.value = booking.bookingId;
    selectedCargoType.value = booking.cargoType;
    selectedContainerSize.value = booking.containerSize;
    selectedContainerStatus.value = booking.containerStatus.isNotEmpty ? booking.containerStatus : 'Empty';
    selectedTruckType.value = booking.truckType;
    tripType.value = booking.tripType;
    selectedLegMode.value = booking.roundTripLegMode;
    isHazardous.value = booking.isHazardous;
    selectedCurrency.value = booking.currency;

    weightController.text = booking.weight > 0 ? booking.weight.toString() : '';
    loadDescriptionController.text = booking.loadDescription;
    senderNameController.text = booking.senderName;
    senderPhoneController.text = booking.senderPhone;
    receiverNameController.text = booking.receiverName;
    receiverPhoneController.text = booking.receiverPhone;

    pickupName.value = booking.pickupAddress;
    pickupAddressController.text = booking.pickupAddress;
    destinationName.value = booking.dropoffAddress;
    dropoffAddressController.text = booking.dropoffAddress;

    if (booking.pickupLocation != null) {
      pickupLocation.value = LatLng(booking.pickupLocation!.latitude, booking.pickupLocation!.longitude);
    }
    if (booking.dropoffLocation != null) {
      destinationLocation.value = LatLng(booking.dropoffLocation!.latitude, booking.dropoffLocation!.longitude);
    }

    isFragile.value = booking.isFragile;
    isInsured.value = booking.isInsured;
    requiresAssistance.value = booking.requiresLoadingAssistance;

    cargoValueController.text = (booking.cargoValue != null && booking.cargoValue! > 0) ? booking.cargoValue.toString() : '';
    scheduledDateTime.value = booking.scheduledDate;
    selectedPaymentMethod.value = booking.paymentMethod ?? 'Cash on Delivery';

    inventoryItems.assignAll(booking.inventory);
    additionalStops.assignAll(booking.stops);

    // Populate existing documents attached to this booking
    pickedDocuments.assignAll(booking.documents.map((doc) => {
      'name': doc['name'] ?? '',
      'path': doc['path'] ?? doc['url'] ?? '',
      'url': doc['url'] ?? '',
      'type': ((doc['path'] ?? doc['url'] ?? '').toLowerCase().endsWith('.pdf')) ? 'file' : 'image',
    }).toList());

    drawRoute();
  }

  Future<void> saveBooking() async {
    try {
      // 1. Mandatory Gatekeeper: Ensure Shipper is identity-verified AND approved by admin
      if (!checkShipperVerificationAndApproval()) {
        return;
      }

      AvailFullScreenLoader.openLoadingDialog('Processing your booking & uploading files...', 'assets/images/animations/loader-animation.json');

      if (!bookingFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      String customBookingId = editingCustomBookingId.value;

      if (editingBookingId.value.isEmpty || customBookingId.isEmpty) {
        try {
          customBookingId = await IdGenerator.generate(
            prefix: 'FT-',
            includeYear: true,
            includeMonth: true,
            includeDay: true,
          );
        } catch (e) {
          final now = DateTime.now();
          final dateStr = DateFormat('yyMMdd').format(now);
          final randomNum = (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
          customBookingId = 'FT-$dateStr-$randomNum';
        }
      }

      // Sync and upload picked documents to Firebase Storage
      final List<Map<String, String>> uploadedDocuments = [];
      for (int i = 0; i < pickedDocuments.length; i++) {
        final doc = pickedDocuments[i];
        final name = (doc['name'] as String? ?? '').trim();
        final path = (doc['path'] as String? ?? '').trim();
        String url = (doc['url'] as String? ?? '').trim();

        if (url.isEmpty && path.isNotEmpty && !path.startsWith('http')) {
          final file = File(path);
          if (file.existsSync()) {
            try {
              final docName = name.isNotEmpty ? name : 'doc_${i + 1}';
              final extension = path.contains('.') ? path.split('.').last : 'jpg';
              final sanitizedName = docName.replaceAll(RegExp(r'[^\w.]'), '_');
              final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}_$sanitizedName.$extension';

              final ref = FirebaseStorage.instance
                  .ref()
                  .child('booking_documents')
                  .child(customBookingId)
                  .child(fileName);

              await ref.putFile(file);
              url = await ref.getDownloadURL();
            } catch (e) {
              debugPrint('Error uploading document to Firebase Storage: $e');
            }
          }
        } else if (url.isEmpty && path.startsWith('http')) {
          url = path;
        }

        uploadedDocuments.add({
          'name': name.isNotEmpty ? name : 'Freight Document ${i + 1}',
          'path': path,
          'url': url,
        });
      }

      // Resolve any placeholder addresses like "Current Location" before saving to Firestore
      String finalPickupAddress = pickupName.value.trim();
      if ((finalPickupAddress.isEmpty ||
              finalPickupAddress.toLowerCase().contains('current location') ||
              finalPickupAddress == 'Select pickup point') &&
          pickupLocation.value != null) {
        final geocoded = await reverseGeocode(pickupLocation.value!);
        if (geocoded.isNotEmpty && !geocoded.toLowerCase().contains('current location')) {
          finalPickupAddress = geocoded;
          pickupName.value = geocoded;
          pickupAddressController.text = geocoded;
        } else {
          finalPickupAddress = 'GPS: ${pickupLocation.value!.latitude.toStringAsFixed(4)}, ${pickupLocation.value!.longitude.toStringAsFixed(4)}';
        }
      }

      String finalDropoffAddress = destinationName.value.trim();
      if ((finalDropoffAddress.isEmpty ||
              finalDropoffAddress.toLowerCase().contains('current location') ||
              finalDropoffAddress == 'Where to?' ||
              finalDropoffAddress == 'Select destination / dropoff') &&
          destinationLocation.value != null) {
        final geocoded = await reverseGeocode(destinationLocation.value!);
        if (geocoded.isNotEmpty && !geocoded.toLowerCase().contains('current location')) {
          finalDropoffAddress = geocoded;
          destinationName.value = geocoded;
          dropoffAddressController.text = geocoded;
        } else {
          finalDropoffAddress = 'GPS: ${destinationLocation.value!.latitude.toStringAsFixed(4)}, ${destinationLocation.value!.longitude.toStringAsFixed(4)}';
        }
      }

      final List<Map<String, dynamic>> sanitizedStops = [];
      for (final stop in additionalStops) {
        String sAddr = (stop['address'] ?? stop['description'] ?? stop['title'] ?? '').toString().trim();
        final double? sLat = (stop['lat'] as num?)?.toDouble();
        final double? sLng = (stop['lng'] as num?)?.toDouble();
        if ((sAddr.isEmpty || sAddr.toLowerCase().contains('current location')) && sLat != null && sLng != null) {
          final geocoded = await reverseGeocode(LatLng(sLat, sLng));
          if (geocoded.isNotEmpty && !geocoded.toLowerCase().contains('current location')) {
            sAddr = geocoded;
          } else {
            sAddr = 'GPS: ${sLat.toStringAsFixed(4)}, ${sLng.toStringAsFixed(4)}';
          }
        }
        sanitizedStops.add({
          'address': sAddr,
          'lat': sLat ?? 0.0,
          'lng': sLng ?? 0.0,
        });
      }

      final booking = BookingModel(
        id: editingBookingId.value,
        bookingId: customBookingId,
        userId: AuthenticationRepository.instance.authUser?.uid ?? '',
        cargoType: selectedCargoType.value,
        containerSize: selectedContainerSize.value,
        containerStatus: selectedContainerStatus.value,
        loadDescription: loadDescriptionController.text.trim(),
        senderName: senderNameController.text.trim(),
        senderPhone: senderPhoneController.text.trim(),
        receiverName: receiverNameController.text.trim(),
        receiverPhone: receiverPhoneController.text.trim(),
        status: 'pending',
        timestamp: DateTime.now(),
        truckType: selectedTruckType.value,
        price: calculatedPrice.value,
        pickupAddress: finalPickupAddress,
        dropoffAddress: finalDropoffAddress,
        weight: double.tryParse(weightController.text) ?? 0.0,
        distance: double.tryParse(estimatedDistance.value.replaceAll(' km', '')) ?? 0.0,
        pickupLocation: pickupLocation.value != null ? GeoPoint(pickupLocation.value!.latitude, pickupLocation.value!.longitude) : null,
        dropoffLocation: destinationLocation.value != null ? GeoPoint(destinationLocation.value!.latitude, destinationLocation.value!.longitude) : null,
        isFragile: isFragile.value,
        isInsured: isInsured.value,
        requiresLoadingAssistance: requiresAssistance.value,
        isHazardous: isHazardous.value,
        tripType: tripType.value,
        roundTripLegMode: selectedLegMode.value,
        journeyCategory: journeyCategoryLabel.value,
        containerDeckSurcharge: containerDeckSurcharge.value,
        emptyReturnDiscount: emptyReturnDiscount.value,
        excessWeightFee: excessWeightFee.value,
        specialSurcharges: fragileSurcharge.value + hazardousSurcharge.value + loadingLaborFee.value,
        roadAllowance: roadAllowance.value,
        loadingLaborFee: loadingLaborFee.value,
        platformFee: platformFee.value,
        driverEarnings: driverTotalPayout.value,
        currency: selectedCurrency.value,
        scheduledDate: scheduledDateTime.value,
        cargoValue: double.tryParse(cargoValueController.text) ?? 0.0,
        paymentMethod: selectedPaymentMethod.value,
        inventory: inventoryItems.toList(),
        stops: sanitizedStops,
        documents: uploadedDocuments,
      );

      if (editingBookingId.value.isNotEmpty) {
        await BookingRepository.instance.updateBooking(booking);
        AvailFullScreenLoader.stopLoading();
        AvailLoaders.successSnackBar(title: 'Manifest Updated', message: 'The freight manifest has been updated successfully.');
      } else {
        final savedId = await BookingRepository.instance.saveBooking(booking);
        booking.id = savedId;
        AvailFullScreenLoader.stopLoading();
        AvailLoaders.successSnackBar(title: 'Success', message: 'Your booking has been saved and documents synced.');
      }

      clearFormFieldsOnly();
      if (Get.isRegistered<NavigationController>()) {
        NavigationController.instance.selectedIndex.value = 0;
      }
      if (Get.isOverlaysOpen) {
        Get.back(closeOverlays: true);
      }
      Get.until((route) => route.isFirst || route.settings.name == '/NavigationMenu');

      // Immediately display and draw the newly created manifest on the home map!
      Future.delayed(const Duration(milliseconds: 350), () {
        showJobOnMap(booking);
      });

    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Oh Snap!', message: e.toString());
    }
  }
}
