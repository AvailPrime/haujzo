import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../data/repositories/support/support_config_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../privacy/privacy_settings.dart';
import '../../../../routes/routes.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : Colors.grey.shade200;
    final titleColor = dark ? Colors.white : Colors.black87;
    final bodyColor = dark ? Colors.grey.shade300 : Colors.grey.shade800;
    final isWide = SiteLayout.isWideScreen(context);

    return AppPageLayout(
      title: 'Privacy Policy & Disclosures',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isWide
            ? null
            : const AvailAppbar(
                title: Text(
                  'Privacy Policy & Disclosures',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white),
                ),
                showBackArrow: true,
                showBackgroundColor: true,
                backArrowColor: Colors.white,
              ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ResponsiveCenter(
          maxWidth: 920,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Summary Card
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AvailColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Iconsax.shield_tick, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Haujzo Data Privacy Policy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Effective: Nov 17, 2026 • Google Play, Act 843 & GDPR',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'This Privacy Policy governs how Haujzo collects, processes, shares, and safeguards personal credentials, corporate KYB records, identity biometrics, freight manifests, payment logs, and location telematics for Individual and Business Shippers across the Haujzo ecosystem.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.2, height: 1.45),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // PROMINENT LOCATION DISCLOSURE (GOOGLE PLAY COMPLIANCE)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dark ? Colors.amber.shade900.withValues(alpha: 0.22) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: dark ? Colors.amber.shade600 : Colors.amber.shade400,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.location_cross,
                          color: dark ? Colors.amber.shade300 : Colors.amber.shade900,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Prominent Disclosure: Location & Routing Data',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: dark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Haujzo collects precise and approximate foreground location data (ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION) while you are actively using the app to enable Google Maps GPS pickup, intermediate stop, and dropoff pinning, reverse-geocoded terminal addresses, live corridor distance and fare estimation, and active shipment map tracking. Haujzo does NOT collect your device location in the background when the app is closed.\n\n'
                      '• When Location is Collected: Accessed only in the foreground when you grant location permission and tap "Current GPS Location", pin route coordinates on Google Maps, or view live freight dispatch progress.\n'
                      '• Who Receives Location Data: Your pickup, intermediate stop, and destination coordinates are shared with matched drivers/fleet carriers (on Haujzo Pro) and operations controllers (on Haujzo Portal) strictly to execute, verify 500m geofence arrivals, and monitor your cargo booking.\n'
                      '• How to Stop Collection: You may restrict or revoke location access at any time in your device Settings or Profile > Account Privacy & Security. Disabling GPS stops automatic pinning while still permitting manual place search.',
                      style: TextStyle(
                        fontSize: 12.2,
                        color: dark ? Colors.amber.shade100 : Colors.brown.shade900,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildDataCard(
                title: '1. Shipper Identity & Didit Biometric KYC / Corporate KYB',
                icon: Iconsax.user_tag,
                body:
                    'We collect your full name, username, email address, phone number, profile photo, optional gender, and saved pickup/delivery addresses.\n\n'
                    '• Individual Shippers (KYC): We collect your government ID type (National ID, Passport, Driver License, or Voter ID), legal name on ID, document number, and expiry date.\n'
                    '• Business Shippers (KYB): We collect your company legal name, Tax Identification / Business Registration Number, and corporate physical address.\n'
                    '• Didit Protocol Verification (verification.didit.me): We process ID document scans, corporate verification files, and 3D facial liveness checks solely to authenticate shipper identity, prevent cargo fraud, and complete dual-gate approval on Haujzo Portal.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              _buildDataCard(
                title: '2. Freight Manifests, Waybills, Camera & Audio Permissions',
                icon: Iconsax.document_text,
                body:
                    'When booking a truck, Haujzo collects cargo specifications (cargo type, ISO container size/status, container serial numbers, gross weight, itemized inventory, declared cargo value, fragile/hazardous/loading-crew selections), consignor and consignee names and phone numbers, scheduled pickup timestamps, and uploaded files (waybills, invoices, packing lists, cargo photos) stored securely in Firebase Cloud Storage.\n\n'
                    '• Camera & Media (CAMERA): Used strictly when you capture or upload profile photos, cargo/waybill attachments, or Didit verification scans.\n'
                    '• Audio & Alert Playback (RECORD_AUDIO / MODIFY_AUDIO_SETTINGS): Used only when you actively initiate supported in-app audio/communication features or receive urgent shipment payment chimes—never recorded passively in the background.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              _buildDataCard(
                title: '3. Controlled Sharing Across the Haujzo Ecosystem',
                icon: Iconsax.share,
                body:
                    'We share only the operational data required to fulfill and govern your shipment:\n\n'
                    '• Drivers & Fleet Carriers (Haujzo Pro): Receive cargo specs, pickup/stop/dropoff coordinates, consignor/consignee contacts, payment status ("Paid Online" vs. "Cash on Delivery"), and manifest documents required for carriage and geofenced POD handover.\n'
                    '• Operations Command Hub (Haujzo Portal): Administrators review KYC/KYB verification, active manifests, 500m geofence logs, Paystack refund/payout records, and support tickets.\n'
                    '• Infrastructure Processors: Google Firebase (Auth, Firestore, Realtime DB, Cloud Storage, Functions, Messaging), Google Maps Platform (Maps, Places, Directions), Didit Protocol (KYC/KYB), Paystack & Mobile Money networks (payments/refunds), and FX conversion APIs. Haujzo NEVER sells personal data.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              _buildDataCard(
                title: '4. Financial, Refund Verification & Multi-Currency Records',
                icon: Iconsax.card_pos,
                body:
                    'To process freight fares, cancellation refunds, and demurrage adjustments, we store your selected payment method (Cash on Delivery or Paystack Online—Mobile Money MTN, Telecel, AirtelTigo, or Card/Bank), saved Mobile Money/bank refund wallet details (including verified Account Holder Name), transaction references, and display currency preferences (GHS, USD, NGN, EUR, GBP).\n\n'
                    'Online charges and refunds are processed via PCI-DSS compliant Paystack infrastructure. Haujzo never stores raw card numbers, CVVs, or Mobile Money PINs.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              _buildDataCard(
                title: '5. Privacy Controls, Legal Archival & Fraud Retention',
                icon: Iconsax.archive_tick,
                body:
                    'You manage data usage and permission preferences directly inside Profile > Account Privacy & Security and device Settings.\n\n'
                    '• Statutory Retention & Fraud Defense: We retain active records while your account remains open. Even after an Account Deletion Request, Haujzo legally retains or anonymizes completed freight manifests, downloadable Waybills, Paystack payment/refund logs, tax records, GPS dispute telemetry, and fraud/ban identifiers for statutory commercial transport, tax, chargeback-defense, and anti-fraud compliance periods.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              _buildDataCard(
                title: '6. Account & Personal Data Deletion Rights',
                icon: Iconsax.trash,
                body:
                    'You may inspect, correct, or request permanent deletion of your Haujzo account at any time:\n\n'
                    '• In-App Deletion: Navigate to Profile > Profile Details > Delete Account, or Account Privacy & Security > Delete Account & Purge Data (requires Google or Email/Password re-authentication).\n'
                    '• Written Request: Email privacy@haujzo.com from your registered email address.\n\n'
                    'Upon verification, active personal identifiers are purged within 30 days, provided no active trips, pending refunds, or unsettled disputes/balances remain.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              Obx(() {
                final cfg = SupportConfigRepository.instance.supportConfig.value;
                return _buildDataCard(
                  title: '7. Data Protection Officer (DPO) Contact',
                  icon: Iconsax.message_question,
                  body:
                      'For privacy inquiries, data access requests, or GDPR / Data Protection Act 843 compliance notices, contact our legal compliance desk:\n\n'
                      'Privacy / DPO Email: privacy@haujzo.com\n'
                      'Support Email: ${cfg.supportEmail}\n'
                      'Hotline: ${cfg.supportPhone}\n'
                      'Emergency Line: ${cfg.emergencyNumber}\n'
                      'Subject: Haujzo Shipper Data Protection Request',
                  cardColor: cardColor,
                  borderColor: borderColor,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                );
              }),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(AvailRoutes.privacySettings),
                  icon: const Icon(Iconsax.security_user, color: AvailColors.primary, size: 18),
                  label: const Text(
                    'Manage Account Privacy & Deletion Controls',
                    style: TextStyle(
                      color: AvailColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AvailColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDataCard({
    required String title,
    required IconData icon,
    required String body,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AvailColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AvailColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: titleColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(fontSize: 12.3, color: bodyColor, height: 1.48)),
        ],
      ),
    );
  }
}
