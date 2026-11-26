import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';
import './widgets/signup_form.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = dark ? Colors.grey.shade400 : Colors.grey.shade600;
    final isWide = SiteLayout.isWideScreen(context);

    return Scaffold(
      backgroundColor: dark ? AvailColors.dark : const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: dark ? Colors.white : Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 20,
            vertical: isWide ? 16 : 8,
          ),
          child: ResponsiveCenter(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Haujzo Brand Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AvailColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AvailColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.truck_fast, size: 14, color: AvailColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'HAUJZO FREIGHT NETWORK',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AvailColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Headline & Subtitle
                Text(
                  'Create Shipper Account',
                  style: TextStyle(
                    fontSize: isWide ? 28 : 24,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join cargo owners and enterprises booking verified container chassis, tippers, and heavy haulage trucks across West Africa.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: subtitleColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AvailSizes.spacebtwsections),

                // 3. Signup Form Container
                Container(
                  padding: EdgeInsets.all(isWide ? 28 : 18),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const AvailSignupFrom(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
