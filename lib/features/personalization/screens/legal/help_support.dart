import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../data/repositories/support/support_config_repository.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _showTicketModal(BuildContext context, SupportConfigRepository supportRepo) {
    final bookingRefCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedCategory = 'Shipment / Fare Dispute';
    bool isSubmitting = false;

    final categories = [
      'Shipment / Fare Dispute',
      'Cargo Damage / Shortage Claim',
      'Driver Delay / No-Show',
      'Demurrage & Waiting Charges',
      'Billing & Paystack Refund',
      'Didit KYC / KYB Verification',
      'Other Inquiry',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).viewPadding.bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Iconsax.ticket, color: AvailColors.primary, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Submit Support / Dispute Ticket',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tickets are routed directly to Haujzo Portal Operations with your Shipper ID:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Issue Category',
                      prefixIcon: const Icon(Iconsax.category),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedCategory = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bookingRefCtrl,
                    decoration: InputDecoration(
                      labelText: 'Booking / Manifest ID (e.g. FT-2026...)',
                      prefixIcon: const Icon(Iconsax.hashtag),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: const Icon(Iconsax.document_text),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Describe your issue, timeline, cargo claim, or billing inquiry',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (subjectCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                                Get.snackbar(
                                  'Missing Details',
                                  'Please enter both a subject and description.',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final authUser = FirebaseAuth.instance.currentUser;
                              final ticketCode =
                                  'HZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                              final fallbackEmail = supportRepo.supportConfig.value.supportEmail;

                              try {
                                await FirebaseFirestore.instance.collection('support_tickets').add({
                                  'ticketCode': ticketCode,
                                  'userId': authUser?.uid ?? '',
                                  'userEmail': authUser?.email ?? '',
                                  'category': selectedCategory,
                                  'bookingRef': bookingRefCtrl.text.trim(),
                                  'subject': subjectCtrl.text.trim(),
                                  'message': messageCtrl.text.trim(),
                                  'status': 'open',
                                  'platform': 'Haujzo Shipper',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                                if (ctx.mounted) Navigator.pop(ctx);
                                Get.snackbar(
                                  'Ticket Dispatched',
                                  'Ticket #$ticketCode logged with Haujzo Portal Operations.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.green.shade800,
                                  colorText: Colors.white,
                                  duration: const Duration(seconds: 5),
                                );
                              } catch (e) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                Get.snackbar(
                                  'Email Fallback Recommended',
                                  'Could not sync online ($e). Please email $fallbackEmail with Ref #$ticketCode.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.black87,
                                  colorText: Colors.white,
                                  duration: const Duration(seconds: 5),
                                );
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Iconsax.send_1, color: Colors.white, size: 18),
                      label: Text(
                        isSubmitting ? 'Sending...' : 'Send to Haujzo Operations',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AvailColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supportRepo = SupportConfigRepository.instance;
    final dark = AvailHelperFunctions.isDarkMode(context);
    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : Colors.grey.shade200;
    final titleColor = dark ? Colors.white : Colors.black87;
    final bodyColor = dark ? Colors.grey.shade300 : Colors.grey.shade800;
    final isWide = SiteLayout.isWideScreen(context);

    return AppPageLayout(
      title: 'Shipper & Dispatch Support',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isWide
            ? null
            : const AvailAppbar(
                title: Text(
                  'Shipper & Dispatch Support',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white),
                ),
                showBackArrow: true,
                showBackgroundColor: true,
                backArrowColor: Colors.white,
              ),
        body: Obx(() {
        final cfg = supportRepo.supportConfig.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ResponsiveCenter(
            maxWidth: 920,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Urgent Shipment Assistance Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade900, Colors.red.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Iconsax.warning_2, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Active Shipment Emergency & Cargo SOS',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If an active cargo dispatch experiences route deviation, seal tampering, breakdown, or a safety incident:\n'
                        '1. Call the Emergency Line or Dispatch Desk immediately with your Manifest ID.\n'
                        '2. Instruct your consignee to document any seal or cargo discrepancies at handover.\n'
                        '3. Submit a formal Support Ticket with photos & Waybill PDF within 48 hours.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.2, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: supportRepo.callEmergency,
                            icon: const Icon(Iconsax.warning_2, color: Colors.red, size: 18),
                            label: Text(
                              'Emergency SOS (${cfg.emergencyNumber})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.red),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: supportRepo.callSupport,
                            icon: const Icon(Iconsax.call, color: Colors.red, size: 17),
                            label: Text(
                              'Dispatch Desk (${cfg.supportPhone})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (cfg.disputeNotice.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: dark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AvailColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Iconsax.shield_tick, color: AvailColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cfg.disputeNotice,
                            style: TextStyle(fontSize: 12.3, color: bodyColor, height: 1.4, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Support Channels
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support Channels',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _iconCircle(Iconsax.call, Colors.green),
                        title: Text(
                          'Support & Dispatcher Hotline',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
                        ),
                        subtitle: Text(
                          '${cfg.supportPhone} • ${cfg.supportHours}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                        onTap: supportRepo.callSupport,
                      ),
                      Divider(color: borderColor),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _iconCircle(Iconsax.sms, Colors.blue),
                        title: Text(
                          'Email Shipper Operations',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
                        ),
                        subtitle: Text(
                          '${cfg.supportEmail} • Disputes, refunds & cargo claims',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                        onTap: () => supportRepo.emailSupport(subject: 'Haujzo Shipper Support Request'),
                      ),
                      Divider(color: borderColor),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _iconCircle(Iconsax.warning_2, Colors.red),
                        title: Text(
                          'Emergency Safety Number',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
                        ),
                        subtitle: Text(
                          '${cfg.emergencyNumber} • Urgent cargo safety & roadside SOS',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                        onTap: supportRepo.callEmergency,
                      ),
                      Divider(color: borderColor),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _iconCircle(Iconsax.ticket, AvailColors.primary),
                        title: Text(
                          'Open In-App Support Ticket',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
                        ),
                        subtitle: const Text(
                          'Submit cargo claims, demurrage, or Paystack refund inquiries',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        trailing: const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                        onTap: () => _showTicketModal(context, supportRepo),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Operational Rules, SLAs & FAQs
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Iconsax.info_circle, color: titleColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Operational Rules, SLAs & FAQs',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildFaqItem(
                        question: 'How are freight rates and multi-currency quotes calculated?',
                        answer:
                            'Haujzo computes itemized rates before dispatch using vehicle class, route distance tier, single/round-trip leg mode, ISO container size multipliers or empty-return discounts, excess weight, road allowances, and fragile/hazardous/loading-crew selections. Display currencies (GHS, USD, NGN, EUR, GBP) convert using live FX rates, while online Paystack charges settle in GHS.',
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
                      Divider(height: 24, color: borderColor),
                      _buildFaqItem(
                        question: 'Why am I prompted to pay online once my cargo is loaded?',
                        answer:
                            'When a driver marks cargo as Loaded / Picked Up / In Transit on an unpaid booking, Haujzo triggers an urgent online payment alert. Settling via Paystack secures instant confirmation across Shipper, Driver, and Portal Admin—and once marked PAID ONLINE, never pay physical cash to the driver.',
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
                      Divider(height: 24, color: borderColor),
                      _buildFaqItem(
                        question: 'Can I edit, cancel, or get a refund on a freight manifest?',
                        answer:
                            'You can edit details only while status is "Pending", and self-cancel only before cargo is picked up/loaded. Once loaded or in transit, self-cancellation is locked to protect both parties—contact Dispatch Support for dispute review. For cancelled "Paid Online" bookings, submit a refund request via Paystack Original Source or a verified MoMo/Bank wallet (Account Name match required).',
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
                      Divider(height: 24, color: borderColor),
                      _buildFaqItem(
                        question: 'How do loading windows and demurrage charges work?',
                        answer:
                            'Every booking includes a free 2-hour (120-minute) loading window at origin and 2-hour offloading window at destination, measured by 500m GPS geofence timestamps on Haujzo Pro. Delays beyond 120 minutes caused by shipper/warehouse/port/consignee incur verifiable hourly detention/demurrage fees.',
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
                      Divider(height: 24, color: borderColor),
                      _buildFaqItem(
                        question: 'How long does Didit KYC / KYB + Admin approval take?',
                        answer:
                            'Automated Didit Protocol ID, corporate TIN, and biometric liveness checks typically complete in 1 to 5 minutes. Final Haujzo Portal Operations review completes within 2 to 24 business hours.',
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
                      Divider(height: 24, color: borderColor),
                      _buildFaqItem(
                        question: 'What are the deadlines for cargo claims and billing disputes?',
                        answer:
                            'Open any booking in My Bookings > Manifest Details and tap the Waybill icon to share your PDF Waybill. Cargo loss or damage claims must be submitted within 48 hours of delivery with photos and POD notes. Billing, fare, or demurrage disputes must be filed within 14 calendar days.',
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.toNamed(AvailRoutes.termsOfService),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'View Terms of Service',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.toNamed(AvailRoutes.privacyPolicy),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Privacy & Disclosures',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
        ),
        const SizedBox(height: 4),
        Text(answer, style: TextStyle(fontSize: 12.3, color: bodyColor, height: 1.45)),
      ],
    );
  }
}
