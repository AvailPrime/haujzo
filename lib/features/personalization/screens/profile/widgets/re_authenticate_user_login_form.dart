import '../../../../../commons/widgets/appBar/appbar.dart';
import '../../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../../utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/validators/validator.dart';
import '../../../controllers/user_controller.dart';

class ReAuthLoginForm extends StatelessWidget {
  const ReAuthLoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = UserController.instance;
    return Scaffold(
      appBar: const AvailAppbar(title: Text('Re-Authenticate'), showBackArrow: true),
      body: SafeArea(
        top: false,
        child: MaxWidthContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(AvailSizes.defaultSpace),
          child: Form(
          key: controller.reAuthFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ///Email
              TextFormField(
                controller: controller.verifyEmail,
                validator: (value) => AvailValidator.validateEmail(value),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Iconsax.direct_right),
                    labelText: AvailTexts.email),
              ),
              const SizedBox(height: AvailSizes.spacebtwinputfield),

              /// Password
              Obx(() => TextFormField(
                  controller: controller.verifyPassword,
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
               SizedBox(height: AvailSizes.spacebtwsections),

              /// Sign In Button
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () => controller.reAuthenticateEmailAndPasswordUser(),
                      child: const Text('Verify'))),
              const SizedBox(height: AvailSizes.spacebtwitems),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }
}
