import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';

/// A widget for displaying an animated loading indicator with optional text and action button.
class AvailAnimationLoaderWidget extends StatelessWidget {
  /// Default constructor for the TAnimationLoaderWidget.

  /// Parameters:
  /// text: The text to be displayed below the animation.
  /// animation: The path to the Lottie animation file.
  /// showAction: Whether to show an action button below the text.
  /// actionText: The text to be displayed on the action button.
  /// onActionPressed: Callback function to be executed when the action button is pressed.
  const AvailAnimationLoaderWidget({
    super.key,
    required this.text,
    required this.animation,
    this.showAction = false,
    this.actionText,
    this.onActionPressed,
  });

  final String text;
  final String animation;
  final bool showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(animation, width: MediaQuery.of(context).size.width * 0.2, height: MediaQuery.of(context).size.height * 0.2),
          const SizedBox(height: AvailSizes.xxxs),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AvailSizes.xxxs),
          showAction
              ? SizedBox(
            width: 200,
            child: OutlinedButton(
              onPressed: onActionPressed,
              style: OutlinedButton.styleFrom(backgroundColor: AvailColors.dark),
              child: Text(
                actionText!,
                style: Theme.of(context).textTheme.bodyMedium!.apply(color: AvailColors.light),
              ),
            ),
          )
              : const SizedBox(),
        ],
      ),
    );
  }
}
