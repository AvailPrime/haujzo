import 'package:flutter/material.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';

class AvailPromoCard extends StatelessWidget {
  const AvailPromoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AvailSizes.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF), // Soft lavender/blue
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AvailColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AvailColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AvailSizes.spacebtwitems),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.black54, size: 20),
          ),
        ],
      ),
    );
  }
}
