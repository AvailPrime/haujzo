import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/personalization/models/support_config_model.dart';

class SupportConfigRepository extends GetxController {
  static SupportConfigRepository get instance =>
      Get.isRegistered<SupportConfigRepository>()
          ? Get.find<SupportConfigRepository>()
          : Get.put(SupportConfigRepository(), permanent: true);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Rx<SupportConfigModel> supportConfig = SupportConfigModel.defaults().obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listenToSupportConfig();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _listenToSupportConfig() {
    try {
      _sub = _db
          .collection('app_settings')
          .doc('support_config')
          .snapshots()
          .listen(
        (doc) {
          if (doc.exists && doc.data() != null) {
            supportConfig.value = SupportConfigModel.fromJson(doc.data()!);
          }
        },
        onError: (e) {
          if (kDebugMode) {
            debugPrint('SupportConfigRepository stream error: $e');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportConfigRepository init error: $e');
      }
    }
  }

  Future<SupportConfigModel> fetchSupportConfig() async {
    try {
      final doc = await _db.collection('app_settings').doc('support_config').get();
      if (doc.exists && doc.data() != null) {
        final model = SupportConfigModel.fromJson(doc.data()!);
        supportConfig.value = model;
        return model;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportConfigRepository fetch error: $e');
      }
    }
    return supportConfig.value;
  }

  String _cleanDialNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    return cleaned.isNotEmpty ? cleaned : raw.trim();
  }

  Future<void> callSupport() async {
    final phoneDisplay = supportConfig.value.supportPhone;
    final phoneUri = Uri(scheme: 'tel', path: _cleanDialNumber(phoneDisplay));
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        Get.snackbar('Support Hotline', phoneDisplay, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Support Hotline', phoneDisplay, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> callEmergency() async {
    final emergencyDisplay = supportConfig.value.emergencyNumber;
    final phoneUri = Uri(scheme: 'tel', path: _cleanDialNumber(emergencyDisplay));
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        Get.snackbar('Emergency Number', emergencyDisplay, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Emergency Number', emergencyDisplay, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> emailSupport({
    String subject = 'Haujzo Shipper Support Request',
    String? body,
  }) async {
    final email = supportConfig.value.supportEmail;
    final queryParams = <String, String>{'subject': subject};
    if (body != null && body.trim().isNotEmpty) {
      queryParams['body'] = body;
    }
    final emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: queryParams,
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        Get.snackbar('Support Email', 'Email us at: $email', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Support Email', 'Email us at: $email', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
