import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/address_controller.dart';
import './add_new_address.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';

class UserAddressScreen extends StatelessWidget {
  const UserAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddressController());
    final dark = AvailHelperFunctions.isDarkMode(context);
    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);

    return Scaffold(
      backgroundColor: dark ? AvailColors.dark : const Color(0xFFF8FAFC),
      appBar: isEmbedded
          ? null
          : const AvailAppbar(
              title: Text(
                'Saved Addresses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
              ),
              showBackArrow: true,
              showBackgroundColor: true,
              backArrowColor: Colors.white,
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AvailColors.primary,
        onPressed: () {
          if (Get.isRegistered<NavigationController>()) {
            NavigationController.instance.openSubScreen(
              const AddNewAddressScreen(),
              title: 'Add New Address',
            );
          } else {
            Get.toNamed(AvailRoutes.addNewAddress);
          }
        },
        icon: const Icon(Iconsax.add, color: AvailColors.white),
        label: const Text(
          'Add Address',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        final addresses = controller.addresses;
        final selectedId = controller.selectedAddress.value.id;

        if (addresses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AvailSizes.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.location, size: 42, color: AvailColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No addresses found. Add a new one!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : AvailSizes.sm,
            vertical: isWide ? 20 : AvailSizes.sm,
          ),
          child: ResponsiveCenter(
            maxWidth: 960,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 720 ? 2 : 1;
                if (cols == 1) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AvailSizes.sm),
                    itemBuilder: (_, index) =>
                        _buildAddressCard(context, controller, addresses[index], selectedId, dark),
                  );
                }

                final rows = <Widget>[];
                for (var i = 0; i < addresses.length; i += 2) {
                  rows.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildAddressCard(
                                context, controller, addresses[i], selectedId, dark),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: i + 1 < addresses.length
                                ? _buildAddressCard(
                                    context, controller, addresses[i + 1], selectedId, dark)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(children: rows);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    AddressController controller,
    dynamic address,
    String selectedId,
    bool dark,
  ) {
    final isSelected = address.id == selectedId;
    return GestureDetector(
      onTap: () => controller.selectAddress(address),
      child: Container(
        padding: const EdgeInsets.all(AvailSizes.md),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isSelected
                ? AvailColors.primary
                : (dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: address.id,
              groupValue: selectedId,
              onChanged: (_) => controller.selectAddress(address),
              activeColor: AvailColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.formattedPhoneNo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
