import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../commons/widgets/network/network_manager.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../data/repositories/user/app_user_repository.dart';
import '../../../../utils/constants/country_codes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/routes.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/popups/full_screen_loader.dart';
import '../../../shop/models/user_account_model.dart';
import '../../screens/signup/verify_email.dart';


class SignupController extends GetxController {
  static SignupController get instance => Get.find();

  final hidePassword = true.obs; 
  final privacyPolicy = false.obs; 
  
  // Account Type Selection: 'individual' vs 'business'
  final accountType = 'individual'.obs;

  final firstName = TextEditingController(); 
  final lastName = TextEditingController(); 
  final email = TextEditingController(); 
  final username = TextEditingController(); 
  final password = TextEditingController(); 
  final phoneNumber = TextEditingController(); 
  final licensePlate = TextEditingController();
  final selectedVehicleType = 'motor'.obs;

  // Business Account Fields
  final companyName = TextEditingController();
  final registrationNumber = TextEditingController();
  final businessAddress = TextEditingController();
  
  final selectedCountry = ''.obs; 
  final selectedCountryCode = ''.obs; 
  final selectedCountryObject = Rx<AvailCountry?>(AvailCountry.africanCountries.firstWhere((c) => c.name == 'Ghana', orElse: () => AvailCountry.africanCountries.first));

  @override
  void onInit() {
    super.onInit();
    ever(selectedCountryObject, (AvailCountry? country) {
      if (country != null) {
        selectedCountry.value = country.name;
        selectedCountryCode.value = country.code;
      }
    });
  }
  
  GlobalKey<FormState> signupFormKey = GlobalKey<FormState>();

  void signup() async {
    try {
      final isBusiness = accountType.value == 'business';
      final loadingText = isBusiness ? 'Creating your Business Shipper account...' : 'Creating your account...';
      
      AvailFullScreenLoader.openLoadingDialog(loadingText, AvailImages.loadingAnimation);

      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      if (!signupFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      if (!privacyPolicy.value) {
        AvailLoaders.warningSnackBar(title: 'Accept Privacy Policy', message: 'Please accept the privacy policy to continue.');
        AvailFullScreenLoader.stopLoading();
        return;
      }

      final userCredential = await AuthenticationRepository.instance.registerWithEmailAndPassword(email.text.trim(), password.text.trim());

      final phoneCode = selectedCountryObject.value?.phoneCode ?? '+233';
      var cleanPhone = phoneNumber.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      final formattedPhone = '$phoneCode $cleanPhone';

      final newUser = UserAccountModel(
        id: userCredential.user!.uid,
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        username: username.text.trim().isNotEmpty ? username.text.trim() : UserAccountModel.generateUsername('${firstName.text.trim()} ${lastName.text.trim()}'),
        email: email.text.trim(),
        phoneNumber: formattedPhone,
        profilePicture: '',
        country: selectedCountry.value,
        countryCode: selectedCountryCode.value,
        role: isBusiness ? 'business_shipper' : 'shipper',
        accountType: accountType.value,
        companyName: isBusiness ? companyName.text.trim() : '',
        registrationNumber: isBusiness ? registrationNumber.text.trim() : '',
        businessAddress: isBusiness ? businessAddress.text.trim() : '',
        verificationStatus: 'unverified',
        verificationType: isBusiness ? 'kyb' : 'kyc',
      );

      final userRepository = Get.put(AppUserRepository());
      await userRepository.saveUserRecord(newUser);
      
      AvailFullScreenLoader.stopLoading();
      final successMsg = isBusiness
          ? 'Your Business Shipper account has been created! Please verify your email.'
          : 'Your account has been created! Please verify your email.';
      AvailLoaders.successSnackBar(title: 'Congratulations', message: successMsg);
      
      Get.toNamed(AvailRoutes.verifyEmail, arguments: email.text.trim());
    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Signup Failed', message: e.toString());
    }
  }
}
