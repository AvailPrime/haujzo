import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/image_strings.dart';
import '../shimmer/shimmer.dart';

/// Renders the assigned driver's verified profile picture with an in-memory
/// cache and Firestore fallback resolution for older bookings.
class DriverProfileAvatar extends StatelessWidget {
  const DriverProfileAvatar({
    super.key,
    this.driverImage,
    this.driverId,
    this.radius = 22,
    this.borderGradient,
    this.borderWidth = 2,
    this.showGradientBorder = false,
    this.borderColor,
    this.backgroundColor,
    this.fallbackWidget,
  });

  final String? driverImage;
  final String? driverId;
  final double radius;
  final Gradient? borderGradient;
  final double borderWidth;
  final bool showGradientBorder;
  final Color? borderColor;
  final Color? backgroundColor;
  final Widget? fallbackWidget;

  /// Global static cache mapping driverId -> profile photo URL
  static final Map<String, String> _driverPhotoCache = {};

  /// Asynchronously resolves driver's profile picture from Firestore if not on the booking doc
  static Future<String?> resolveDriverImage(String? driverId) async {
    final cleanId = (driverId ?? '').trim();
    if (cleanId.isEmpty) return null;
    if (_driverPhotoCache.containsKey(cleanId)) {
      return _driverPhotoCache[cleanId];
    }

    try {
      final userSnap = await FirebaseFirestore.instance.collection('Users').doc(cleanId).get();
      final userData = userSnap.data();
      final userPic = (userData?['profilePicture'] ??
              userData?['ProfilePicture'] ??
              userData?['profile_picture'] ??
              userData?['photoURL'])
          ?.toString()
          ?.trim();

      if (userPic != null && userPic.isNotEmpty && userPic.startsWith('http')) {
        _driverPhotoCache[cleanId] = userPic;
        return userPic;
      }

      final driverSnap = await FirebaseFirestore.instance.collection('drivers').doc(cleanId).get();
      final driverData = driverSnap.data();
      final driverPic = (driverData?['profilePicture'] ??
              driverData?['ProfilePicture'] ??
              driverData?['profile_picture'] ??
              driverData?['photoURL'])
          ?.toString()
          ?.trim();

      if (driverPic != null && driverPic.isNotEmpty && driverPic.startsWith('http')) {
        _driverPhotoCache[cleanId] = driverPic;
        return driverPic;
      }

      final pubSnap = await FirebaseFirestore.instance.collection('drivers_public').doc(cleanId).get();
      final pubData = pubSnap.data();
      final pubPic = (pubData?['profilePicture'] ??
              pubData?['ProfilePicture'] ??
              pubData?['driverImage'])
          ?.toString()
          ?.trim();

      if (pubPic != null && pubPic.isNotEmpty && pubPic.startsWith('http')) {
        _driverPhotoCache[cleanId] = pubPic;
        return pubPic;
      }

      _driverPhotoCache[cleanId] = '';
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final directUrl = (driverImage ?? '').trim();
    Widget avatarWidget;

    if (directUrl.isNotEmpty && directUrl.startsWith('http')) {
      avatarWidget = _buildNetworkImage(directUrl);
    } else {
      final cleanId = (driverId ?? '').trim();
      if (cleanId.isNotEmpty && _driverPhotoCache.containsKey(cleanId) && _driverPhotoCache[cleanId]!.isNotEmpty) {
        avatarWidget = _buildNetworkImage(_driverPhotoCache[cleanId]!);
      } else if (cleanId.isNotEmpty) {
        avatarWidget = FutureBuilder<String?>(
          future: resolveDriverImage(cleanId),
          builder: (context, snapshot) {
            final fetched = snapshot.data;
            if (fetched != null && fetched.isNotEmpty && fetched.startsWith('http')) {
              return _buildNetworkImage(fetched);
            }
            return _buildFallback();
          },
        );
      } else {
        avatarWidget = _buildFallback();
      }
    }

    if (showGradientBorder) {
      final effectiveGradient = borderGradient ?? AvailColors.lineargradient;
      return Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: effectiveGradient,
        ),
        child: avatarWidget,
      );
    }

    if (borderColor != null) {
      return Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildNetworkImage(String url) {
    final diameter = radius * 2;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: diameter,
          height: diameter,
          color: backgroundColor ?? Colors.grey.shade200,
          child: AvailShimmerEffect(
            width: diameter,
            height: diameter,
            radius: radius,
          ),
        ),
        errorWidget: (context, _, __) => _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;
    final diameter = radius * 2;
    return ClipOval(
      child: Container(
        width: diameter,
        height: diameter,
        color: backgroundColor ?? Colors.grey.shade200,
        child: Image.asset(
          AvailImages.user,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
