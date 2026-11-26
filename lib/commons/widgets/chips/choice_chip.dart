import '../custom_shapes/containers/circular_container.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class AvailChoiceChip extends StatelessWidget {
  const AvailChoiceChip({
    super.key,
    required this.text,
    required this.selected,
    this.onSelected,
  });

  final String text;
  final bool selected;
  final void Function(bool)? onSelected;

  @override
  Widget build(BuildContext context) {
    final isColor = AvailHelperFunctions.getColor(text) != null;
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
      child: ChoiceChip(
        label: isColor
            ? const SizedBox()
            : SizedBox(
                width: 40,
                child: Text(text, textAlign: TextAlign.center),
              ),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? (isColor ? Colors.white : AvailColors.primary) : null,
          fontWeight: selected ? FontWeight.bold : null,
        ),
        avatar: isColor
            ? AvailCircularContainer(
                width: 50,
                height: 50,
                backgroundColor: AvailHelperFunctions.getColor(text)!)
            : Icon(Iconsax.tick_circle,
                size: 16,
                color: selected ? AvailColors.primary : AvailColors.grey),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        shape: isColor
            ? CircleBorder(
                side: BorderSide(
                  color: selected ? AvailColors.primary : AvailColors.grey,
                  width: selected ? 2 : 1,
                ),
              )
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AvailSizes.cardradiusmd),
                side: BorderSide(
                  color: selected ? AvailColors.primary : AvailColors.grey,
                  width: selected ? 2 : 1,
                ),
              ),
        labelPadding: isColor ? const EdgeInsets.all(0) : const EdgeInsets.symmetric(horizontal: 4),
        padding: isColor ? const EdgeInsets.all(0) : const EdgeInsets.all(0),
        backgroundColor: isColor ? AvailHelperFunctions.getColor(text)! : Colors.white,
        selectedColor: isColor ? AvailHelperFunctions.getColor(text)! : Colors.white,
      ),
    );
  }
}
