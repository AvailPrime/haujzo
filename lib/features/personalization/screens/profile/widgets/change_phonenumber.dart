import '../../../../../commons/widgets/appBar/appbar.dart';
import '../../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../../commons/widgets/login_signup/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:get/get.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/helpers/helper_functions.dart';
import '../../../../../utils/validators/validator.dart';
import '../../../controllers/update_phonenumber_controller.dart';

class ChangePhoneNumber extends StatelessWidget {
  const ChangePhoneNumber({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UpdatePhoneNumberController());
    final dark = AvailHelperFunctions.isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? AvailColors.dark : const Color(0xFFF1F5F9),
      appBar: const AvailAppbar(
        showBackArrow: true,
        showBackgroundColor: true,
        backgroundColor: Color(0xFF0B1D35),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UPDATE PHONE NUMBER',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            Text(
              'Dispatch & Driver Coordination Line',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: MaxWidthContainer(
          maxWidth: 540,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(AvailSizes.defaultspace),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF132238) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Iconsax.call,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Primary Contact Line',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: dark ? Colors.white : AvailColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update your phone number and country code for driver arrival calls and SMS dispatch alerts.',
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.grey.shade400 : AvailColors.darkgrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Form(
                  key: controller.updatePhoneNumberFormKey,
                  child: Column(
                    children: [
                      Obx(
                        () => AvailCountryPicker(
                          selectedCountry: controller.selectedCountryObject.value,
                          onCountrySelected: (country) {
                            controller.selectedCountryObject.value = country;
                          },
                        ),
                      ),
                      const SizedBox(height: AvailSizes.spacebtwinputfield),
                      Obx(
                        () => TextFormField(
                          controller: controller.phoneNumber,
                          validator: (value) =>
                              AvailValidator.validatePhoneNumber(value),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AvailTexts.phoneNo,
                            prefixIcon: const Icon(Iconsax.call),
                            prefixText: controller.selectedCountryObject.value
                                        ?.phoneCode !=
                                    null
                                ? '${controller.selectedCountryObject.value!.phoneCode} '
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => controller.updatePhoneNumber(),
                          icon: const Icon(Iconsax.tick_circle, size: 18, color: Colors.white),
                          label: const Text(
                            'Save Phone Number',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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
