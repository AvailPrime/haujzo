import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import 'widgets/login_form.dart';
import 'widgets/login_header.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);

    const mobileView = MaxWidthContainer(
      maxWidth: 480,
      alwaysDecorate: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvailLoginHeader(),
            AvailLoginForm(),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: dark ? AvailColors.dark : const Color(0xFFF4F7FB),
      body: SafeArea(
        child: SiteLayout(
          mobile: mobileView,
          tablet: const MaxWidthContainer(
            maxWidth: 480,
            alwaysDecorate: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvailLoginHeader(),
                  AvailLoginForm(),
                ],
              ),
            ),
          ),
        desktop: Container(
          color: dark ? AvailColors.dark : const Color(0xFFF4F7FB),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF132238) : AvailColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        /// Left Brand Hero Panel
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: const BoxDecoration(
                              gradient: AvailColors.navyGradient,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AvailColors.primary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AvailColors.primary.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.truck_fast, color: AvailColors.primary, size: 15),
                                      SizedBox(width: 6),
                                      Text(
                                        'HAUJZO FREIGHT PORTAL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Move Cargo Across Borders With Precision.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        height: 1.25,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Book verified flatbeds, heavy-duty tippers, and refrigerated fleets with real-time GPS telemetry and digital waybills.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                                const Column(
                                  children: [
                                    _HeroFeatureRow(
                                      icon: Iconsax.radar_2,
                                      text: 'Live GPS fleet tracking & ETA telemetry',
                                    ),
                                    SizedBox(height: 8),
                                    _HeroFeatureRow(
                                      icon: Iconsax.verify,
                                      text: 'Verified drivers & insured commercial haulage',
                                    ),
                                    SizedBox(height: 8),
                                    _HeroFeatureRow(
                                      icon: Iconsax.document_text,
                                      text: 'Instant digital waybills & POD verification',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        /// Right Login Form Panel
                        const Expanded(
                          flex: 6,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AvailLoginHeader(),
                                AvailLoginForm(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _HeroFeatureRow extends StatelessWidget {
  const _HeroFeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AvailColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
