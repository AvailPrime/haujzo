import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/validators/validator.dart';
import '../../controllers/forget_password/forget_password_controller.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ForgotPasswordController());
    return Scaffold(
      appBar: AppBar(),
      body: MaxWidthContainer(
        maxWidth: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AvailSizes.defaultspace),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Heading
              Text(AvailTexts.forgotPasswordTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AvailSizes.spacebtwitems),
              Text(AvailTexts.forgotPasswordSubtitle, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AvailSizes.spacebtwsections * 1.5),

              /// Text field
              Form(
                key: controller.forgotPasswordFormKey,
                child: TextFormField(
                  controller: controller.email,
                  validator: AvailValidator.validateEmail,
                  decoration: const InputDecoration(
                    labelText: AvailTexts.email,
                    prefixIcon: Icon(Iconsax.direct_right),
                  ),
                ),
              ),
              const SizedBox(height: AvailSizes.spacebtwsections),

              /// Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => controller.sendPasswordResetEmail(),
                  child: const Text(AvailTexts.submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
