import 'package:flutter/material.dart';

import '../../../../../utils/constants/colors.dart';


class AvailRideOptionCard extends StatelessWidget {
  const AvailRideOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.oldPrice,
    required this.image,
    required this.isSelected,
    required this.onTap,
    this.tag,
  });

  final String title;
  final String subtitle;
  final String price;
  final String oldPrice;
  final String image;
  final bool isSelected;
  final VoidCallback onTap;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isSelected ? Border.all(color: AvailColors.primary, width: 2) : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Image.asset(image, height: 50, width: 70, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 50)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                          child: Text(tag!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('GHS $price', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('GHS $oldPrice', style: const TextStyle(color: Colors.black38, decoration: TextDecoration.lineThrough, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
