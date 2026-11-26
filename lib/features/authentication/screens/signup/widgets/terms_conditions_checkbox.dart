import '../../../../personalization/screens/legal/privacy_policy.dart';
import '../../../../personalization/screens/legal/terms_of_service.dart';
import '../../../../../routes/routes.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/helpers/helper_functions.dart';
import '../../../controllers/signup/signup_controller.dart';

class AvailTermsandConditionsCheckbox extends StatelessWidget {
  const AvailTermsandConditionsCheckbox({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SignupController.instance;
    final dark = AvailHelperFunctions.isDarkMode(context);
    return Row(
      children: [
        SizedBox(
            width: 24,
            height: 24,
            child: Obx(() => Checkbox(
                value: controller.privacyPolicy.value,
                onChanged: (value) => controller.privacyPolicy.value =
                    !controller.privacyPolicy.value))),
        const SizedBox(width: AvailSizes.spacebtwitems),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: '${AvailTexts.iAgreeTo} ',
                  style: Theme.of(context).textTheme.bodySmall),
              TextSpan(
                  text: '${AvailTexts.privacyPolicy} ',
                  recognizer: TapGestureRecognizer()..onTap = () => Get.toNamed(AvailRoutes.privacyPolicy),
                  style: Theme.of(context).textTheme.bodySmall!.apply(
                        color: dark ? AvailColors.white : AvailColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            dark ? AvailColors.white : AvailColors.primary,
                      )),
              TextSpan(
                  text: '${AvailTexts.and} ',
                  style: Theme.of(context).textTheme.bodySmall),
              TextSpan(
                  text: AvailTexts.termsOfUse,
                  recognizer: TapGestureRecognizer()..onTap = () => Get.toNamed(AvailRoutes.termsOfService),
                  style: Theme.of(context).textTheme.bodySmall!.apply(
                        color: dark ? AvailColors.white : AvailColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            dark ? AvailColors.white : AvailColors.primary,
                      )),
            ],
          ),
        ),
      ],
    );
  }
}
