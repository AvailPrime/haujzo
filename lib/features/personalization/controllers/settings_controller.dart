import './user_controller.dart';
import 'package:get/get.dart';

import '../../../data/repositories/user/app_user_repository.dart';


class SettingsController extends GetxController {
  static SettingsController get instance => Get.find();

  final userRepository = AppUserRepository.instance;
  final userController = UserController.instance;

  /// -- Observables for App Settings
  late RxBool allowDataUsage;

  @override
  void onInit() {
    super.onInit();
    final user = userController.user.value;
    allowDataUsage = user.allowDataUsage.obs;
  }

  /// -- Functions to toggle states and save to Firebase
  Future<void> toggleDataUsage(bool value) async {
    allowDataUsage.value = value;
    await userRepository.updateSingleField({'allowDataUsage': value});
  }
}
