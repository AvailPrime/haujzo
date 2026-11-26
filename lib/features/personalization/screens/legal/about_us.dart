import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/helpers/helper_functions.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
      title: 'About Haujzo',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isWide
            ? null
            : const AvailAppbar(
                title: Text(
                  'About Haujzo',
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
              // Brand Hero Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: AvailColors.navyGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AvailColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.asset(
                        AvailImages.appLogo,
                        width: 210,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Iconsax.truck_fast,
                          size: 40,
                          color: AvailColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'HAUJZO',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Shippers & Cargo Owners Edition',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AvailColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Version 1.0.1 • Build 2026.11',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Mission Statement
              _buildInfoCard(
                title: 'Our Mission',
                icon: Iconsax.radar_2,
                content:
                    'To empower businesses, manufacturers, importers, and individual cargo owners with on-demand access to verified commercial trucks, transparent itemized freight pricing, real-time GPS tracking, and accountable digital settlements.',
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                bodyColor: bodyColor,
              ),

              const SizedBox(height: 12),

              // 3-Tier Ecosystem Explanation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.element_3, color: titleColor, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'The Haujzo Freight Ecosystem',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildEcosystemItem(
                      tag: 'Haujzo',
                      role: 'Shippers & Cargo Owners',
                      desc:
                          'Used by businesses, manufacturers, importers, and individuals to dispatch verified commercial trucks, configure multi-stop manifests, track shipments live, generate PDF waybills, and verify Proof of Delivery (POD).',
                      color: AvailColors.primary,
                      bodyColor: bodyColor,
                    ),
                    Divider(height: 20, color: borderColor),
                    _buildEcosystemItem(
                      tag: 'Haujzo Pro',
                      role: 'Drivers & Fleet Carriers',
                      desc:
                          'Used by verified independent owner-operators, corporate fleet managers, and company roster drivers to accept freight loads, navigate corridors, enforce 500m geofenced stages, and settle earnings.',
                      color: Colors.amber.shade700,
                      bodyColor: bodyColor,
                    ),
                    Divider(height: 20, color: borderColor),
                    _buildEcosystemItem(
                      tag: 'Haujzo Portal',
                      role: 'Operations & Compliance Hub',
                      desc:
                          'The central dispatch & compliance command hub managing dual-gate KYC/KYB approvals, live corridor pricing matrices, fleet safety audits, Paystack refunds/payouts, and 24/7 dispute resolution.',
                      color: Colors.purple.shade400,
                      bodyColor: bodyColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Core Platform Capabilities
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.cpu_setting, color: titleColor, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Core Platform Capabilities',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _capRow(
                      Iconsax.routing,
                      'Multi-Stop Routing & Smart Corridors',
                      'Interactive map pinning, reorderable intermediate stops, 20ft/40ft/Twin ISO container controls, and offline corridor routing fallback.',
                      dark,
                      titleColor,
                      bodyColor,
                    ),
                    _capRow(
                      Iconsax.shield_tick,
                      'Didit KYC/KYB + Operations Gate',
                      'Biometric liveness, government ID and corporate TIN verification paired with Haujzo Portal review.',
                      dark,
                      titleColor,
                      bodyColor,
                    ),
                    _capRow(
                      Iconsax.wallet_check,
                      'Paystack Escrow, Refunds & Waybill PDFs',
                      'Upfront multi-currency fare breakdowns, secure Paystack Mobile Money/Card settlement, protected cancellation refunds, and instant PDF waybills.',
                      dark,
                      titleColor,
                      bodyColor,
                    ),
                    _capRow(
                      Iconsax.radar_2,
                      'Live GPS Tracking & 500m Geofenced POD',
                      'Real-time 3D truck tracking, driver arrival alerts, and geofenced delivery handover verification.',
                      dark,
                      titleColor,
                      bodyColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Legal Shortcuts
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.toNamed(AvailRoutes.termsOfService),
                      icon: Icon(Iconsax.document_text, size: 16, color: titleColor),
                      label: Text(
                        'Terms',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.toNamed(AvailRoutes.privacyPolicy),
                      icon: Icon(Iconsax.shield_security, size: 16, color: titleColor),
                      label: Text(
                        'Privacy',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.toNamed(AvailRoutes.helpSupport),
                      icon: Icon(Iconsax.support, size: 16, color: titleColor),
                      label: Text(
                        'Support',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _capRow(
    IconData icon,
    String title,
    String subtitle,
    bool dark,
    Color titleColor,
    Color bodyColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: dark ? AvailColors.primary.withValues(alpha: 0.16) : AvailColors.orangeSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AvailColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.8, color: titleColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11.8, color: bodyColor, height: 1.38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: TextStyle(fontSize: 12.6, color: bodyColor, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildEcosystemItem({
    required String tag,
    required String role,
    required String desc,
    required Color color,
    required Color bodyColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6, right: 10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    tag,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                  ),
                  Text(
                    '($role)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 12.3, color: bodyColor, height: 1.38)),
            ],
          ),
        ),
      ],
    );
  }
}
