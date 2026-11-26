import '../../styles/spacing_styles.dart';
import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/constants/text_strings.dart';
import '../../../utils/helpers/helper_functions.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.image, required this.title, required this.subTitle, required this.onPressed});

  final String image, title, subTitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AvailSpacingStyles.paddingWithAppBarHeight * 2,
            child: Column(
              children: [
                /// Image
                Center(
                  child: SizedBox(
                    height: 200,
                    child: Image(
                      image: AssetImage(image),
                      width: AvailHelperFunctions.screenWidth() * 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: AvailSizes.spacebtwsections),

                /// Title & Subtitle
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AvailSizes.spacebtwitems),
                Text(
                  subTitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AvailSizes.spacebtwsections),

                /// Button
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: onPressed, child: const Text(AvailTexts.aContinue))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
