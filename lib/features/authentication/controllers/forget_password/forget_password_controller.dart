import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../screens/password_configuration/reset_password.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../commons/widgets/network/network_manager.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/popups/full_screen_loader.dart';

class ForgotPasswordController extends GetxController {
  static ForgotPasswordController get instance => Get.find();

  ///  Variable
  final email = TextEditingController();
  GlobalKey<FormState> forgotPasswordFormKey = GlobalKey<FormState>();

  /// Send reset password email
  Future<void> sendPasswordResetEmail() async {
    try {
      //Start Loading
      AvailFullScreenLoader.openLoadingDialog(
          'Logging you in...', AvailImages.loadingAnimation);

      // Check internet connectivity
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Validation
      if (!forgotPasswordFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      await AuthenticationRepository.instance.sendPasswordResetEmail(email.text.trim());

      // Remove Loader
      AvailFullScreenLoader.stopLoading();

      // show success
      AvailLoaders.successSnackBar(title: 'Email Sent', message: 'Email Link sent to Reset your Password'.tr);
      
      // Redirect
      Get.toNamed(AvailRoutes.resetPassword, arguments: email.text.trim());
    } catch (e) {
      // Remove Loader
      AvailFullScreenLoader.stopLoading();

      // show success
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());

    }
  }

  /// Resend reset password email
  Future<void> resendPasswordResetEmail(String email) async {
    try {
      //Start Loading
      AvailFullScreenLoader.openLoadingDialog(
          'Logging you in...', AvailImages.loadingAnimation);

      // Check internet connectivity
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      await AuthenticationRepository.instance.sendPasswordResetEmail(email);

      // Remove Loader
      AvailFullScreenLoader.stopLoading();

      // show success
      AvailLoaders.successSnackBar(title: 'Email Sent', message: 'Email Link sent to Reset your Password'.tr);

    } catch (e) {
      // Remove Loader
      AvailFullScreenLoader.stopLoading();

      // show success
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());

    }
  }
}
