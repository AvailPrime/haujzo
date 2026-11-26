import 'dart:async';
import '../../../routes/routes.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class NetworkManager extends GetxController {
  static NetworkManager get instance => Get.find();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final RxList<ConnectivityResult> _connectionStatus = <ConnectivityResult>[].obs;

  @override
  void onInit() {
    super.onInit();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void onReady() {
    super.onReady();
    // Check initial connectivity
    isConnected().then((connected) {
      if (!connected) {
        _updateConnectionStatus([ConnectivityResult.none]);
      }
    });
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    _connectionStatus.assignAll(results);

    if (_connectionStatus.contains(ConnectivityResult.none)) {
      if (Get.currentRoute != AvailRoutes.noNetwork) {
        Get.toNamed(AvailRoutes.noNetwork);
      }
    } else {
      if (Get.currentRoute == AvailRoutes.noNetwork) {
        Get.back();
      }
    }
  }

  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return false;
      }
      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
