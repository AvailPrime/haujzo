import './widgets/onboarding_dot_navigation.dart';
import './widgets/onboarding_next_button.dart';
import './widgets/onboarding_page.dart';
import './widgets/onboarding_skip.dart';
import '../../../../utils/constants/text_strings.dart';
import 'package:flutter/material.dart';
import '../../../../utils/constants/image_strings.dart';
import 'package:get/get.dart';
import '../../controllers/onboarding/onboarding_controller.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';

class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnBoardingController());
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SiteLayout(
          mobile: Stack(
            children: [
              /// Horizontal Scrollable Page
              PageView(
                controller: controller.pageController,
                onPageChanged: controller.updatePageIndicator,
                children: const [
                  OnBoardingPage(
                      image: AvailImages.onBoardingImage1,
                      title: AvailTexts.onboardingtitle1,
                      subtitle: AvailTexts.onboardingsubtitle1),
                  OnBoardingPage(
                      image: AvailImages.onBoardingImage2,
                      title: AvailTexts.onboardingtitle2,
                      subtitle: AvailTexts.onboardingsubtitle2),
                  OnBoardingPage(
                      image: AvailImages.onBoardingImage3,
                      title: AvailTexts.onboardingtitle3,
                      subtitle: AvailTexts.onboardingsubtitle3),
                ],
              ),

              /// Skip Button
              const OnBoardingSkip(),

              /// Dot Navigation SmoothPageIndicator
              const OnBoardingDotNavigation(),

              /// Circulation Button
              const OnBoardingNextButton()
            ],
          ),
          desktop: MaxWidthContainer(
            child: Stack(
              children: [
                /// Horizontal Scrollable Page
                PageView(
                  controller: controller.pageController,
                  onPageChanged: controller.updatePageIndicator,
                  children: const [
                    OnBoardingPage(
                        image: AvailImages.onBoardingImage1,
                        title: AvailTexts.onboardingtitle1,
                        subtitle: AvailTexts.onboardingsubtitle1),
                    OnBoardingPage(
                        image: AvailImages.onBoardingImage2,
                        title: AvailTexts.onboardingtitle2,
                        subtitle: AvailTexts.onboardingsubtitle2),
                    OnBoardingPage(
                        image: AvailImages.onBoardingImage3,
                        title: AvailTexts.onboardingtitle3,
                        subtitle: AvailTexts.onboardingsubtitle3),
                  ],
                ),

                /// Skip Button
                const OnBoardingSkip(),

                /// Dot Navigation SmoothPageIndicator
                const OnBoardingDotNavigation(),

                /// Circulation Button
                const OnBoardingNextButton()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
