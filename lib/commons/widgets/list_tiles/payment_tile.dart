import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../features/personalization/controllers/payment_controller.dart';
import '../../../features/shop/models/payment_method_model.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/helpers/helper_functions.dart';
import '../custom_shapes/containers/rounded_container.dart';

class AvailPaymentTile extends StatelessWidget {
  const AvailPaymentTile({super.key, required this.paymentMethod});

  final PaymentMethodModel paymentMethod;

  @override
  Widget build(BuildContext context) {
    final controller = PaymentController.instance;
    return ListTile(
      contentPadding: const EdgeInsets.all(0),
      onTap: () {
        controller.setPaymentType(paymentMethod.type, paymentMethod.code);
        Get.back(); // close bottom sheet
      },
      leading: AvailRoundedContainer(
        width: 60,
        height: 40,
        backgroundColor: AvailHelperFunctions.isDarkMode(context) ? AvailColors.light : AvailColors.white,
        padding: const EdgeInsets.all(AvailSizes.sm),
        child: Image(image: AssetImage(paymentMethod.image), fit: BoxFit.contain),
      ), // TRoundedContainer
      title: Text(paymentMethod.name),
      trailing: const Icon(Iconsax.arrow_right_34),
    ); // ListTile
  }
}
