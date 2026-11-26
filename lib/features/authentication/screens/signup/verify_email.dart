import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../controllers/signup/verify_email_controller.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(VerifyEmailController());

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => AuthenticationRepository.instance.logout(),
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
                        image: AssetImage(AvailImages.deliveredEmailIllustration),
                        width: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwsections),

                  /// Title & Subtitle
                  Text(
                    AvailTexts.confirmEmail,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AvailSizes.spacebtwitems),
                  Text(
                    email ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AvailSizes.spacebtwitems),
                  Text(
                    AvailTexts.confirmEmailSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AvailSizes.spacebtwsections),

                  /// Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => controller.checkEmailVerificationStatus(),
                      child: const Text(AvailTexts.aContinue),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwitems),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => controller.sendEmailVerification(),
                      child: const Text(AvailTexts.resendCode),
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
