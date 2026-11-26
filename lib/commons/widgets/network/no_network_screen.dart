import './network_manager.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class NoNetworkScreen extends StatefulWidget {
  const NoNetworkScreen({super.key});

  @override
  State<NoNetworkScreen> createState() => _NoNetworkScreenState();
}

class _NoNetworkScreenState extends State<NoNetworkScreen> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AvailSizes.defaultspace),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Iconsax.wifi,
                size: 100,
                color: AvailColors.primary,
              ),
              const SizedBox(height: AvailSizes.spacebtwsections),
              Text(
                'No Internet Connection',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AvailSizes.spacebtwitems),
              Text(
                'Please check your internet connection and try again to continue your shopping experience.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AvailSizes.spacebtwsections),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final isConnected = await NetworkManager.instance.isConnected();
                    if (isConnected) {
                      Get.back();
                    } else {
                      // Optionally show a toast if still no connection
                    }
                  },
                  child: const Text('Refresh'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
