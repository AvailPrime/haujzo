import '../../../../shop/models/address_model.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../commons/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../controllers/address_controller.dart';

class AvailSingleAddress extends StatelessWidget {
  const AvailSingleAddress({super.key, required this.address, required this.onTap});

  final AddressModel address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AddressController.instance;

    final dark = AvailHelperFunctions.isDarkMode(context);
    return Obx(() {
      final selectedAddressId = controller.selectedAddress.value.id;
      final selectedAddress = selectedAddressId == address.id;
      return InkWell(
        onTap: onTap,
        child: AvailRoundedContainer(
          width: double.infinity,
          showBorder: true,
          padding: const EdgeInsets.all(AvailSizes.md),
          backgroundColor: selectedAddress
              ? AvailColors.primary.withOpacity(0.5)
              : Colors.transparent,
          borderColor: selectedAddress
              ? Colors.transparent
              : dark
                  ? AvailColors.darkgrey
                  : AvailColors.grey,
          margin: const EdgeInsets.only(bottom: AvailSizes.spacebtwitems),
          child: Stack(
            children: [
              Positioned(
                right: 5,
                top: 0,
                child: Icon(
                  selectedAddress ? Iconsax.tick_circle5 : null,
                  color: selectedAddress ?  dark ? AvailColors.light : AvailColors.dark : null,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AvailSizes.sm / 2),
                  Text(address.formattedPhoneNo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AvailSizes.sm / 2),
                  Text(address.toString(),
                    softWrap: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );}
    );
  }
}
