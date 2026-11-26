import '../../password_configuration/forget_password.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/validators/validator.dart';
import '../../../controllers/login/login_controller.dart';
import '../../signup/signup.dart';
import '../../../../../routes/routes.dart';

class AvailLoginForm extends StatelessWidget {
  const AvailLoginForm({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());

    return Form(
      key: controller.loginFormKey,
      child: Padding(
        padding: const EdgeInsets.only(top: AvailSizes.md),
        child: Column(
          children: [
            ///Email
            TextFormField(
              controller: controller.email,
              textInputAction: TextInputAction.next,
              validator: (value) => AvailValidator.validateEmail(value),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Iconsax.direct_right),
                  labelText: AvailTexts.email),
            ),
            const SizedBox(height: AvailSizes.spacebtwinputfield),

            /// Password
            Obx(
              () => TextFormField(
                controller: controller.password,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => controller.loginWithEmailAndPassword(),
                validator: (value) =>
                    AvailValidator.validateEmptyText('Password', value),
                obscureText: controller.hidePassword.value,
                expands: false,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Iconsax.password_check),
                    labelText: AvailTexts.password,
                    suffixIcon: IconButton(
                        onPressed: () => controller.hidePassword.value =
                            !controller.hidePassword.value,
                        icon: Icon(controller.hidePassword.value
                            ? Iconsax.eye_slash
                            : Iconsax.eye))),
              ),
            ),
            const SizedBox(height: AvailSizes.xs),

            /// Remember Me & Forgot Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// Remember Me
                Row(
                  children: [
                    Obx(() => Checkbox(
                        value: controller.rememberMe.value,
                        onChanged: (value) => controller.rememberMe.value =
                            !controller.rememberMe.value)),
                    const Text(AvailTexts.rememberMe),
                  ],
                ),

                /// Forgot Password
                TextButton(
                    onPressed: () => Get.toNamed(AvailRoutes.forgotPassword),
                    child: const Text(AvailTexts.forgotPassword)),
              ],
            ),
            const SizedBox(height: AvailSizes.md),

            /// Sign In Button
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => controller.loginWithEmailAndPassword(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(AvailTexts.signIn))),
            const SizedBox(height: 10),

            /// Create an Account
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: () => Get.toNamed(AvailRoutes.signup),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(AvailTexts.createAccount))),
          ],
        ),
      ),
    );
  }
}
