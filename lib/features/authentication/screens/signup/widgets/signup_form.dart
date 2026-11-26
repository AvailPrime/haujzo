import './terms_conditions_checkbox.dart';
import '../../../../../commons/widgets/login_signup/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/validators/validator.dart';
import '../../../controllers/signup/signup_controller.dart';

class AvailSignupFrom extends StatelessWidget {
  const AvailSignupFrom({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SignupController());

    return Form(
      key: controller.signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Account Type Selector (Individual vs Business Shipper)
          Text(
            'Select Account Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AvailSizes.sm),

          Obx(
            () => Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.accountType.value = 'individual',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AvailSizes.md),
                      decoration: BoxDecoration(
                        color: controller.accountType.value == 'individual'
                            ? AvailColors.primary.withAlpha(30)
                            : Colors.transparent,
                        border: Border.all(
                          color: controller.accountType.value == 'individual'
                              ? AvailColors.primary
                              : Colors.grey.shade400,
                          width: controller.accountType.value == 'individual' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AvailSizes.borderRadiusLg),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Iconsax.user,
                            color: controller.accountType.value == 'individual'
                                ? AvailColors.primary
                                : Colors.grey,
                          ),
                          const SizedBox(height: AvailSizes.xs),
                          Text(
                            'Individual',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: controller.accountType.value == 'individual'
                                      ? AvailColors.primary
                                      : Colors.grey.shade700,
                                  fontWeight: controller.accountType.value == 'individual'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AvailSizes.spacebtwinputfield),
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.accountType.value = 'business',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AvailSizes.md),
                      decoration: BoxDecoration(
                        color: controller.accountType.value == 'business'
                            ? AvailColors.primary.withAlpha(30)
                            : Colors.transparent,
                        border: Border.all(
                          color: controller.accountType.value == 'business'
                              ? AvailColors.primary
                              : Colors.grey.shade400,
                          width: controller.accountType.value == 'business' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AvailSizes.borderRadiusLg),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Iconsax.building,
                            color: controller.accountType.value == 'business'
                                ? AvailColors.primary
                                : Colors.grey,
                          ),
                          const SizedBox(height: AvailSizes.xs),
                          Text(
                            'Business Shipper',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: controller.accountType.value == 'business'
                                      ? AvailColors.primary
                                      : Colors.grey.shade700,
                                  fontWeight: controller.accountType.value == 'business'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AvailSizes.spacebtwsections),

          /// Contact Person First & Last Name
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller.firstName,
                  validator: (value) => AvailValidator.validateEmptyText('First Name', value),
                  decoration: const InputDecoration(
                    labelText: AvailTexts.firstName,
                    prefixIcon: Icon(Iconsax.user),
                  ),
                ),
              ),
              const SizedBox(width: AvailSizes.spacebtwinputfield),
              Expanded(
                child: TextFormField(
                  controller: controller.lastName,
                  validator: (value) => AvailValidator.validateEmptyText('Last Name', value),
                  decoration: const InputDecoration(
                    labelText: AvailTexts.lastName,
                    prefixIcon: Icon(Iconsax.user),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AvailSizes.spacebtwinputfield),

          /// Notice Banner for Verification Requirement (Cargo Safety & Security)
          Obx(() {
            final isBusiness = controller.accountType.value == 'business';
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AvailSizes.md),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(AvailSizes.borderRadiusMd),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.shield_security, color: Colors.blue.shade700),
                      const SizedBox(width: AvailSizes.sm),
                      Expanded(
                        child: Text(
                          isBusiness
                              ? 'Business accounts enable Bulk Ordering & Corporate Shipping Invoices. Business verification (DIDIT KYB) is required.'
                              : 'Identity verification (DIDIT KYC) is required for cargo safety and driver security accountability.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AvailSizes.spacebtwinputfield),
              ],
            );
          }),

          /// Business Shipper Specific Fields
          Obx(() {
            if (controller.accountType.value == 'business') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  TextFormField(
                    controller: controller.companyName,
                    validator: (value) => controller.accountType.value == 'business'
                        ? AvailValidator.validateEmptyText('Company Name', value)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Company Legal Name',
                      prefixIcon: Icon(Iconsax.building),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwinputfield),

                  TextFormField(
                    controller: controller.registrationNumber,
                    validator: (value) => controller.accountType.value == 'business'
                        ? AvailValidator.validateEmptyText('Business Registration / Tax ID', value)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Registration No. / Tax ID (TIN)',
                      prefixIcon: Icon(Iconsax.card),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwinputfield),

                  TextFormField(
                    controller: controller.businessAddress,
                    validator: (value) => controller.accountType.value == 'business'
                        ? AvailValidator.validateEmptyText('Business Address', value)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Company Office Address',
                      prefixIcon: Icon(Iconsax.location),
                    ),
                  ),
                  const SizedBox(height: AvailSizes.spacebtwinputfield),
                ],
              );
            }
            return const SizedBox.shrink();
          }),

          TextFormField(
            controller: controller.username,
            validator: (value) => AvailValidator.validateEmptyText('Username', value),
            decoration: const InputDecoration(
              labelText: AvailTexts.username,
              prefixIcon: Icon(Iconsax.user_edit),
            ),
          ),
          const SizedBox(height: AvailSizes.spacebtwinputfield),

          Obx(
            () => TextFormField(
              controller: controller.email,
              validator: (value) => AvailValidator.validateEmail(value),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: controller.accountType.value == 'business' ? 'Official Business Email' : AvailTexts.email,
                prefixIcon: const Icon(Iconsax.direct),
              ),
            ),
          ),
          const SizedBox(height: AvailSizes.spacebtwinputfield),

          Obx(
            () => AvailCountryPicker(
              selectedCountry: controller.selectedCountryObject.value,
              onCountrySelected: (country) => controller.selectedCountryObject.value = country,
            ),
          ),
          const SizedBox(height: AvailSizes.spacebtwinputfield),

          Obx(
            () => TextFormField(
              controller: controller.phoneNumber,
              validator: (value) => AvailValidator.validatePhoneNumber(value),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AvailTexts.phoneNo,
                hintText: 'e.g. 0241234567 or 241234567',
                prefixIcon: const Icon(Iconsax.call),
                prefixText: controller.selectedCountryObject.value?.phoneCode != null
                    ? '${controller.selectedCountryObject.value!.phoneCode} '
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AvailSizes.spacebtwinputfield),

          Obx(
            () => TextFormField(
              controller: controller.password,
              validator: (value) => AvailValidator.validatePassword(value),
              obscureText: controller.hidePassword.value,
              decoration: InputDecoration(
                prefixIcon: const Icon(Iconsax.password_check),
                labelText: AvailTexts.password,
                suffixIcon: IconButton(
                  onPressed: () => controller.hidePassword.value = !controller.hidePassword.value,
                  icon: Icon(controller.hidePassword.value ? Iconsax.eye_slash : Iconsax.eye),
                ),
              ),
            ),
          ),
          const SizedBox(height: AvailSizes.spacebtwsections),

          const AvailTermsandConditionsCheckbox(),
          const SizedBox(height: AvailSizes.spacebtwsections),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.signup(),
              child: const Text(AvailTexts.createAccount),
            ),
          ),
        ],
      ),
    );
  }
}
