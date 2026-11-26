import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../commons/widgets/login_signup/country_picker.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/country_codes.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/helpers/helper_functions.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../controllers/payment_controller.dart';

class AddNewPaymentScreen extends StatelessWidget {
  const AddNewPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PaymentController.instance;
    final dark = AvailHelperFunctions.isDarkMode(context);

    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = dark ? Colors.grey.shade400 : Colors.grey.shade700;

    final networks = [
      {
        'name': 'MTN Mobile Money',
        'code': 'mtn',
        'image': AvailImages.mtn,
        'prefix': '024, 054, 055, 059',
        'badgeColor': Colors.amber.shade800,
      },
      {
        'name': 'Telecel Cash',
        'code': 'telecel',
        'image': AvailImages.telecel,
        'prefix': '020, 050',
        'badgeColor': Colors.red.shade700,
      },
      {
        'name': 'AirtelTigo Money',
        'code': 'airteltigo',
        'image': AvailImages.airteltigo,
        'prefix': '027, 057, 026, 056',
        'badgeColor': Colors.blue.shade800,
      },
    ];

    final isWide = SiteLayout.isWideScreen(context);

    return AppPageLayout(
      title: 'Add Payment Method',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isWide
            ? null
            : AvailAppbar(
                title: const Text(
                  'Add Payment Method',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white),
                ),
                showBackArrow: true,
                showBackgroundColor: true,
                backArrowColor: Colors.white,
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
          padding: EdgeInsets.symmetric(
            horizontal: SiteLayout.isWideScreen(context) ? 24 : 16,
            vertical: 18,
          ),
        child: ResponsiveCenter(
          maxWidth: 720,
          child: Form(
            key: controller.paymentFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 1. Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AvailColors.navyGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AvailColors.secondary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AvailColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.wallet_3, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Freight Payment Setup',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Configure your preferred payment method: Save a verified Mobile Money wallet or activate Cash on Delivery (POD).',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Cash Option Quick Action Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: controller.selectedPayment.value.isCash ? Colors.green : borderColor,
                    width: controller.selectedPayment.value.isCash ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.money, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Cash on Delivery (POD)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Zero Setup',
                                  style: TextStyle(color: Colors.green, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pay driver in cash upon arrival. No online gateway or card required.',
                            style: TextStyle(fontSize: 11, color: bodyColor),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        controller.selectCashPayment();
                        if (Get.isRegistered<NavigationController>() &&
                            NavigationController.instance.subScreen.value != null) {
                          NavigationController.instance.closeSubScreen();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop(true);
                        }
                        Get.snackbar(
                          'Payment Updated',
                          'Cash on Delivery is now your selected payment method.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Use Cash', style: TextStyle(color: Colors.green, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 3. Country / Region Selection
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Iconsax.global, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'COUNTRY / REGION FOR MOBILE MONEY',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              Obx(() => AvailCountryPicker(
                    selectedCountry: controller.selectedCountryObject.value,
                    countries: AvailCountry.momoCountries,
                    onCountrySelected: (country) {
                      controller.selectedCountryObject.value = country;
                    },
                  )),
              const SizedBox(height: 20),

              // 4. Select Network Provider
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Iconsax.radar_2, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'SELECT NETWORK PROVIDER',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              Obx(() => Column(
                    children: networks.map((network) {
                      final isSelected = controller.selectedNetwork.value == network['code'];
                      final code = network['code'] as String;

                      return GestureDetector(
                        onTap: () => controller.setPaymentType('mobile_money', code),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AvailColors.primary : borderColor,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? AvailColors.primary.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.asset(
                                  network['image'] as String,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Iconsax.mobile, color: AvailColors.primary),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      network['name'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        color: titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Prefixes: ${network['prefix']}',
                                      style: TextStyle(fontSize: 11, color: bodyColor),
                                    ),
                                  ],
                                ),
                              ),
                              Radio<String>(
                                value: code,
                                groupValue: controller.selectedNetwork.value,
                                onChanged: (val) {
                                  if (val != null) {
                                    controller.setPaymentType('mobile_money', val);
                                  }
                                },
                                activeColor: AvailColors.primary,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )),

              const SizedBox(height: 18),

              // 5. Mobile Number Input Section with Dynamic Country Code
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Iconsax.call, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'MOBILE MONEY PHONE NUMBER',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() {
                      final country = controller.selectedCountryObject.value;
                      final phoneCode = country?.phoneCode ?? '+233';

                      return TextFormField(
                        controller: controller.mobileNumberController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            width: 85,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(country?.flag ?? '🇬🇭', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Text(
                                  phoneCode,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AvailColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 80, maxWidth: 95),
                          labelText: 'Mobile Number',
                          hintText: 'e.g. 0241234567 or 241234567',
                          helperText: 'Formatted with $phoneCode for instant gateway authorization',
                          helperStyle: TextStyle(fontSize: 11, color: bodyColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AvailColors.primary, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your mobile money phone number';
                          }
                          final cleaned = value.replaceAll(RegExp(r'[\s\-+]'), '');
                          if (cleaned.length < 9) {
                            return 'Phone number is too short (min 9 digits)';
                          }
                          return null;
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller.accountNameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Iconsax.user_tick, color: AvailColors.primary),
                        labelText: 'Registered Account Name',
                        hintText: 'e.g. Kwame Mensah',
                        helperText: 'Exact name registered on this Mobile Money wallet (used for refund verification)',
                        helperMaxLines: 2,
                        helperStyle: TextStyle(fontSize: 11, color: bodyColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AvailColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the exact registered Account Name';
                        }
                        if (value.trim().split(RegExp(r'\s+')).length < 2) {
                          return 'Enter full registered account name (First & Last name)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Iconsax.shield_security, size: 15, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Protected by 256-bit encryption. A prompt will be sent to this number when authorizing payments.',
                            style: TextStyle(fontSize: 11, color: bodyColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 6. Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (controller.selectedNetwork.value.isEmpty) {
                      Get.snackbar(
                        'Provider Required',
                        'Please select your Mobile Money provider (MTN, Telecel, or AirtelTigo)',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.redAccent,
                        colorText: Colors.white,
                      );
                      return;
                    }

                    if (controller.paymentFormKey.currentState?.validate() ?? false) {
                      final added = await controller.addNewPayment();
                      if (added) {
                        if (Get.isRegistered<NavigationController>() &&
                            NavigationController.instance.subScreen.value != null) {
                          NavigationController.instance.closeSubScreen();
                          controller.loadUserPayments();
                        } else if (context.mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop(true);
                        }
                      }
                    }
                  },
                  icon: const Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                  label: const Text(
                    'Save Mobile Money Account',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          ),
        ),
      ),
    ),
  );
}
}
