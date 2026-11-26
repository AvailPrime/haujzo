
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/device/device_utility.dart';
import '../../../../../utils/helpers/helper_functions.dart';
import '../../../controllers/onboarding/onboarding_controller.dart' show OnBoardingController;

class OnBoardingNextButton extends StatelessWidget {
  const OnBoardingNextButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);

    return Positioned(
      right: AvailSizes.defaultspace,
      bottom: AvailDeviceUtils.getBottomNavigationBarHeight(),
      child: ElevatedButton(
        onPressed: () => OnBoardingController.instance.nextPage(),
        style: ElevatedButton.styleFrom(
          backgroundColor: dark? AvailColors.primary : Colors.black,
          shape: const CircleBorder(),
        ),
        child: const Icon(Iconsax.arrow_right_3),
      ),
    );
  }
}
