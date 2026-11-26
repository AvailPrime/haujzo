import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../../utils/constants/colors.dart';

class AvailRecentLocationTile extends StatelessWidget {
  const AvailRecentLocationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AvailColors.lightgrey,
          shape: BoxShape.circle,
        ),
        child: const Icon(Iconsax.clock, size: 20, color: Colors.black87),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54),
      ),
    );
  }
}
