import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../personalization/controllers/user_controller.dart';

class FreightHomeHeader extends StatelessWidget {
  const FreightHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = UserController.instance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AvailSizes.lg, vertical: 20),
      decoration: const BoxDecoration(
        color: AvailColors.secondary, // Professional dark/industrial color
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOGISTICS DISPATCH',
                    style: TextStyle(
                      color: AvailColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Text(
                    userController.user.value.fullName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace', // Industrial feel
                    ),
                  )),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Iconsax.notification, color: AvailColors.primary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem('ACTIVE JOBS', '03'),
              const SizedBox(width: 30),
              _buildStatItem('FLEET NEARBY', '12'),
              const SizedBox(width: 30),
              _buildStatItem('SYSTEM', 'ONLINE', color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
