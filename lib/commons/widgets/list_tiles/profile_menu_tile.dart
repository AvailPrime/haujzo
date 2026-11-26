import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/helpers/helper_functions.dart';

class AvailProfileMenuTile extends StatelessWidget {
  const AvailProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final accent = iconColor ?? AvailColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                /// -- Rounded Squircle Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: dark ? 0.22 : 0.14),
                        accent.withValues(alpha: dark ? 0.10 : 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: accent.withValues(alpha: dark ? 0.35 : 0.22),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 14),

                /// -- Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : AvailColors.textPrimary,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (badgeText != null && badgeText!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accent)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (badgeColor ?? accent)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor ?? accent,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: dark
                              ? Colors.grey.shade400
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                /// -- Trailing Widget or Subtle Chevron Pill
                trailing ??
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Iconsax.arrow_right_3,
                        size: 15,
                        color: dark
                            ? Colors.grey.shade400
                            : const Color(0xFF64748B),
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
