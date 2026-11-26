import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../controllers/forget_password/forget_password_controller.dart';
import '../login/login.dart';
import '../../../../routes/routes.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(CupertinoIcons.clear),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: MaxWidthContainer(
          maxWidth: 500,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AvailSizes.defaultspace),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Image
                  const Center(
                    child: SizedBox(
                      height: 200,
                      child: Image(
                        image: AssetImage(AvailImages.successIllustration),
                        width: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwsections),

                  /// Email, Title & Subtitle
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AvailSizes.spacebtwitems),
                  Text(
                    AvailTexts.changeYourPasswordTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AvailSizes.spacebtwitems),
                  Text(
                    AvailTexts.changeYourPasswordSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AvailSizes.spacebtwsections),

                  /// Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.offAllNamed(AvailRoutes.signIn),
                      child: const Text(AvailTexts.done),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwitems),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => ForgotPasswordController.instance.resendPasswordResetEmail(email),
                      child: const Text(AvailTexts.resendEmail),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
