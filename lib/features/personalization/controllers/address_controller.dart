import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/widgets/loader/loaders.dart';
import '../../../commons/widgets/network/network_manager.dart';
import '../../../commons/widgets/texts/section_heading.dart';
import '../../../data/repositories/address/address_repository.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/image_strings.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../../../utils/constants/country_codes.dart';
import '../../shop/models/address_model.dart';
import '../screens/address/add_new_address.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../routes/routes.dart';

class AddressController extends GetxController {
  static AddressController get instance => Get.find();

  // Form fields
  final name = TextEditingController();
  final phoneNumber = TextEditingController();
  final street = TextEditingController();
  final postalCode = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final country = TextEditingController();
  final selectedCountryObject = Rx<AvailCountry?>(AvailCountry.africanCountries.firstWhere((c) => c.name == 'Ghana', orElse: () => AvailCountry.africanCountries.first));
  GlobalKey<FormState> addressFormKey = GlobalKey<FormState>();

  // Reactive selected address
  final Rx<AddressModel> selectedAddress = AddressModel.empty().obs;

  // Reactive address list
  RxList<AddressModel> addresses = <AddressModel>[].obs;

  // Repository
  final addressRepository = Get.put(AddressRepository());

  @override
  void onInit() {
    super.onInit();
    loadUserAddresses();

    // Sync country text and phone code prefix
    ever(selectedCountryObject, (AvailCountry? countryObj) {
      if (countryObj != null) {
        country.text = countryObj.name;
      }
    });
  }

  /// Load all user addresses and set default
  Future<void> loadUserAddresses() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        addresses.clear();
        selectedAddress.value = AddressModel.empty();
        return;
      }
      final fetchedAddresses = await addressRepository.fetchUserAddresses();
      addresses.assignAll(fetchedAddresses); // reactive update

      final defaultId = await addressRepository.getDefaultAddressId();
      if (defaultId != null) {
        selectedAddress.value = addresses.firstWhere(
              (a) => a.id == defaultId,
          orElse: () => AddressModel.empty(),
        );
      } else if (addresses.isNotEmpty) {
        // If no default, set the first address as default
        selectedAddress.value = addresses.first;
        await addressRepository.setDefaultAddress(addresses.first.id);
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    }
  }

  /// Select a new address (radio button)
  Future<void> selectAddress(AddressModel address, {bool closePopup = false}) async {
    // Update UI immediately
    selectedAddress.value = address;

    // Close popup immediately if requested
    if (closePopup && Get.context != null) {
      Navigator.of(Get.context!).pop();
    }

    // Update Firestore in background
    addressRepository.setDefaultAddress(address.id).catchError((e) {
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    });
  }

  /// Add a new address
  Future<void> addNewAddress() async {
    try {
      AvailFullScreenLoader.openLoadingDialog(
          'Storing_Address_...', AvailImages.loadingAnimation);

      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      if (addressFormKey.currentState!.validate()) {
        final phoneCode = selectedCountryObject.value?.phoneCode ?? '';
        final cleanedPhone = phoneNumber.text.trim().replaceFirst(phoneCode, '').trim();
        final fullPhoneNumber = '$phoneCode $cleanedPhone';
        final newAddress = AddressModel(
          id: '',
          name: name.text.trim(),
          phoneNumber: fullPhoneNumber,
          street: street.text.trim(),
          city: city.text.trim(),
          state: state.text.trim(),
          postalCode: postalCode.text.trim(),
          country: country.text.trim(),
        );

        final id = await addressRepository.addAddress(newAddress);
        newAddress.id = id;

        addresses.add(newAddress); // reactive update

        // Optionally select as default if no previous default
        if (selectedAddress.value.id.isEmpty) {
          await selectAddress(newAddress);
        }

        AvailFullScreenLoader.stopLoading();
        AvailLoaders.successSnackBar(
            title: 'Success', message: 'Address saved successfully');

        resetFormFields();

        // Close popup or subScreen
        if (Get.isRegistered<NavigationController>() &&
            NavigationController.instance.subScreen.value != null) {
          NavigationController.instance.closeSubScreen();
        } else if (Navigator.of(Get.context!).canPop()) {
          Navigator.of(Get.context!).pop();
        }
      }
    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    }
  }

  /// Reset form fields
  void resetFormFields() {
    name.clear();
    phoneNumber.clear();
    street.clear();
    postalCode.clear();
    city.clear();
    state.clear();
    country.clear();
    selectedCountryObject.value = null;
    addressFormKey.currentState?.reset();
  }

  /// Delete an address
  Future<void> deleteAddress(String addressId) async {
    try {
      Get.defaultDialog(
        title: 'Delete Address',
        middleText: 'Are you sure you want to delete this address?',
        onConfirm: () async {
          Navigator.of(Get.overlayContext!).pop(); // Close dialog
          AvailLoaders.customToast(message: 'Deleting...');

          await addressRepository.deleteAddress(addressId);

          // Update local list
          addresses.removeWhere((element) => element.id == addressId);

          // If the deleted address was the selected one, clear selection
          if (selectedAddress.value.id == addressId) {
            selectedAddress.value = AddressModel.empty();
            if (addresses.isNotEmpty) {
              await selectAddress(addresses.first);
            }
          }

          AvailLoaders.customToast(message: 'Address deleted successfully');
        },
        onCancel: () {},
        textConfirm: 'Delete',
        textCancel: 'Cancel',
        confirmTextColor: Colors.white,
        buttonColor: Colors.red,
      );
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Error', message: 'Failed to delete address: $e');
    }
  }

  /// Popup to select address (uses radio buttons)
  Future<AddressModel?> selectNewAddressPopup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<AddressModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(AvailSizes.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvailSectionHeading(
                  title: 'Select Address',
                  showActionButton: false,
                ),

                /// Address List
                Expanded(
                  child: Obx(() {
                    final currentSelected = selectedAddress.value;

                    if (addresses.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AvailSizes.lg),
                          child: Text(
                            'No addresses found. Add a new one!',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AvailSizes.sm),
                      itemCount: addresses.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AvailSizes.xs),
                      itemBuilder: (_, index) {
                        final address = addresses[index];
                        final isSelected = currentSelected != null &&
                            address.id == currentSelected.id;

                        return GestureDetector(
                          onTap: () => selectAddress(address),
                          child: Container(
                            padding: const EdgeInsets.all(AvailSizes.sm),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF132238) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: isSelected
                                    ? AvailColors.primary
                                    : (isDark ? const Color(0xFF1E3A5F) : Colors.transparent),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Radio<String>(
                                  value: address.id,
                                  groupValue:
                                      currentSelected?.id, // 👈 reactive
                                  onChanged: (_) => selectAddress(address),
                                  activeColor: AvailColors.primary,
                                ),
                                const SizedBox(width: 12),

                                /// Address Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address.formattedPhoneNo,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address.toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),

                                /// DELETE ICON
                                IconButton(
                                  onPressed: () => deleteAddress(address.id),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),

                const SizedBox(height: AvailSizes.xxs),

                /// Add New Address Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Get.toNamed(AvailRoutes.addNewAddress),
                    child: const Text('Add new address'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
