import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/popups/full_screen_loader.dart';
import '../../../../commons/widgets/loader/loaders.dart';

import '../../../../utils/constants/enums.dart';
import '../../models/booking_model.dart';
import '../../../../data/services/routing/smart_routing_engine.dart';
import '../../../../utils/constants/map_styles.dart';

class DriverDashboardController extends GetxController {
  static DriverDashboardController get instance => Get.find();

  // Observables
  final RxBool isOnline = false.obs;
  final Rx<LatLng?> currentPosition = Rx<LatLng?>(null);
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxList<BookingModel> availableBookings = <BookingModel>[].obs;
  final RxList<BookingModel> activeTasks = <BookingModel>[].obs;
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  
  // Google Maps Controller
  GoogleMapController? mapController;
  StreamSubscription<Position>? positionStream;
  StreamSubscription<QuerySnapshot>? bookingsSubscription;

  @override
  void onInit() {
    super.onInit();
    checkLocationPermission();
  }

  @override
  void onClose() {
    positionStream?.cancel();
    bookingsSubscription?.cancel();
    super.onClose();
  }

  /// Check and Request Location Permission
  Future<void> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AvailLoaders.warningSnackBar(title: 'Location Disabled', message: 'Please enable location services.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AvailLoaders.errorSnackBar(title: 'Permission Denied', message: 'Location permission is required for the driver app.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AvailLoaders.errorSnackBar(title: 'Permission Denied', message: 'Location permissions are permanently denied. Please enable them in settings.');
      return;
    }

    // Get Initial Position
    Position position = await Geolocator.getCurrentPosition();
    currentPosition.value = LatLng(position.latitude, position.longitude);
    
    // Update Map
    updateDriverMarker(position);
  }

  /// Toggle Online/Offline Status
  Future<void> toggleOnlineStatus() async {
    try {
      isOnline.value = !isOnline.value;

      if (isOnline.value) {
        startLocationUpdates();
        fetchAvailableBookings();
        AvailLoaders.successSnackBar(title: 'You are Online', message: 'Ready to receive delivery tasks.');
      } else {
        stopLocationUpdates();
        stopFetchingBookings();
        AvailLoaders.customToast(message: 'You are now Offline');
      }

      // Update Firestore Status
      final userId = AuthenticationRepository.instance.authUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('Users').doc(userId).update({
          'status': isOnline.value ? 'online' : 'offline',
        });
      }
    } catch (e) {
      isOnline.value = !isOnline.value; // Revert on error
      AvailLoaders.errorSnackBar(title: 'Status Update Failed', message: e.toString());
    }
  }

  /// Fetch Bookings that are not yet assigned to any driver
  void fetchAvailableBookings() {
    bookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: BookingStatus.pending.toString())
        .where('driverId', isEqualTo: '')
        .snapshots()
        .listen((snapshot) {
      availableBookings.value = snapshot.docs.map((doc) => BookingModel.fromSnapshot(doc)).toList();
      updateMarkersWithBookings();
    });
  }

  void stopFetchingBookings() {
    bookingsSubscription?.cancel();
    availableBookings.clear();
    updateMarkersWithBookings();
  }

  /// Accept a Delivery Task
  Future<void> acceptBooking(BookingModel booking) async {
    try {
      AvailFullScreenLoader.openDialog('Accepting Booking...');
      
      final userId = AuthenticationRepository.instance.authUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('bookings').doc(booking.bookingId).update({
        'status': BookingStatus.confirmed.toString(),
        'driverId': userId,
      });

      AvailFullScreenLoader.stopLoading();
      AvailLoaders.successSnackBar(title: 'Booking Accepted', message: 'The booking has been added to your tasks.');
      
    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    }
  }

  void updateMarkersWithBookings() {
    // Keep driver marker
    final driverMarker = markers.firstWhere((m) => m.markerId.value == 'driver_marker', orElse: () => markers.first);
    markers.clear();
    markers.add(driverMarker);

    // Add markers for available bookings
    for (var booking in availableBookings) {
      if (booking.pickupLocation != null) {
        markers.add(
          Marker(
            markerId: MarkerId(booking.bookingId),
            position: LatLng(booking.pickupLocation!.latitude, booking.pickupLocation!.longitude),
            infoWindow: InfoWindow(title: 'Pickup: ${booking.pickupAddress}', snippet: '${booking.weight}kg - ${booking.truckType}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            onTap: () => drawRouteForBooking(booking),
          ),
        );
      }
    }
  }

  Future<void> drawRouteForBooking(BookingModel booking) async {
    if (booking.pickupLocation == null || booking.dropoffLocation == null) return;

    final pickup = LatLng(booking.pickupLocation!.latitude, booking.pickupLocation!.longitude);
    final dropoff = LatLng(booking.dropoffLocation!.latitude, booking.dropoffLocation!.longitude);

    final route = await SmartRoutingEngine.instance.getRoute(
      origin: pickup,
      destination: dropoff,
    );

    polylines.assignAll(
      SmartRoutingEngine.instance.buildMultiLayeredPolylines(
        baseId: booking.bookingId,
        points: route.points,
        source: route.source,
        trafficSegments: route.trafficSegments,
        primaryColor: const Color(0xFF00E5FF),
        coreWidth: 3.8,
      ),
    );

    markers.add(Marker(
      markerId: MarkerId('${booking.bookingId}_dropoff'),
      position: dropoff,
      infoWindow: InfoWindow(title: 'Dropoff: ${booking.dropoffAddress}'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // Focus camera on the route
    final bounds = route.bounds ?? (pickup.latitude > dropoff.latitude
        ? LatLngBounds(southwest: dropoff, northeast: pickup)
        : LatLngBounds(southwest: pickup, northeast: dropoff));
    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  /// Start Real-time Location Updates
  void startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      currentPosition.value = LatLng(position.latitude, position.longitude);
      
      // Update Firestore
      updateLocationInFirebase(position);
      
      // Update Marker
      updateDriverMarker(position);

      // Move Camera if map is initialized and not focused on a route
      if (polylines.isEmpty) {
        mapController?.animateCamera(CameraUpdate.newLatLng(currentPosition.value!));
      }
    });
  }

  /// Stop Location Updates
  void stopLocationUpdates() {
    positionStream?.cancel();
  }

  /// Sync Location to Firebase
  Future<void> updateLocationInFirebase(Position position) async {
    final userId = AuthenticationRepository.instance.authUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Update Driver Marker on Map
  void updateDriverMarker(Position position) {
    final driverMarker = Marker(
      markerId: const MarkerId('driver_marker'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: const InfoWindow(title: 'You are here'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    markers.add(driverMarker);
  }
  
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    AvailMapStyles.applyThemeStyle(controller, Get.isDarkMode);
    if (currentPosition.value != null) {
      mapController?.animateCamera(CameraUpdate.newLatLng(currentPosition.value!));
    }
  }
}
