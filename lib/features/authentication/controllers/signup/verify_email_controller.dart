import 'dart:async';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../commons/widgets/success_screen/success_screen.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../routes/routes.dart';

class VerifyEmailController extends GetxController {
  static VerifyEmailController get instance => Get.find();

  /// Send Email Whenever the verify email screen appears and set timer to auto redirect
  @override
  void onInit() {
    sendEmailVerification();
    setTimerForAutoRedirect();
    super.onInit();
  }

  /// Send verification link
  Future<void> sendEmailVerification() async {
    try {
      await AuthenticationRepository.instance.sendEmailVerification();
      AvailLoaders.successSnackBar(
          title: 'Success!',
          message: 'Email verification sent. Check your inbox and verify.');
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Error!', message: e.toString());
    }
  }

  /// Timer to automatically redirect to Email verification
  void setTimerForAutoRedirect() {
    Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        await FirebaseAuth.instance.currentUser?.reload();
        final user = FirebaseAuth.instance.currentUser;
        if (user?.emailVerified ?? false) {
          timer.cancel();
          Get.off(
            () => SuccessScreen(
              image: AvailImages.successIllustration,
              title: AvailTexts.yourAccountCreatedTitle,
              subTitle: AvailTexts.yourAccountCreatedSubtitle,
              onPressed: () =>
                  AuthenticationRepository.instance.screenRedirect(),
            ),
            routeName: AvailRoutes.signupSuccess,
          );
        }
      },
    );
  }

  /// Manually check if Email Verified
  Future<void> checkEmailVerificationStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.emailVerified){
      Get.off(
        () => SuccessScreen(
          image: AvailImages.successIllustration,
          title: AvailTexts.yourAccountCreatedTitle,
          subTitle: AvailTexts.yourAccountCreatedSubtitle,
          onPressed: () =>
              AuthenticationRepository.instance.screenRedirect(),
        ),
        routeName: AvailRoutes.signupSuccess,
      );
    }
  }
}
