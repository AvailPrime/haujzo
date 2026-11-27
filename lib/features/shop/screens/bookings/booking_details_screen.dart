import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../commons/widgets/images/driver_profile_avatar.dart';
import '../../../../data/repositories/bookings/booking_repository.dart';
import '../../../../data/repositories/support/support_config_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/notifications/trip_payment_alert_service.dart';
import '../../controllers/customer/customer_home_controller.dart';
import '../../controllers/customer/trip_payment_controller.dart';
import '../../../personalization/controllers/localization_controller.dart';
import '../../models/booking_model.dart';
import '../chat/trip_chat_screen.dart';
import 'widgets/cancel_refund_dialog.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../../../utils/helpers/pdf_helper.dart';
import '../../../../routes/routes.dart';

import 'package:truck_booking/data/services/routing/smart_routing_engine.dart';
import 'package:truck_booking/utils/constants/map_styles.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingModel booking;
  final bool openPaymentSheetOnLoad;
  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.openPaymentSheetOnLoad = false,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late BookingModel _currentBooking;
  StreamSubscription<BookingModel>? _bookingSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverLocationSub;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  late List<Map<String, String>> _localDocuments;
  bool _isSaving = false;

  LatLng? _driverPos;
  LatLng? _lastDriverPos;
  double _driverBearing = 0.0;
  bool _isTrafficEnabled = false;
  bool _is3DFollowMode = false;
  MapType _mapType = MapType.normal;

  List<RouteDataModel> _suggestedRoutes = [];
  int _selectedRouteIndex = 0;
  List<LatLng> _approachPoints = [];

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    _localDocuments = List.from(widget.booking.documents);
    _listenToBookingUpdates();
    _listenToDriverLocation();
    _loadRoute();

    if (widget.openPaymentSheetOnLoad && !_currentBooking.isPaidOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          TripPaymentAlertService.instance.openManualPaymentSheet(_currentBooking);
        }
      });
    } else if (_currentBooking.requiresOnlinePaymentPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          TripPaymentAlertService.instance.triggerLoadedPaymentAlert(_currentBooking);
        }
      });
    }
  }

  void _listenToBookingUpdates() {
    _bookingSub?.cancel();
    _bookingSub = BookingRepository.instance.getBookingStream(widget.booking.id).listen((updated) {
      if (mounted) {
        final driverIdChanged = updated.driverId != _currentBooking.driverId;
        final becameLoadedUnpaid = !_currentBooking.requiresOnlinePaymentPrompt && updated.requiresOnlinePaymentPrompt;
        setState(() {
          _currentBooking = updated;
        });
        if (driverIdChanged) {
          _listenToDriverLocation();
        }
        if (becameLoadedUnpaid) {
          TripPaymentAlertService.instance.triggerLoadedPaymentAlert(updated);
        }
        _loadRoute();
      }
    });
  }

  Future<void> _updateDriverMarkerOnly() async {
    if (_driverPos == null) return;

    final controller = CustomerHomeController.instance;
    final double truckScale = _is3DFollowMode ? 0.53 : 0.54;
    final driverTruckIcon = await controller.getCachedTopDownTruckMarker(
      containerColor: const Color(0xFF0F172A),
      cabColor: const Color(0xFF0088FF),
      label: _currentBooking.truckType.isNotEmpty ? _currentBooking.truckType : 'DRIVER',
      scale: truckScale,
    );

    final updatedMarker = Marker(
      markerId: const MarkerId('driver'),
      position: _driverPos!,
      rotation: _driverBearing,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(
        title: _currentBooking.driverName != null && _currentBooking.driverName!.isNotEmpty
            ? 'Driver: ${_currentBooking.driverName}'
            : 'Driver Location',
        snippet: _currentBooking.vehiclePlate != null ? 'Plate: ${_currentBooking.vehiclePlate}' : '',
      ),
      icon: driverTruckIcon,
    );

    final pickup = _currentBooking.pickupLocation != null 
        ? LatLng(_currentBooking.pickupLocation!.latitude, _currentBooking.pickupLocation!.longitude) 
        : null;

    final Set<Polyline> newApproachPolylines = {};
    if (pickup != null) {
      final approachCoords = await controller.fetchRoutePoints(_driverPos!, pickup);
      if (approachCoords.length >= 2) {
        newApproachPolylines.addAll(
          SmartRoutingEngine.instance.buildMultiLayeredPolylines(
            baseId: 'driver_pickup',
            points: approachCoords,
            source: RouteSource.googleDirections,
            primaryColor: const Color(0xFF0088FF),
            glowColor: const Color(0x330088FF),
            coreWidth: 5.0,
            baseZIndex: 20,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(updatedMarker);

        if (newApproachPolylines.isNotEmpty) {
          _polylines.removeWhere((p) => p.polylineId.value.contains('driver_pickup'));
          _polylines.addAll(newApproachPolylines);
        }
      });

      if (_is3DFollowMode && _mapController != null) {
        try {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _driverPos!,
                zoom: 18.0,
                tilt: 58.0,
                bearing: _driverBearing,
              ),
            ),
          );
        } catch (_) {}
      }
    }
  }

  void _listenToDriverLocation() {
    _driverLocationSub?.cancel();
    final driverId = _currentBooking.driverId;
    if (driverId == null || driverId.isEmpty) return;

    _driverLocationSub = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
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
          } else if (_lastDriverPos != null) {
            if (_lastDriverPos!.latitude != newPos.latitude || _lastDriverPos!.longitude != newPos.longitude) {
              newBearing = Geolocator.bearingBetween(
                _lastDriverPos!.latitude, _lastDriverPos!.longitude,
                newPos.latitude, newPos.longitude,
              );
            } else {
              newBearing = _driverBearing;
            }
          }

          if (mounted) {
            setState(() {
              _driverPos = newPos;
              _driverBearing = newBearing;
              _lastDriverPos = newPos;
            });
            _updateDriverMarkerOnly();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _driverLocationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final controller = CustomerHomeController.instance;

    LatLng? pickup = _currentBooking.pickupLocation != null 
        ? LatLng(_currentBooking.pickupLocation!.latitude, _currentBooking.pickupLocation!.longitude) 
        : null;
    LatLng? dropoff = _currentBooking.dropoffLocation != null 
        ? LatLng(_currentBooking.dropoffLocation!.latitude, _currentBooking.dropoffLocation!.longitude) 
        : null;

    if (pickup == null && _currentBooking.pickupAddress.isNotEmpty) {
      pickup = await controller.geocodeAddressToLatLng(_currentBooking.pickupAddress);
    }
    if (dropoff == null && _currentBooking.dropoffAddress.isNotEmpty) {
      dropoff = await controller.geocodeAddressToLatLng(_currentBooking.dropoffAddress);
    }

    final newMarkers = <Marker>{};

    if (pickup != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('pickup'), 
        position: pickup, 
        icon: controller.customPickupMarkerIcon ?? controller.pickupIcon,
        anchor: CustomerHomeController.pinAnchor,
        infoWindow: InfoWindow(title: 'Pickup: ${_currentBooking.pickupAddress}'),
      ));
    }
    if (dropoff != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('dropoff'), 
        position: dropoff,
        icon: controller.customDropoffMarkerIcon ?? controller.destinationIcon,
        anchor: CustomerHomeController.pinAnchor,
        infoWindow: InfoWindow(title: 'Dropoff: ${_currentBooking.dropoffAddress}'),
      ));
    }

    // Add intermediate stops
    for (int i = 0; i < _currentBooking.stops.length; i++) {
      final stop = _currentBooking.stops[i];
      final stopIcon = await controller.buildStopMarkerIcon(i + 1);
      newMarkers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: LatLng(stop['lat'], stop['lng']),
        infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
        icon: stopIcon,
        anchor: CustomerHomeController.pinAnchor,
      ));
    }

    // Add driver marker if live location available
    if (_driverPos != null) {
      final double truckScale = _is3DFollowMode ? 0.53 : 0.44;
      final driverTruckIcon = await controller.getCachedTopDownTruckMarker(
        containerColor: const Color(0xFF0F172A),
        cabColor: const Color(0xFF0088FF),
        label: _currentBooking.truckType.isNotEmpty ? _currentBooking.truckType : 'DRIVER',
        scale: truckScale,
      );
      newMarkers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverPos!,
        rotation: _driverBearing,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: _currentBooking.driverName != null && _currentBooking.driverName!.isNotEmpty
              ? 'Driver: ${_currentBooking.driverName}'
              : 'Driver Location',
          snippet: _currentBooking.vehiclePlate != null ? 'Plate: ${_currentBooking.vehiclePlate}' : '',
        ),
        icon: driverTruckIcon,
      ));
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });

      final List<LatLng> fitPoints = [
        if (pickup != null) pickup,
        for (final s in _currentBooking.stops)
          if (s['lat'] != null && s['lng'] != null)
            LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
        if (dropoff != null) dropoff,
        if (_driverPos != null) _driverPos!,
      ];
      _fitBoundsMulti(fitPoints);
    }

    // Fetch Real Road Polylines & Live Traffic Alternatives
    if (pickup != null && dropoff != null) {
      if (_driverPos != null) {
        _approachPoints = await controller.fetchRoutePoints(_driverPos!, pickup);
      }

      try {
        final List<LatLng> waypointsList = _currentBooking.stops
            .where((s) => s['lat'] != null && s['lng'] != null)
            .map((s) => LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()))
            .toList();

        final freightRoute = await SmartRoutingEngine.instance.getRoute(
          origin: pickup,
          destination: dropoff,
          waypoints: waypointsList,
          forceRefresh: true,
        );
        _suggestedRoutes = [freightRoute, ...freightRoute.suggestedAlternatives];
        _selectedRouteIndex = 0;
        await _renderPolylinesAndBadges();
      } catch (e) {
        debugPrint('Error loading freight route directions: $e');
      }
    }
  }

  Future<void> _renderPolylinesAndBadges() async {
    if (_suggestedRoutes.isEmpty) return;

    final controller = CustomerHomeController.instance;
    final newPolylines = <Polyline>{};
    final safeIdx = _selectedRouteIndex.clamp(0, _suggestedRoutes.length - 1);

    // 1. Approach polyline (Driver to pickup)
    if (_driverPos != null && _approachPoints.length >= 2) {
      newPolylines.addAll(
        SmartRoutingEngine.instance.buildMultiLayeredPolylines(
          baseId: 'driver_pickup',
          points: _approachPoints,
          source: RouteSource.googleDirections,
          primaryColor: const Color(0xFF0088FF),
          coreWidth: 3.8,
          baseZIndex: 30,
        ),
      );
    }

    // 2. Freight route alternatives
    final multiPolylines = SmartRoutingEngine.instance.buildMultiRoutePolylines(
      routes: _suggestedRoutes,
      selectedIndex: safeIdx,
      onSelectRoute: (idx) {
        if (!mounted) return;
        setState(() {
          _selectedRouteIndex = idx;
        });
        _renderPolylinesAndBadges();
      },
      coreWidth: 3.8,
    );
    newPolylines.addAll(multiPolylines);

    final activeRoute = _suggestedRoutes[safeIdx];
    final rawPickup = _currentBooking.pickupLocation != null && _currentBooking.pickupLocation!.latitude != 0
        ? LatLng(_currentBooking.pickupLocation!.latitude, _currentBooking.pickupLocation!.longitude)
        : null;
    final rawDropoff = _currentBooking.dropoffLocation != null && _currentBooking.dropoffLocation!.latitude != 0
        ? LatLng(_currentBooking.dropoffLocation!.latitude, _currentBooking.dropoffLocation!.longitude)
        : null;

    if (rawPickup != null && rawDropoff != null && activeRoute.points.isNotEmpty) {
      final accessConnectors = SmartRoutingEngine.instance.buildAccessConnectors(
        origin: rawPickup,
        destination: rawDropoff,
        roadPoints: activeRoute.points,
      );
      newPolylines.addAll(accessConnectors);
    }

    // 3. Midpoint Callout Badges
    final newMarkers = Map<String, Marker>.from({
      for (final m in _markers)
        if (!m.markerId.value.startsWith('route_badge')) m.markerId.value: m,
    });

    if (activeRoute.points.isNotEmpty) {
      final snappedPickup = activeRoute.points.first;
      final snappedDropoff = activeRoute.points.last;
      if (newMarkers.containsKey('pickup')) {
        final old = newMarkers['pickup']!;
        newMarkers['pickup'] = old.copyWith(positionParam: snappedPickup);
      }
      if (newMarkers.containsKey('dropoff')) {
        final old = newMarkers['dropoff']!;
        newMarkers['dropoff'] = old.copyWith(positionParam: snappedDropoff);
      }
    }

    for (int i = 0; i < _suggestedRoutes.length; i++) {
      final route = _suggestedRoutes[i];
      final isSelected = (i == safeIdx);
      final subText = isSelected
          ? (i == 0 ? 'Fastest' : 'Active')
          : (route.relativeDistanceText.isNotEmpty
              ? route.relativeDistanceText
              : '+${(route.trafficDelaySeconds / 60).round()}m');

      final badgeIcon = await controller.buildRouteCalloutBadge(
        timeText: route.durationInTrafficText,
        subText: subText,
        isSelected: isSelected,
        trafficColor: route.trafficStatusColor,
      );

      newMarkers['route_badge_$i'] = Marker(
        markerId: MarkerId('route_badge_$i'),
        position: route.midpoint,
        icon: badgeIcon,
        anchor: const Offset(0.5, 0.5),
        consumeTapEvents: true,
        onTap: () {
          if (!mounted) return;
          setState(() {
            _selectedRouteIndex = i;
          });
          _renderPolylinesAndBadges();
        },
      );
    }

    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.addAll(newPolylines);
        _markers.clear();
        _markers.addAll(newMarkers.values);
      });
    }
  }

  void _fitBoundsMulti(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.005, minLng - 0.005),
      northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
    );

    try {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    } catch (e) {
      debugPrint('Details Map Error: $e');
    }
  }

  Future<void> _addMoreDocuments() async {
    final controller = CustomerHomeController.instance;
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkMode ? AvailColors.dark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add More Documentation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSourceOption('Camera', Iconsax.camera, () async {
                    Get.back();
                    await controller.pickDocument('CAMERA');
                    _appendPickedDocs();
                  }),
                  _buildSourceOption('Gallery', Iconsax.gallery, () async {
                    Get.back();
                    await controller.pickDocument('GALLERY');
                    _appendPickedDocs();
                  }),
                  _buildSourceOption('Files', Iconsax.document_upload, () async {
                    Get.back();
                    await controller.pickDocument('FILES');
                    _appendPickedDocs();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _appendPickedDocs() {
    final controller = CustomerHomeController.instance;
    if (controller.pickedDocuments.isNotEmpty) {
      setState(() {
        for (var doc in controller.pickedDocuments) {
          _localDocuments.add({
            'name': doc['name'] as String,
            'path': doc['path'] as String,
            'url': '',
          });
        }
        controller.pickedDocuments.clear();
      });
      _saveDocumentsToFirebase();
    }
  }

  String _resolveDocumentContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveDocumentsToFirebase() async {
    setState(() => _isSaving = true);
    try {
      final List<Map<String, String>> updatedList = [];

      for (var doc in _localDocuments) {
        final path = doc['path'] ?? '';
        final url = doc['url'] ?? '';
        final fileName = doc['name'] ?? 'doc';

        if (url.isNotEmpty) {
          updatedList.add({'name': fileName, 'url': url});
        } else if (path.isNotEmpty && File(path).existsSync()) {
          final extension = path.contains('.')
              ? path.split('.').last.toLowerCase()
              : 'jpg';
          final sanitizedName = fileName.replaceAll(RegExp(r'[^\w.]'), '_');
          final suffix = sanitizedName.toLowerCase().endsWith('.$extension')
              ? ''
              : '.$extension';
          final storageFileName =
              '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName$suffix';
          final ref = FirebaseStorage.instance
              .ref()
              .child('booking_documents')
              .child(_currentBooking.id)
              .child(storageFileName);
          await ref.putFile(
            File(path),
            SettableMetadata(
              contentType: _resolveDocumentContentType(extension),
            ),
          );
          final downloadUrl = await ref.getDownloadURL();
          updatedList.add({'name': fileName, 'url': downloadUrl});
        }
      }

      await BookingRepository.instance.updateBookingDocuments(_currentBooking.id, updatedList);
      if (mounted) {
        setState(() {
          _localDocuments = updatedList.map((e) => {'name': e['name']!, 'path': '', 'url': e['url']!}).toList();
        });
        AvailLoaders.successSnackBar(title: 'Documents Updated', message: 'Your freight manifest attachments have been saved.');
      }
    } catch (e) {
      if (mounted) {
        AvailLoaders.errorSnackBar(title: 'Upload Error', message: 'Failed to upload attachments.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _viewDocument(Map<String, String> doc) async {
    final name = doc['name'] ?? 'Document';
    final path = doc['path'] ?? '';
    final url = doc['url'] ?? '';
    final target = url.isNotEmpty ? url : path;
    final isNetwork = target.startsWith('http');
    final isImage = target.toLowerCase().contains('.jpg') || target.toLowerCase().contains('.png') || target.toLowerCase().contains('.jpeg') || target.toLowerCase().contains('.webp');
    final isPdf = target.toLowerCase().contains('.pdf');

    if (isImage) {
      Get.to(
        () => _buildFullScreenImage(target, name, isNetwork: isNetwork),
        routeName: '/full-screen-image',
      );
    } else if (!isNetwork && isPdf && File(target).existsSync()) {
      Printing.layoutPdf(onLayout: (_) => File(target).readAsBytesSync());
    } else if (target.isNotEmpty) {
      final uri = Uri.parse(target);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document URL.')));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not found or format not supported.')));
      }
    }
  }

  Widget _buildFullScreenImage(String pathOrUrl, String name, {bool isNetwork = false}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(name, style: const TextStyle(fontSize: 14)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Share Document',
              icon: const Icon(Icons.share_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (isNetwork) {
                  Share.share(pathOrUrl, subject: name);
                } else if (File(pathOrUrl).existsSync()) {
                  Share.shareXFiles([XFile(pathOrUrl)], text: name);
                }
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isNetwork
              ? Image.network(pathOrUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 50))
              : Image.file(File(pathOrUrl), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildSourceOption(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AvailColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AvailColors.primary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeaderActionIcon({
    required bool darkMode,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPrimary
                  ? AvailColors.primary.withValues(alpha: darkMode ? 0.2 : 0.12)
                  : (darkMode ? Colors.grey.shade800 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPrimary
                    ? AvailColors.primary.withValues(alpha: 0.35)
                    : (darkMode ? Colors.white10 : Colors.grey.shade200),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? AvailColors.primary
                  : (darkMode ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final booking = _currentBooking;

    String displayId = booking.bookingId.isNotEmpty ? booking.bookingId : booking.id;
    if (!displayId.toUpperCase().startsWith('FT')) {
      displayId = "FT-$displayId";
    }

    final initialTarget = booking.pickupLocation != null
        ? LatLng(booking.pickupLocation!.latitude, booking.pickupLocation!.longitude)
        : const LatLng(5.6037, -0.1870);

    return AppPageLayout(
      title: 'Manifest #$displayId',
      child: Scaffold(
        backgroundColor: darkMode ? AvailColors.black : const Color(0xFFF8F9FA),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isSplit = constraints.maxWidth >= 960;

            final mapStack = Stack(
              children: [
                // 1. FULL-SCREEN DYNAMIC INTERACTIVE MAP
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  mapType: _mapType,
                  trafficEnabled: _isTrafficEnabled,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  padding: EdgeInsets.only(bottom: isSplit ? 24 : 220),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    AvailMapStyles.applyThemeStyle(controller, darkMode);
                    _loadRoute();
                  },
                ),

            // 2. TOP FLOATING APP BAR OVERLAY (Mobile only; wide view uses top ShipperHeader)
            if (!isSplit)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (darkMode ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: darkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () {
                      if (Get.isRegistered<NavigationController>() &&
                          NavigationController.instance.subScreen.value != null) {
                        NavigationController.instance.closeSubScreen();
                      } else {
                        Get.back();
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: darkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'MANIFEST #$displayId',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: darkMode ? Colors.white : Colors.black87,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: _driverPos != null ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _driverPos != null ? 'Live Driver Tracking' : 'Freight Route Map',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _driverPos != null ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (booking.status == 'pending') ...[
                    _buildHeaderActionIcon(
                      darkMode: darkMode,
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit Manifest Details',
                      onPressed: () {
                        CustomerHomeController.instance.populateForEditing(booking);
                        Get.toNamed(AvailRoutes.jobDispatch);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  _buildHeaderActionIcon(
                    darkMode: darkMode,
                    icon: Icons.picture_as_pdf_outlined,
                    tooltip: 'Export Waybill PDF',
                    onPressed: () => AvailPdfHelper.generateAndShareWaybill(booking),
                  ),
                  const SizedBox(width: 6),
                  _buildHeaderActionIcon(
                    darkMode: darkMode,
                    icon: Icons.share_rounded,
                    tooltip: 'Share Manifest',
                    isPrimary: true,
                    onPressed: () => CustomerHomeController.instance.shareManifest(booking),
                  ),
                ],
              ),
            ),
          ),

          // 3. FLOATING MAP CONTROLS
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 75,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'mode_3d_details_btn',
                  onPressed: () {
                    setState(() {
                      _is3DFollowMode = !_is3DFollowMode;
                    });
                    if (_is3DFollowMode && _driverPos != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: _driverPos!,
                            zoom: 18.0,
                            tilt: 58.0,
                            bearing: _driverBearing,
                          ),
                        ),
                      );
                    } else {
                      final p = booking.pickupLocation;
                      final d = booking.dropoffLocation;
                      if (p != null && d != null) {
                        final fitPoints = [LatLng(p.latitude, p.longitude), LatLng(d.latitude, d.longitude)];
                        if (_driverPos != null) fitPoints.add(_driverPos!);
                        _fitBoundsMulti(fitPoints);
                      }
                    }
                  },
                  backgroundColor: _is3DFollowMode ? AvailColors.primary : (darkMode ? const Color(0xFF1E293B) : Colors.white),
                  foregroundColor: _is3DFollowMode ? Colors.white : AvailColors.primary,
                  child: const Icon(Iconsax.radar5, size: 18),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'recenter_details_btn',
                  onPressed: () {
                    final p = booking.pickupLocation;
                    final d = booking.dropoffLocation;
                    if (p != null && d != null) {
                      final fitPoints = [LatLng(p.latitude, p.longitude), LatLng(d.latitude, d.longitude)];
                      if (_driverPos != null) fitPoints.add(_driverPos!);
                      _fitBoundsMulti(fitPoints);
                    }
                  },
                  backgroundColor: darkMode ? const Color(0xFF1E293B) : Colors.white,
                  foregroundColor: AvailColors.primary,
                  child: const Icon(Iconsax.map, size: 18),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'traffic_details_btn',
                  onPressed: () {
                    setState(() {
                      _isTrafficEnabled = !_isTrafficEnabled;
                    });
                    AvailLoaders.customToast(
                      message: _isTrafficEnabled ? 'Live Traffic Overlay Active' : 'Traffic Overlay Disabled',
                    );
                  },
                  backgroundColor: _isTrafficEnabled ? Colors.green : (darkMode ? const Color(0xFF1E293B) : Colors.white),
                  foregroundColor: _isTrafficEnabled ? Colors.white : (darkMode ? Colors.white : Colors.black87),
                  child: const Icon(Iconsax.routing, size: 18),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'layer_details_btn',
                  onPressed: () {
                    setState(() {
                      _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
                    });
                  },
                  backgroundColor: darkMode ? const Color(0xFF1E293B) : Colors.white,
                  foregroundColor: Colors.blue,
                  child: const Icon(Iconsax.layer, size: 18),
                ),
              ],
            ),
          ),
            ],
          );

          // 4. DETAILS PANEL OR DRAGGABLE SHEET
          final List<Widget> detailsChildren = [
            // Executive Header Summary Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: darkMode
                      ? [const Color(0xFF132238), const Color(0xFF0E1A2B)]
                      : [const Color(0xFFF8FAFC), Colors.white],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: darkMode
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildClassicStatusBadge(booking.status),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: displayId));
                          AvailLoaders.customToast(
                              message: 'Manifest #$displayId copied');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: darkMode
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#$displayId',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  color: darkMode
                                      ? Colors.white
                                      : AvailColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Iconsax.copy,
                                size: 12,
                                color: AvailColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Iconsax.calendar_1,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm')
                            .format(booking.timestamp),
                        style: TextStyle(
                          color: darkMode
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AvailSizes.spaceBtwItems),

            // Live Shipment Stage Progress Bar
            _buildLiveStageProgress(booking.status),
            const SizedBox(height: AvailSizes.spaceBtwItems),

            // Online Payment Status Banner & Pay Now Action
            _buildOnlinePaymentBanner(booking, darkMode),
            const SizedBox(height: AvailSizes.spaceBtwItems),

            // Assigned Driver Contact Card (if assigned)
            if (booking.driverName != null && booking.driverName!.isNotEmpty) ...[
              _buildDriverContactCard(booking),
              const SizedBox(height: AvailSizes.spaceBtwItems),
            ],

            // Main Executive Financial & Route Telemetry Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B1D35),
                    Color(0xFF122F51),
                    Color(0xFF1A3E6B),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AvailColors.secondary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL FREIGHT RATE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white60,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Obx(
                            () => Text(
                              LocalizationController.instance
                                  .getFormattedPrice(booking.price),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AvailColors.primary.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AvailColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Iconsax.truck_fast,
                                size: 15,
                                color: AvailColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  booking.truckType.isNotEmpty
                                      ? booking.truckType.toUpperCase()
                                      : booking.cargoType.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.white12),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Iconsax.box,
                                size: 15,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CARGO CLASS',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  Text(
                                    booking.cargoType.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white12,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Iconsax.routing,
                                size: 15,
                                color: Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DISTANCE',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  Text(
                                    '${booking.distance.toStringAsFixed(1)} KM',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AvailSizes.spaceBtwSections),

            // Route Timeline Card
            _buildSectionTitle('ROUTE DETAILS'),
            const SizedBox(height: AvailSizes.spaceBtwItems),
            if (_suggestedRoutes.isNotEmpty) ...[
              _buildRouteOptionsCard(),
              const SizedBox(height: AvailSizes.spaceBtwItems),
            ],
            _buildRouteTimeline(booking.pickupAddress, booking.dropoffAddress),
            const SizedBox(height: AvailSizes.spaceBtwSections),

            // Load Information Card
            _buildSectionTitle('CARGO SPECIFICATIONS'),
            const SizedBox(height: AvailSizes.spaceBtwItems),
            _buildDetailCard([
              _buildInlineDetail('Gross Weight', '${booking.weight} Tons'),
              _buildInlineDetail('Unit Size', booking.containerSize),
              _buildInlineDetail('Load Desc.', booking.loadDescription),
              if (booking.cargoValue != null && booking.cargoValue! > 0)
                _buildInlineDetail('Declared Value', 'GHS ${booking.cargoValue!.toStringAsFixed(2)}'),
              if (booking.isFragile) _buildInlineDetail('Fragile Cargo', 'YES (Special Handling)', color: Colors.orange),
              if (booking.isInsured) _buildInlineDetail('Transit Insurance', 'ACTIVE (Full Cover)', color: Colors.green),
            ]),
            const SizedBox(height: AvailSizes.spaceBtwSections),

            // Detailed Inventory
            if (booking.inventory.isNotEmpty) ...[
              _buildSectionTitle('DETAILED INVENTORY'),
              const SizedBox(height: AvailSizes.spaceBtwItems),
              _buildDetailCard(
                booking.inventory.map((item) => _buildInlineDetail(item['name'], 'x${item['quantity']}')).toList(),
              ),
              const SizedBox(height: AvailSizes.spaceBtwSections),
            ],

            // Schedule Information
            if (booking.scheduledDate != null) ...[
              _buildSectionTitle('DISPATCH SCHEDULE'),
              const SizedBox(height: AvailSizes.spaceBtwItems),
              _buildDetailCard([
                _buildInlineDetail('Pickup Date', DateFormat('EEEE, MMM dd, yyyy').format(booking.scheduledDate!)),
                _buildInlineDetail('Target Time', DateFormat('HH:mm a').format(booking.scheduledDate!)),
              ]),
              const SizedBox(height: AvailSizes.spaceBtwSections),
            ],

            // Documentation Gallery Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('MANIFEST ATTACHMENTS'),
                if (_localDocuments.isNotEmpty)
                  Text('${_localDocuments.length} files attached', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AvailSizes.spaceBtwItems),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _localDocuments.length + 1,
                itemBuilder: (context, index) {
                  if (index == _localDocuments.length) {
                    return _isSaving
                        ? const SizedBox(width: 120, child: Center(child: CircularProgressIndicator()))
                        : GestureDetector(
                            onTap: _addMoreDocuments,
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: darkMode ? const Color(0xFF132238) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(0xFFE3F2FD),
                                    child: Icon(Iconsax.add, color: Colors.blue, size: 20),
                                  ),
                                  SizedBox(height: 10),
                                  Text('ATTACH NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue)),
                                ],
                              ),
                            ),
                          );
                  }

                  final doc = _localDocuments[index];
                  final name = doc['name'] ?? 'Untitled';
                  final path = doc['path'] ?? '';
                  final url = doc['url'] ?? '';
                  final target = url.isNotEmpty ? url : path;
                  final isNetwork = target.startsWith('http');
                  final isImage = target.toLowerCase().contains('.jpg') || target.toLowerCase().contains('.png') || target.toLowerCase().contains('.jpeg') || target.toLowerCase().contains('.webp');
                  final isPdf = target.toLowerCase().contains('.pdf');

                  return GestureDetector(
                    onTap: () => _viewDocument(doc),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 15, bottom: 10),
                      decoration: BoxDecoration(
                        color: darkMode ? const Color(0xFF132238) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                        border: Border.all(
                          color: darkMode ? const Color(0xFF1E3A5F) : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                  child: isImage
                                      ? (isNetwork
                                          ? Image.network(target, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Iconsax.image, size: 28)))
                                          : (File(target).existsSync()
                                              ? Image.file(File(target), fit: BoxFit.cover, width: double.infinity)
                                              : Container(color: Colors.grey.shade200, child: const Icon(Iconsax.document_text, size: 28))))
                                      : Container(
                                          width: double.infinity,
                                          color: isPdf ? Colors.red.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.08),
                                          child: Icon(
                                            isPdf ? Iconsax.document_text5 : Iconsax.document_text,
                                            color: isPdf ? Colors.red : Colors.blue,
                                            size: 28,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _localDocuments.removeAt(index);
                                        _saveDocumentsToFirebase();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 10, color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              name.isEmpty ? 'Manifest File' : name,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AvailSizes.spaceBtwSections),

            // Logistics Contacts
            _buildSectionTitle('LOGISTICS CONTACTS'),
            const SizedBox(height: AvailSizes.spaceBtwItems),
            Row(
              children: [
                Expanded(child: _buildContactCard('SENDER', booking.senderName, booking.senderPhone)),
                const SizedBox(width: 12),
                Expanded(child: _buildContactCard('RECEIVER', booking.receiverName, booking.receiverPhone)),
              ],
            ),
            const SizedBox(height: AvailSizes.spaceBtwSections),

            // Proof of Delivery or Operational Support
            if (booking.status == 'delivered') ...[
              _buildSectionTitle('PROOF OF DELIVERY (POD)'),
              const SizedBox(height: AvailSizes.spaceBtwItems),
              _buildDetailCard([
                _buildInlineDetail('Received By', booking.receiverName),
                _buildInlineDetail('Delivery Note', 'Cargo verified and accepted'),
                const SizedBox(height: 10),
                Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Text('DIGITAL SIGNATURE SECURED & VERIFIED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                ),
              ]),
            ] else ...[
              _buildSectionTitle('OPERATIONAL SUPPORT'),
              const SizedBox(height: AvailSizes.spaceBtwItems),
              OutlinedButton.icon(
                onPressed: () => _showOperationalSupportSheet(context, booking),
                icon: const Icon(Iconsax.message_question),
                label: const Text('Support, Dispute & Emergency SOS'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
            if (booking.status == 'delivered') ...[
              const SizedBox(height: AvailSizes.spaceBtwItems),
              OutlinedButton.icon(
                onPressed: () => _showOperationalSupportSheet(context, booking),
                icon: const Icon(Iconsax.support),
                label: const Text('Need Help or Dispute This Delivery?'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
            const SizedBox(height: AvailSizes.spaceBtwSections),
          ];

          if (isSplit) {
            return Row(
              children: [
                Expanded(child: mapStack),
                Container(
                  width: constraints.maxWidth >= 1250 ? 470 : 410,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: darkMode ? AvailColors.dark : const Color(0xFFF8FAFC),
                    border: Border(
                      left: BorderSide(
                        color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: detailsChildren,
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              mapStack,
              DraggableScrollableSheet(
                initialChildSize: 0.44,
                minChildSize: 0.20,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: darkMode ? AvailColors.dark : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        AvailSizes.defaultSpace,
                        12,
                        AvailSizes.defaultSpace,
                        MediaQuery.of(context).viewPadding.bottom + 24,
                      ),
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        ...detailsChildren,
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildLiveStageProgress(String status) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final stages = ['pending', 'confirmed', 'onTheWayToPickup', 'inTransit', 'delivered'];
    final labels = ['Pending', 'Confirmed', 'En Route', 'In Transit', 'Delivered'];
    final icons = [
      Iconsax.clock,
      Iconsax.tick_circle,
      Iconsax.routing_2,
      Iconsax.truck_fast,
      Iconsax.verify5,
    ];

    int currentIdx = stages.indexOf(status);
    if (status == 'pickedUp') currentIdx = 3;
    if (currentIdx == -1) currentIdx = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AvailColors.primary.withValues(alpha: darkMode ? 0.18 : 0.10),
            AvailColors.primary.withValues(alpha: darkMode ? 0.06 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AvailColors.primary.withValues(alpha: darkMode ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AvailColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE SHIPMENT TELEMETRY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      color: darkMode ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                _getStageLabel(status),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AvailColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(stages.length, (i) {
              final isPassed = i < currentIdx;
              final isCurrent = i == currentIdx;
              final Color nodeColor = isPassed
                  ? const Color(0xFF10B981)
                  : (isCurrent
                      ? AvailColors.primary
                      : (darkMode
                          ? const Color(0xFF1E3A5F)
                          : Colors.grey.shade300));
              final Color completedLine = const Color(0xFF10B981);
              final Color inactiveLine = darkMode
                  ? const Color(0xFF1E3A5F)
                  : Colors.grey.shade300;

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? Colors.transparent
                                    : (i <= currentIdx
                                        ? completedLine
                                        : inactiveLine),
                                borderRadius: i == 1
                                    ? const BorderRadius.horizontal(
                                        left: Radius.circular(2))
                                    : BorderRadius.zero,
                              ),
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: nodeColor,
                              shape: BoxShape.circle,
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: AvailColors.primary
                                            .withValues(alpha: 0.45),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              isPassed ? Icons.check_rounded : icons[i],
                              size: 12,
                              color: isPassed || isCurrent
                                  ? Colors.white
                                  : Colors.grey.shade500,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: i == stages.length - 1
                                    ? Colors.transparent
                                    : (i < currentIdx
                                        ? completedLine
                                        : inactiveLine),
                                borderRadius: i == stages.length - 2
                                    ? const BorderRadius.horizontal(
                                        right: Radius.circular(2))
                                    : BorderRadius.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 26,
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1.15,
                          fontWeight:
                              isCurrent ? FontWeight.w900 : (isPassed ? FontWeight.w700 : FontWeight.w500),
                          color: isCurrent
                              ? AvailColors.primary
                              : (isPassed
                                  ? (darkMode ? Colors.white70 : const Color(0xFF1E293B))
                                  : Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledRefundBanner(
    BookingModel booking,
    bool darkMode,
    String formattedAmount,
    String formattedGhs,
  ) {
    final bool isRefunded = booking.isRefunded;
    final bool isProcessing = booking.isRefundProcessing;
    final bool isRequested = booking.isRefundRequested;
    final bool isFailed = booking.isRefundFailed;

    final Color accent = isRefunded
        ? Colors.teal
        : isProcessing
            ? Colors.indigo
            : isFailed
                ? Colors.red
                : Colors.orange;

    final String headline = isRefunded
        ? 'REFUND COMPLETED ($formattedGhs)'
        : isProcessing
            ? 'REFUND PROCESSING VIA PAYSTACK'
            : isRequested
                ? 'REFUND REQUESTED — UNDER ADMIN REVIEW'
                : isFailed
                    ? 'REFUND FAILED — ACTION NEEDED'
                    : 'CANCELLED PAID BOOKING — REFUND ELIGIBLE';

    final String subtitle = isRefunded
        ? 'Your online payment ($formattedAmount / $formattedGhs) has been refunded via ${booking.refundMethod ?? 'Paystack'}${booking.refundReference != null ? ' (Ref: ${booking.refundReference})' : ''}.'
        : isProcessing
            ? 'Paystack is processing your refund of $formattedGhs. You will be notified as soon as settlement completes.'
            : isRequested
                ? 'Your refund request for $formattedAmount ($formattedGhs) has been submitted to Admin for Paystack verification & release.'
                : isFailed
                    ? 'Previous refund attempt failed${(booking.refundFailureReason ?? '').isNotEmpty ? ': ${booking.refundFailureReason}' : ''}. Update your refund wallet or re-submit.'
                    : 'This cancelled booking was paid online ($formattedAmount / $formattedGhs). Tap below to submit your refund request.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: darkMode ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRefunded
                      ? Iconsax.tick_circle5
                      : isFailed
                          ? Iconsax.warning_2
                          : Iconsax.money_recive,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: darkMode ? Colors.white70 : Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isRefunded && !isProcessing && !isRequested) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => CancelRefundDialog.show(context, booking),
                icon: const Icon(Iconsax.money_recive, size: 17, color: Colors.white),
                label: Text(
                  isFailed ? 'UPDATE WALLET & RETRY REFUND' : 'REQUEST REFUND ($formattedGhs)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlinePaymentBanner(BookingModel booking, bool darkMode) {
    final normalizedStatus = booking.status.toLowerCase().trim();
    final tripPayCtrl = TripPaymentController.instance;
    final locCtrl = LocalizationController.instance;
    final formattedAmount = locCtrl.getFormattedPrice(booking.price);
    final ghsAmount = booking.paidAmountGhs ?? tripPayCtrl.getNormalizedGHSAmount(booking.price);
    final formattedGhs = 'GH¢ ${NumberFormat('#,##0.00', 'en_US').format(ghsAmount)}';

    if (normalizedStatus == 'cancelled' || normalizedStatus == 'canceled') {
      if (!booking.isPaidOnline) return const SizedBox.shrink();
      return _buildCancelledRefundBanner(booking, darkMode, formattedAmount, formattedGhs);
    }

    if (booking.isPaidOnline) {
      final ref = booking.paymentReference ?? '';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: darkMode ? 0.22 : 0.12),
              Colors.teal.withValues(alpha: darkMode ? 0.16 : 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.verify5, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PAID ONLINE VIA PAYSTACK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Full trip fee ($formattedAmount) verified. Driver & Admin have been notified — no cash needed on delivery.',
                        style: TextStyle(
                          fontSize: 11,
                          color: darkMode ? Colors.white70 : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (ref.isNotEmpty || (booking.paymentNetwork ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: darkMode ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ref.isNotEmpty)
                            Text(
                              'Ref: $ref',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if ((booking.paymentNetwork ?? '').isNotEmpty)
                            Text(
                              'Channel: ${booking.paymentNetwork}${(booking.paymentChannel ?? '').isNotEmpty ? ' (${booking.paymentChannel})' : ''}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    if (ref.isNotEmpty)
                      IconButton(
                        icon: const Icon(Iconsax.copy, size: 16, color: Colors.green),
                        tooltip: 'Copy Reference',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: ref));
                          AvailLoaders.customToast(message: 'Payment reference copied');
                        },
                      ),
                  ],
                ),
              ),
            ],
            if (booking.lastDriverCancelledAt != null && booking.canShipperCancelDirectly) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: darkMode ? 0.18 : 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.info_circle, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Previous Driver Released Trip — Payment Protected',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: darkMode ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your online payment is safe. You can wait for another nearby driver or cancel and request a full refund.',
                      style: TextStyle(fontSize: 11, color: darkMode ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => CancelRefundDialog.show(context, booking),
                        icon: const Icon(Iconsax.money_recive, size: 15, color: Colors.red),
                        label: const Text(
                          'Cancel Booking & Request Full Refund',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final bool isLoaded = booking.isLoadedOnTruckOrInTransit;
    final Color accent = isLoaded ? const Color(0xFFD97706) : AvailColors.primary;

    return Obx(() {
      final hasPendingRef = tripPayCtrl.pendingBookingId.value == booking.id &&
          tripPayCtrl.pendingReference.value.isNotEmpty;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoaded
                ? [
                    const Color(0xFFF59E0B).withValues(alpha: darkMode ? 0.24 : 0.14),
                    const Color(0xFFEA580C).withValues(alpha: darkMode ? 0.16 : 0.08),
                  ]
                : [
                    AvailColors.primary.withValues(alpha: darkMode ? 0.20 : 0.09),
                    Colors.blue.withValues(alpha: darkMode ? 0.12 : 0.05),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: isLoaded ? 0.65 : 0.35),
            width: isLoaded ? 1.6 : 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLoaded ? Iconsax.card_pos5 : Iconsax.shield_tick5,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoaded
                            ? 'CARGO LOADED — PAYMENT REQUIRED ONLINE'
                            : 'PAY TRIP FEE ONLINE VIA PAYSTACK',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isLoaded
                            ? 'Your cargo is loaded on the truck. Pay $formattedAmount ($formattedGhs) securely online now so Admin & Driver see instant confirmation.'
                            : 'Pay $formattedAmount ($formattedGhs) securely online anytime via Mobile Money or Card.',
                        style: TextStyle(
                          fontSize: 11,
                          color: darkMode ? Colors.white70 : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => TripPaymentAlertService.instance.openManualPaymentSheet(booking),
                    icon: const Icon(Iconsax.card, size: 17, color: Colors.white),
                    label: Text(
                      isLoaded ? 'PAY $formattedAmount NOW' : 'PAY ONLINE ($formattedAmount)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (hasPendingRef) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => tripPayCtrl.manualVerifyPayment(),
                    icon: Icon(Iconsax.refresh, size: 15, color: accent),
                    label: Text(
                      'Verify',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: accent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    });
  }

  String _getStageLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Driver Assigned';
      case 'onTheWayToPickup': return 'Driver Approaching Pickup';
      case 'pickedUp':
      case 'inTransit': return 'Cargo Loaded on Truck • In Transit';
      case 'delivered': return 'Delivered Successfully';
      case 'cancelled': return 'Manifest Cancelled';
      default: return 'Waiting for Driver';
    }
  }

  Widget _buildClassicStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'confirmed') color = Colors.blue;
    if (status == 'inTransit' || status == 'pickedUp') color = Colors.indigo;
    if (status == 'delivered') color = Colors.green;
    if (status == 'cancelled') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildRouteOptionsCard() {
    if (_suggestedRoutes.isEmpty) return const SizedBox.shrink();
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final safeIdx = _selectedRouteIndex.clamp(0, _suggestedRoutes.length - 1);
    final activeRoute = _suggestedRoutes[safeIdx];
    final trafficColor = activeRoute.trafficStatusColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkMode ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: trafficColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: trafficColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activeRoute.trafficStatus,
                    style: TextStyle(
                      color: trafficColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                'Route Options (${_suggestedRoutes.length})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: darkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_suggestedRoutes.length, (i) {
                final route = _suggestedRoutes[i];
                final isSelected = (i == safeIdx);
                final subText = isSelected
                    ? (i == 0 ? 'Fastest' : 'Active')
                    : (route.relativeDistanceText.isNotEmpty
                        ? route.relativeDistanceText
                        : '+${(route.trafficDelaySeconds / 60).round()}m');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedRouteIndex = i;
                      });
                      _renderPolylinesAndBadges();
                    },
                    avatar: CircleAvatar(
                      radius: 4.5,
                      backgroundColor: isSelected ? Colors.white : route.trafficStatusColor,
                    ),
                    label: Text(
                      '${route.durationInTrafficText} • $subText',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (darkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                    selectedColor: const Color(0xFF0F172A),
                    backgroundColor: darkMode ? const Color(0xFF0F172A).withValues(alpha: 0.5) : Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? route.trafficStatusColor
                          : (darkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline(String pickup, String dropoff) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTimelineItem(
            address: pickup,
            type: 'ORIGIN • PICKUP',
            emblem: 'A',
            gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
            tagColor: const Color(0xFF10B981),
            tagBgColor: const Color(0xFF10B981).withValues(alpha: 0.14),
            isLast: false,
            darkMode: darkMode,
          ),
          ..._currentBooking.stops.asMap().entries.map((entry) {
            final idx = entry.key;
            final stop = entry.value;
            return _buildTimelineItem(
              address: stop['address'] ?? '',
              type: 'STOP ${idx + 1}',
              emblem: '${idx + 1}',
              gradientColors: const [Color(0xFFF59E0B), Color(0xFFB45309)],
              tagColor: const Color(0xFFF59E0B),
              tagBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.14),
              isLast: false,
              darkMode: darkMode,
            );
          }),
          _buildTimelineItem(
            address: dropoff,
            type: 'DESTINATION • DROPOFF',
            emblem: 'B',
            gradientColors: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
            tagColor: const Color(0xFFEF4444),
            tagBgColor: const Color(0xFFEF4444).withValues(alpha: 0.14),
            isLast: true,
            darkMode: darkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String address,
    required String type,
    required String emblem,
    required List<Color> gradientColors,
    required Color tagColor,
    required Color tagBgColor,
    required bool isLast,
    required bool darkMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  emblem,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradientColors.first,
                      darkMode ? const Color(0xFF334155) : Colors.grey.shade300,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: tagColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: darkMode ? Colors.white : AvailColors.textPrimary,
                ),
              ),
              if (!isLast) const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: AvailColors.lineargradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: darkMode ? Colors.grey.shade300 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInlineDetail(String label, String value, {Color? color}) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: darkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color ??
                    (darkMode ? Colors.white : AvailColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(String title, String name, String phone) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final isSender = title.toUpperCase().contains('SENDER');
    final accent = isSender ? const Color(0xFF10B981) : const Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (phone.trim().isNotEmpty)
                GestureDetector(
                  onTap: () => CustomerHomeController.instance.callDriver(phone),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.call5, size: 13, color: accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name.isNotEmpty ? name : 'Not Specified',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: darkMode ? Colors.white : AvailColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            phone.isNotEmpty ? phone : 'No phone provided',
            style: const TextStyle(
              fontSize: 11,
              color: AvailColors.primary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverContactCard(BookingModel job) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [const Color(0xFF132238), const Color(0xFF0E1A2B)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          DriverProfileAvatar(
            driverImage: job.driverImage,
            driverId: job.driverId,
            radius: 22,
            showGradientBorder: true,
            borderGradient: AvailColors.lineargradient,
            borderWidth: 2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ASSIGNED FLEET OPERATOR',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.driverName!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: darkMode ? Colors.white : AvailColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${job.vehiclePlate ?? "Fleet Unit"} • ${job.vehicleModel ?? job.truckType}',
                  style: TextStyle(
                    color: darkMode
                        ? Colors.grey.shade400
                        : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (job.canChatWithDriver) ...[
            IconButton(
              onPressed: () {
                CustomerHomeController.instance.showJobOnMap(job);
                Get.back();
              },
              icon: const Icon(Iconsax.radar5,
                  color: AvailColors.primary, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AvailColors.primary.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              tooltip: 'Track Live on Home Map',
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => Get.to(() => TripChatScreen(booking: job)),
                  icon: const Icon(Iconsax.messages_2,
                      color: Colors.white, size: 19),
                  style: IconButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  tooltip: 'In-App Trip Chat with Driver',
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: ShipperUnreadChatBadge(booking: job, compact: true),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () =>
                  CustomerHomeController.instance.callDriver(job.driverPhone),
              icon: const Icon(Iconsax.call5, color: Colors.white, size: 19),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              tooltip: 'Call Driver',
            ),
          ] else
            InkWell(
              onTap: () => Get.to(() => TripChatScreen(booking: job)),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (darkMode ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (darkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.lock,
                      size: 14,
                      color: darkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: darkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOperationalSupportSheet(BuildContext context, BookingModel booking) {
    final supportRepo = SupportConfigRepository.instance;
    final dark = AvailHelperFunctions.isDarkMode(context);
    final manifestRef = booking.bookingId.isNotEmpty ? booking.bookingId : booking.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (ctx) => Obx(() {
        final cfg = supportRepo.supportConfig.value;
        return Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0E1A2B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Executive Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: AvailColors.lineargradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AvailColors.primary.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Iconsax.support,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispatch Support & Dispute Desk',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16.5,
                                color: dark ? Colors.white : AvailColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    cfg.supportHours.isNotEmpty
                                        ? cfg.supportHours
                                        : '24/7 Dispatch & Customer Care',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: dark
                                          ? Colors.grey.shade400
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF1F5F9),
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: dark ? Colors.grey.shade300 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Manifest Context & Copy Reference Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF132238) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.document_text,
                          size: 16,
                          color: dark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MANIFEST REF:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: dark ? Colors.grey.shade400 : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '#$manifestRef',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: dark ? Colors.white : AvailColors.textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: manifestRef));
                            AvailLoaders.customToast(
                              message: 'Manifest #$manifestRef copied',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AvailColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Iconsax.copy,
                                  size: 12,
                                  color: AvailColors.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'COPY ID',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AvailColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dispute Policy / Guidance Banner
                  if (cfg.disputeNotice.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AvailColors.primary.withValues(alpha: dark ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AvailColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Iconsax.shield_tick,
                              size: 17,
                              color: AvailColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cfg.disputeNotice,
                              style: TextStyle(
                                fontSize: 11.8,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                color: dark ? Colors.grey.shade200 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Text(
                    'DIRECT ASSISTANCE CHANNELS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: dark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 1. Call Dispatch Support
                  _buildSupportChannelCard(
                    dark: dark,
                    icon: Iconsax.call_calling,
                    accentColor: const Color(0xFF10B981),
                    badgeText: 'VOICE DESK',
                    title: 'Call Dispatch & Dispute Support',
                    subtitle: '${cfg.supportPhone} • Fare, demurrage & cargo resolution',
                    onTap: () {
                      Navigator.pop(ctx);
                      supportRepo.callSupport();
                    },
                  ),
                  const SizedBox(height: 10),

                  // 2. Email Support & Dispute Team
                  _buildSupportChannelCard(
                    dark: dark,
                    icon: Iconsax.sms_tracking,
                    accentColor: AvailColors.primary,
                    badgeText: 'EMAIL DESK',
                    title: 'Submit Written Dispute / Inquiry',
                    subtitle: '${cfg.supportEmail} • Pre-filled with Manifest #$manifestRef',
                    onTap: () {
                      Navigator.pop(ctx);
                      supportRepo.emailSupport(
                        subject: 'Freight Support / Dispute - Booking #$manifestRef',
                        body:
                            'Booking ID: #$manifestRef\nStatus: ${booking.status}\nRoute: ${booking.pickupAddress} -> ${booking.dropoffAddress}\n\nPlease describe your issue:\n',
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // 3. Emergency SOS Line
                  _buildSupportChannelCard(
                    dark: dark,
                    icon: Iconsax.warning_2,
                    accentColor: const Color(0xFFEF4444),
                    badgeText: 'SOS HOTLINE',
                    title: 'Emergency & Roadside Response',
                    subtitle: 'Dial ${cfg.emergencyNumber} • Immediate safety or incident escalation',
                    isEmergency: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      supportRepo.callEmergency();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSupportChannelCard({
    required bool dark,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEmergency = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isEmergency
                ? accentColor.withValues(alpha: dark ? 0.12 : 0.05)
                : (dark ? const Color(0xFF132238) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEmergency
                  ? accentColor.withValues(alpha: 0.4)
                  : (dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.18 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: dark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : AvailColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: dark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isEmergency
                      ? accentColor
                      : (dark ? Colors.grey.shade400 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
