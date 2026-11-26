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

class UpdateNameController extends GetxController {
  static UpdateNameController get instance => Get.find();

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final userController = UserController.instance;
  final userRepository = Get.put(AppUserRepository());
  final GlobalKey<FormState> updateUserNameFormKey = GlobalKey<FormState>();

  @override
  void onInit() {
    initializeNames();
    super.onInit();
  }

  /// Pre-fill with current values
  Future<void> initializeNames() async {
    firstName.text = userController.user.value.firstName;
    lastName.text = userController.user.value.lastName;
  }

  /// Update user name
  Future<void> updateUserName() async {
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
      if (!updateUserNameFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Update in Firestore
      Map<String, dynamic> name = {
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'FirstName': firstName.text.trim(),
        'LastName': lastName.text.trim(),
      };
      await userRepository.updateSingleField(name);

      // Update locally
      userController.user.value.firstName = firstName.text.trim();
      userController.user.value.lastName = lastName.text.trim();
      userController.user.refresh(); // 🔑 notify Obx

      // Stop loading
      AvailFullScreenLoader.stopLoading();

      // Show success
      AvailLoaders.successSnackBar(
        title: 'Congratulations',
        message: 'Your Name has been Updated',
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
