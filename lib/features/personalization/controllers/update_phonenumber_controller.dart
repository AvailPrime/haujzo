import '../../../commons/widgets/loader/loaders.dart';
import '../../../commons/widgets/network/network_manager.dart';
import './user_controller.dart';
import '../../../utils/popups/full_screen_loader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/user/app_user_repository.dart';
import '../../../utils/constants/country_codes.dart';
import '../../../utils/constants/image_strings.dart';
import '../screens/profile/profile.dart';
import '../../../routes/routes.dart';

class UpdatePhoneNumberController extends GetxController {
  static UpdatePhoneNumberController get instance => Get.find();

  final phoneNumber = TextEditingController();
  final userController = UserController.instance;
  final userRepository = Get.put(AppUserRepository());
  final GlobalKey<FormState> updatePhoneNumberFormKey = GlobalKey<FormState>();

  /// Selected Country Object for Phone Code
  final selectedCountryObject = Rx<AvailCountry?>(null);

  @override
  void onInit() {
    initializeNames();
    super.onInit();
  }

  /// Pre-fill with current values
  Future<void> initializeNames() async {
    final user = userController.user.value;
    phoneNumber.text = user.phoneNumber;

    // Initialize country if it exists in user record
    if (user.countryCode.isNotEmpty) {
      selectedCountryObject.value = AvailCountry.africanCountries.firstWhere(
        (c) => c.code == user.countryCode,
        orElse: () => AvailCountry.africanCountries.firstWhere((c) => c.name == 'Ghana'), // Fallback to Ghana
      );
    } else {
      // Default to Ghana
      selectedCountryObject.value = AvailCountry.africanCountries.firstWhere((c) => c.name == 'Ghana');
    }
  }

  /// Update phone number
  Future<void> updatePhoneNumber() async {
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
      if (!updatePhoneNumberFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Update in Firestore
      Map<String, dynamic> data = {
        'phoneNumber': phoneNumber.text.trim(),
        'country': selectedCountryObject.value?.name ?? '',
        'countryCode': selectedCountryObject.value?.code ?? '',
      };
      await userRepository.updateSingleField(data);

      // Update locally
      userController.user.value.phoneNumber = phoneNumber.text.trim();
      userController.user.value.country = selectedCountryObject.value?.name ?? '';
      userController.user.value.countryCode = selectedCountryObject.value?.code ?? '';
      userController.user.refresh(); // 🔑 notify Obx

      // Stop loading
      AvailFullScreenLoader.stopLoading();

      // Show success
      AvailLoaders.successSnackBar(
        title: 'Congratulations',
        message: 'Your Phone Number has been Updated',
      );

      // Go back
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
