import '../../../commons/widgets/loader/loaders.dart';
import '../../../commons/widgets/network/network_manager.dart';
import './user_controller.dart';
import '../../../utils/popups/full_screen_loader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


import '../../../data/repositories/user/app_user_repository.dart';
import '../../../utils/constants/image_strings.dart';
import '../screens/profile/profile.dart';
import '../../../routes/routes.dart';

class UpdateUsernameController extends GetxController {
  static UpdateUsernameController get instance => Get.find();

  final username = TextEditingController();
  final userController = UserController.instance;
  final userRepository = Get.put(AppUserRepository());
  final GlobalKey<FormState> updateUsernameFormKey = GlobalKey<FormState>();

  @override
  void onInit() {
    initializeNames();
    super.onInit();
  }

  /// Pre-fill with current values
  Future<void> initializeNames() async {
    username.text = userController.user.value.username;

  }

  /// Update user name
  Future<void> updateUsername() async {
    try {
      // Start loading
      AvailFullScreenLoader.openLoadingDialog(
        'We are updating your information...',
        AvailImages.loadingAnimation,
      );

      // Check internet
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Form validation
      if (!updateUsernameFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Update in Firestore
      Map<String, dynamic> name = {
        'username': username.text.trim(),
        'Username': username.text.trim(),
      };
      await userRepository.updateSingleField(name);

      // Update locally
      userController.user.value.username = username.text.trim();
      userController.user.refresh(); // 🔑 notify Obx

      // Stop loading
      AvailFullScreenLoader.stopLoading();

      // Show success
      AvailLoaders.successSnackBar(
        title: 'Congratulations',
        message: 'Your Username has been Updated',
      );

      // Go back instead of pushing another ProfileScreen
      Navigator.of(Get.context!).pop();

    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(
        title: 'Error',
        message: e.toString(),
      );
    }
  }
}
