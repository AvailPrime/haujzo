import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/authentication/controllers/login/login_controller.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/image_strings.dart';
import '../../../utils/constants/sizes.dart';

class AvailSocialButtons extends StatelessWidget {
  const AvailSocialButtons({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: AvailColors.grey), borderRadius: BorderRadius.circular(100)),
          child: IconButton(
            onPressed: () => controller.googleSignIn(),
            icon: const Image(
              width: AvailSizes.iconmd,
              height: AvailSizes.iconsm,
              image: AssetImage(AvailImages.google),
            ),
          ),
        ),
        const SizedBox(width:  AvailSizes.spacebtwitems),
        Container(
          decoration: BoxDecoration(border: Border.all(color: AvailColors.grey), borderRadius: BorderRadius.circular(100)),
          child: IconButton(
            onPressed: (){},
            icon: const Image(
              width: AvailSizes.iconmd,
              height: AvailSizes.iconsm,
              image: AssetImage(AvailImages.facebook),
            ),
          ),
        ),
      ],
    );
  }
}
