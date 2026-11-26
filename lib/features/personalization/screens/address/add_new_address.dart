import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../commons/widgets/login_signup/country_picker.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/validators/validator.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:get/get.dart';

import 'package:truck_booking/navigation_menu.dart';
import '../../controllers/address_controller.dart';

class AddNewAddressScreen extends StatelessWidget {
  const AddNewAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddressController());
    final isWide = SiteLayout.isWideScreen(context);

    return AppPageLayout(
      title: 'Add New Address',
      child: Scaffold(
        appBar: isWide
            ? null
            : AvailAppbar(
                title: Text(
                  'Add New Address',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                showBackArrow: true,
                leadingOnPressed: () {
                  if (Get.isRegistered<NavigationController>() &&
                      NavigationController.instance.subScreen.value != null) {
                    NavigationController.instance.closeSubScreen();
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
        body: SingleChildScrollView(
        padding: EdgeInsets.all(SiteLayout.isWideScreen(context) ? 24 : AvailSizes.sm),
        child: ResponsiveCenter(
          maxWidth: 680,
          child: Form(
            key: controller.addressFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: controller.name,
                  validator: (value) => AvailValidator.validateEmptyText('Name', value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Iconsax.user),
                    labelText: 'Name',
                  ),
                ),
                const SizedBox(height: AvailSizes.spacebtwinputfield),
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
                    validator: AvailValidator.validatePhoneNumber,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Iconsax.mobile),
                      labelText: 'Phone Number',
                      prefixText: controller.selectedCountryObject.value?.phoneCode != null
                          ? '${controller.selectedCountryObject.value!.phoneCode} '
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: AvailSizes.spacebtwinputfield),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller.street,
                        validator: (value) => AvailValidator.validateEmptyText('Street', value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Iconsax.building_31),
                          labelText: 'Street',
                        ),
                      ),
                    ),
                    const SizedBox(width: AvailSizes.spacebtwinputfield),
                    Expanded(
                      child: TextFormField(
                        controller: controller.postalCode,
                        validator: (value) => AvailValidator.validateEmptyText('Postal Code', value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Iconsax.code),
                          labelText: 'Postal Code',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AvailSizes.spacebtwinputfield),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller.city,
                        validator: (value) => AvailValidator.validateEmptyText('City', value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Iconsax.building),
                          labelText: 'City',
                        ),
                      ),
                    ),
                    const SizedBox(width: AvailSizes.spacebtwinputfield),
                    Expanded(
                      child: TextFormField(
                        controller: controller.state,
                        validator: (value) => AvailValidator.validateEmptyText('State', value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Iconsax.activity),
                          labelText: 'State',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AvailSizes.spacebtwinputfield),
                const SizedBox(height: AvailSizes.defaultspace),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => controller.addNewAddress(),
                    child: const Text('Save'),
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
