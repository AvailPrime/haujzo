import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../controllers/customer/customer_home_controller.dart';
import '../../../../personalization/controllers/localization_controller.dart';

class RideSelectionSheet extends StatelessWidget {
  const RideSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerHomeController.instance;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : Colors.black87;
    final subTextColor = dark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'CARGO MANIFEST & TRUCK CONFIG',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2, color: subTextColor),
                ),
              ),
              const SizedBox(height: 15),

              // Truck Options Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Obx(() => Row(
                  children: [
                    Expanded(child: _buildTruckCard('Mini Truck', '1.5T', Iconsax.truck, controller, dark)),
                    Expanded(child: _buildTruckCard('Box Truck', '3.5T', Iconsax.truck_fast, controller, dark)),
                    Expanded(child: _buildTruckCard('Flatbed', '10T', Iconsax.truck_tick, controller, dark)),
                    Expanded(child: _buildTruckCard('Trailer', '25T', Iconsax.truck_remove, controller, dark)),
                  ],
                )),
              ),
              const SizedBox(height: 20),

              // Cargo Stats (Weight & Container)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Weight Input
                    Expanded(
                      flex: 2,
                      child: _buildManifestInput(
                        label: 'GROSS WEIGHT (KG)',
                        dark: dark,
                        child: Row(
                          children: [
                            const Icon(Iconsax.weight, size: 16, color: AvailColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor),
                                decoration: const InputDecoration(hintText: '0.00', border: InputBorder.none, isDense: true),
                                onChanged: (value) {
                                  final weight = double.tryParse(value) ?? 0.0;
                                  controller.loadWeight.value = weight;
                                  final distanceStr = controller.estimatedDistance.value.replaceAll(' km', '');
                                  final distance = double.tryParse(distanceStr) ?? 0.0;
                                  controller.calculatePrice(distance);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Container Size Dropdown
                    Expanded(
                      flex: 2,
                      child: _buildManifestInput(
                        label: 'UNIT SIZE',
                        dark: dark,
                        child: Obx(() => DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedContainerSize.value,
                            isExpanded: true,
                            dropdownColor: dark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'monospace'),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                controller.selectedContainerSize.value = newValue;
                                final distanceStr = controller.estimatedDistance.value.replaceAll(' km', '');
                                final distance = double.tryParse(distanceStr) ?? 0.0;
                                controller.calculatePrice(distance);
                              }
                            },
                            items: <String>['None', '20ft', '40ft'].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                          ),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Shipping Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildManifestInput(
                  label: 'CARGO DESCRIPTION',
                  dark: dark,
                  child: TextField(
                    controller: controller.loadDescriptionController,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                    decoration: const InputDecoration(
                      hintText: 'e.g. ELECTRONICS, CONSTRUCTION MAT...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Footer / Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL ESTIMATE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: subTextColor)),
                        Obx(() => Text(
                          LocalizationController.instance.getFormattedPrice(controller.calculatedPrice.value),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: dark ? Colors.white : AvailColors.secondary),
                        )),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await controller.saveBooking();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        decoration: BoxDecoration(
                          color: AvailColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: AvailColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Text('DISPATCH JOB', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
                            SizedBox(width: 8),
                            Icon(Iconsax.arrow_right_3, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTruckCard(String title, String cap, IconData icon, CustomerHomeController controller, bool dark) {
    final isSelected = controller.selectedTruckType.value == title;
    return GestureDetector(
      onTap: () {
        controller.selectedTruckType.value = title;
        final distanceStr = controller.estimatedDistance.value.replaceAll(' km', '');
        final distance = double.tryParse(distanceStr) ?? 0.0;
        controller.calculatePrice(distance);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AvailColors.secondary : (dark ? const Color(0xFF1E293B) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AvailColors.secondary : (dark ? const Color(0xFF334155) : Colors.grey.shade200)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: isSelected ? AvailColors.primary : (dark ? Colors.white70 : Colors.black45)),
            const SizedBox(height: 6),
            Text(title.split(' ')[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: isSelected ? Colors.white : (dark ? Colors.white70 : Colors.black45))),
            Text(cap, style: TextStyle(fontSize: 8, color: isSelected ? Colors.white70 : (dark ? Colors.white54 : Colors.black38))),
          ],
        ),
      ),
    );
  }

  Widget _buildManifestInput({required String label, required Widget child, required bool dark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: dark ? Colors.white60 : Colors.black45, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E293B) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: dark ? const Color(0xFF334155) : Colors.grey.shade200),
          ),
          child: child,
        ),
      ],
    );
  }
}
