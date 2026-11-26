import 'package:flutter/material.dart';

import '../../../../../commons/widgets/images/app_logo.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';

class AvailLoginHeader extends StatelessWidget {
  const AvailLoginHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvailAppLogo.authHeader(width: 155, height: 48, scale: 1.15),
        const SizedBox(height: 10),
        Text(AvailTexts.loginTitle,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AvailSizes.xs),
        Text(AvailTexts.loginSubTitle,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
