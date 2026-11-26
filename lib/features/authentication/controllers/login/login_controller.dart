import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../commons/widgets/network/network_manager.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/constants/image_strings.dart';
import '../../../../utils/popups/full_screen_loader.dart';
import '../../../personalization/controllers/user_controller.dart';

class LoginController extends GetxController {
  //Variables
  final rememberMe = false.obs;
  final hidePassword = true.obs;
  final localStorage = GetStorage();
  final email = TextEditingController();
  final password = TextEditingController();
  GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  
  final userController = UserController.instance;

  @override
  void onInit() {
    // Read from GetStorage safely — if null, use empty string
    email.text = localStorage.read('REMEMBER_ME_MAIL') ?? "";
    password.text = localStorage.read('REMEMBER_ME_PASSWORD') ?? "";
    super.onInit();
  }/// this will store the email and password in the local storage if Remember me is true

  /// Login function (and i named it loginWithEmailAndPassword instead of emailAndPasswordSignIn)

  Future<void> loginWithEmailAndPassword() async {
    try {
      // Start Loading
      AvailFullScreenLoader.openLoadingDialog(
          'Logging you in...', AvailImages.loadingAnimation);

      // Check internet connectivity
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Form validation
      if (!loginFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Policy Privacy Check
      if (rememberMe.value) {
        localStorage.write('REMEMBER_ME_MAIL', email.text.trim());
        localStorage.write('REMEMBER_ME_PASSWORD', password.text.trim());
      }

      // Login user using email and password
      final userCredential =
          await AuthenticationRepository.instance.loginWithEmailAndPassword(
        email.text.trim(),
        password.text.trim(),
      );


      // Remover loader
      AvailFullScreenLoader.stopLoading();

      // Redirect
      await AuthenticationRepository.instance.onLoginSuccess();
      AuthenticationRepository.instance.screenRedirect();


    } catch (e) {
      // Remover loader
      AvailFullScreenLoader.stopLoading();
      // Show some Generic Error to the user
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    }
  }

  /// Google Authentication SignIn
  Future<void> googleSignIn() async {
    try{
      // Start Loading
      AvailFullScreenLoader.openLoadingDialog('Logging you in...', AvailImages.loadingAnimation);

      // Check internet connectivity
      final isConnected = await NetworkManager.instance.isConnected();
      if(!isConnected){
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Google Authentication
      final userCredentials = await AuthenticationRepository.instance.signInWithGoogle();

      if (userCredentials == null) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      // Save user records
      await userController.saveUserRecord(userCredentials);

      // Trigger Data Migration
      await AuthenticationRepository.instance.onLoginSuccess();

      // Remove loader
      AvailFullScreenLoader.stopLoading();

      // Redirect User
      AuthenticationRepository.instance.screenRedirect();

    }catch(e){
      // Remove loader
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    }
  }
}
