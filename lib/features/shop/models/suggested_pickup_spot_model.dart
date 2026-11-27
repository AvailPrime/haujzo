import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';

/// Represents an Uber-style designated curb access point or freight hotspot
class SuggestedPickupSpotModel {
  final String id;
  final String title;
  final String subtitle;
  final LatLng location;
  final String badge;
  final int distanceMeters;
  final IconData icon;

  const SuggestedPickupSpotModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.badge,
    required this.distanceMeters,
    this.icon = Iconsax.location,
  });
}
