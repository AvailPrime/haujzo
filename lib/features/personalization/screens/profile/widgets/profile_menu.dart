import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/helpers/helper_functions.dart';

class AvailProfileMenu extends StatelessWidget {
  const AvailProfileMenu({
    super.key,
    this.icon = Iconsax.arrow_right_34,
    this.leadingIcon,
    this.accentColor,
    this.badgeText,
    this.isLocked = false,
    required this.onPressed,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final IconData? leadingIcon;
  final Color? accentColor;
  final String? badgeText;
  final bool isLocked;
  final VoidCallback onPressed;
  final String title, value;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final accent = accentColor ?? AvailColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.035)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: dark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(leadingIcon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: dark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (badgeText != null && badgeText!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value.isNotEmpty ? value : 'Not Set',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: value.isEmpty || value == 'Not Set'
                              ? Colors.grey
                              : (dark ? Colors.white : AvailColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.withValues(alpha: 0.12)
                        : accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: isLocked ? Colors.grey : accent,
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
