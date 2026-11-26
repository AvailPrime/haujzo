import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../commons/widgets/shimmer/shimmer.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/payment_controller.dart';
import 'add_new_payment.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';

class UserPaymentMethodsScreen extends StatelessWidget {
  const UserPaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PaymentController());
    final dark = AvailHelperFunctions.isDarkMode(context);

    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = dark ? Colors.grey.shade400 : Colors.grey.shade700;

    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isEmbedded
          ? null
          : const AvailAppbar(
              title: Text(
                'Payment Methods & Wallets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
              ),
              showBackArrow: true,
              showBackgroundColor: true,
              backArrowColor: Colors.white,
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AvailColors.primary,
        onPressed: () async {
          if (Get.isRegistered<NavigationController>()) {
            NavigationController.instance.openSubScreen(
              AddNewPaymentScreen(),
              title: 'Add Payment Method',
            );
          } else {
            await Get.toNamed(AvailRoutes.addNewPayment);
            await controller.loadUserPayments();
          }
        },
        icon: const Icon(Iconsax.add, color: Colors.white, size: 20),
        label: const Text(
          'Add Mobile Money',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: Obx(() {
        final payments = controller.savedPayments;
        final selectedPayment = controller.selectedPayment.value;
        final selectedId = selectedPayment.id;
        final isCashSelected = selectedPayment.isCash;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 16,
            vertical: 18,
          ),
          child: ResponsiveCenter(
            maxWidth: 960,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 1. Hero Security & Payment Methods Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AvailColors.navyGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AvailColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AvailColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Iconsax.wallet_3, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Digital Freight Payments',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Cash on Delivery, Mobile Money & Gateway',
                                style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select your preferred freight settlement method. You can choose Cash on Delivery (POD) or save your verified Mobile Money wallet for one-tap payments.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 2. Section Header: Active Payment Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.cards, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'AVAILABLE PAYMENT METHODS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${payments.length + 1} Options',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AvailColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Permanent Cash on Delivery Option Card
              GestureDetector(
                onTap: () => controller.selectCashPayment(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCashSelected ? Colors.green : borderColor,
                      width: isCashSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isCashSelected ? Colors.green.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.money, color: Colors.green, size: 28),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: titleColor,
                                  ),
                                ),
                                if (isCashSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Active Default',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Pay physical cash directly to driver upon cargo arrival & POD verification',
                              style: TextStyle(fontSize: 11.5, color: bodyColor),
                            ),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value: 'cash_on_delivery',
                        groupValue: selectedId,
                        onChanged: (_) => controller.selectCashPayment(),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Section Header: Saved Mobile Money Accounts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.mobile, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'SAVED MOBILE MONEY WALLETS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (payments.isNotEmpty)
                    Text(
                      '${payments.length} Saved',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bodyColor),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 5. Loading / Empty State / List of MoMo Accounts
              if (controller.isLoading.value) ...[
                Column(
                  children: List.generate(
                    2,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AvailShimmerEffect(width: double.infinity, height: 86, radius: 18),
                    ),
                  ),
                ),
              ] else if (payments.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AvailColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.wallet_add, size: 30, color: AvailColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Mobile Money Wallets Saved Yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add your MTN, Telecel, or AirtelTigo account for instant electronic freight payments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: bodyColor, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (Get.isRegistered<NavigationController>()) {
                            NavigationController.instance.openSubScreen(
                              AddNewPaymentScreen(),
                              title: 'Add Payment Method',
                            );
                          } else {
                            await Get.toNamed(AvailRoutes.addNewPayment);
                            await controller.loadUserPayments();
                          }
                        },
                        icon: const Icon(Iconsax.add, size: 16),
                        label: const Text('Add Mobile Money Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AvailColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final payment = payments[index];
                    final isSelected = payment.id == selectedId;
                    final networkCode = (payment.network ?? '').toLowerCase();
                    final networkImage = _getNetworkImage(networkCode);

                    return GestureDetector(
                      onTap: () => controller.selectPayment(payment),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AvailColors.primary : borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? AvailColors.primary.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Network Logo
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: networkImage != null
                                  ? Image.asset(
                                      networkImage,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(Iconsax.mobile, color: AvailColors.primary),
                                    )
                                  : const Icon(Iconsax.mobile, color: AvailColors.primary),
                            ),
                            const SizedBox(width: 14),

                            // Account Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        payment.displayTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: titleColor,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AvailColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Default',
                                            style: TextStyle(
                                              color: AvailColors.primary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    payment.mobileNumber != null
                                        ? 'Account: ${payment.mobileNumber}'
                                        : (payment.displaySubtitle.isNotEmpty ? payment.displaySubtitle : 'Saved Payment Account'),
                                    style: TextStyle(fontSize: 11.5, color: bodyColor),
                                  ),
                                  if ((payment.accountName ?? '').trim().isNotEmpty)
                                    Text(
                                      'Account Name: ${payment.accountName!.trim()}',
                                      style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                                    )
                                  else if (payment.method.type == 'mobile_money')
                                    Text(
                                      '⚠ Missing Account Name (Re-add wallet to verify for refunds)',
                                      style: TextStyle(fontSize: 10.5, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),

                            // Delete Action
                            IconButton(
                              onPressed: () => controller.deletePayment(payment.id),
                              icon: const Icon(Iconsax.trash, color: Colors.redAccent, size: 18),
                              tooltip: 'Delete Method',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),

              // 6. Accepted Methods Overview
              Row(
                children: [
                  Icon(Iconsax.shield_tick, size: 16, color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'SUPPORTED PAYMENT CHANNELS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSupportedRow(
                      icon: Icons.money,
                      iconColor: Colors.green,
                      title: 'Cash on Delivery (POD)',
                      desc: 'Zero-fee physical settlement directly with verified driver upon digital waybill sign-off',
                      titleColor: titleColor,
                      bodyColor: bodyColor,
                    ),
                    Divider(height: 16, color: borderColor),
                    _buildSupportedRow(
                      icon: Iconsax.mobile,
                      iconColor: Colors.amber.shade800,
                      title: 'Mobile Money (Ghana & Regional)',
                      desc: 'MTN Mobile Money, Telecel Cash, and AirtelTigo Money via instant USSD prompt',
                      titleColor: titleColor,
                      bodyColor: bodyColor,
                    ),
                    Divider(height: 16, color: borderColor),
                    _buildSupportedRow(
                      icon: Iconsax.card,
                      iconColor: Colors.blue,
                      title: 'Cards & Online Banking',
                      desc: 'Visa, MasterCard & Bank Transfers processed via Paystack with 3D Secure verification',
                      titleColor: titleColor,
                      bodyColor: bodyColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // Padding for FloatingActionButton
            ],
          ),
          ),
        );
      }),
    );
  }

  static String? _getNetworkImage(String network) {
    if (network.contains('mtn')) return AvailImages.mtn;
    if (network.contains('telecel')) return AvailImages.telecel;
    if (network.contains('airtel')) return AvailImages.airteltigo;
    return null;
  }

  Widget _buildSupportedRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: titleColor)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 11, color: bodyColor, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
