import 'dart:async';
import '../../../commons/widgets/loader/loaders.dart';
import '../../../utils/constants/image_strings.dart';
import '../../../utils/constants/sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../commons/widgets/network/network_manager.dart';
import '../../../data/repositories/authentication/authentication_repository.dart';
import '../../shop/models/user_account_model.dart';
import '../../../data/repositories/user/app_user_repository.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../../../routes/routes.dart';
import '../../authentication/screens/login/login.dart';
import '../screens/profile/widgets/re_authenticate_user_login_form.dart';

class UserController extends GetxController {
  static UserController get instance => Get.find();

  final profileLoading = false.obs;
  final imageUploading = false.obs;
  Rx<UserAccountModel> user = UserAccountModel.empty().obs;

  final hidePassword = false.obs;
  final verifyEmail = TextEditingController();
  final verifyPassword = TextEditingController();
  
  final userRepository = AppUserRepository.instance;
  final authRepository = AuthenticationRepository.instance;
  
  GlobalKey<FormState> reAuthFormKey = GlobalKey<FormState>();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStreamSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchUserRecord();
    _startUserStream();
  }

  @override
  void onClose() {
    _userStreamSubscription?.cancel();
    super.onClose();
  }

  void _startUserStream() {
    _userStreamSubscription?.cancel();
    final uid = authRepository.authUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _userStreamSubscription = FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          user.value = UserAccountModel.fromSnapshot(snapshot);
          user.refresh();
        }
      });
    }
  }

  Future<void> refreshUserSession() async {
    await fetchUserRecord();
    _startUserStream();
  }

  void clearUserSession() {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
    user.value = UserAccountModel.empty();
  }

  /// Fetch User Record
  Future<void> fetchUserRecord() async {
    try {
      profileLoading.value = true;
      final user = await userRepository.fetchUserDetails();
      this.user(user);

      if (kReleaseMode &&
          user.id.isNotEmpty &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        FirebaseCrashlytics.instance.setUserIdentifier(user.id);
      }
    } catch (e) {
      user(UserAccountModel.empty());
    } finally {
      profileLoading.value = false;
    }
  }

  /// Save user records from any registration provider
  Future<void> saveUserRecord(UserCredential? userCredential) async {
    try {
      // First update user Rx and check if user data is already stored.
      await fetchUserRecord();

      // If user data is already stored, check if role needs update (optional) or return
      if (user.value.id.isEmpty) {
        if (userCredential != null) {
          // Convert name to firstname and lastname
          final nameParts = UserAccountModel.nameParts(
            userCredential.user!.displayName ?? '',
          );
          final username = UserAccountModel.generateUsername(
            userCredential.user!.displayName ?? '',
          );

          // Map the user data - Default role to 'shipper' for this app
          final newUser = UserAccountModel(
            id: userCredential.user!.uid,
            firstName: nameParts[0],
            lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            username: username,
            email: userCredential.user!.email ?? '',
            phoneNumber: userCredential.user!.phoneNumber ?? '',
            profilePicture: userCredential.user!.photoURL ?? '',
            role: 'shipper',
          );
          
          // Save user records
          await userRepository.saveUserRecord(newUser);
          
          // Update local Rx user
          user.value = newUser;
        }
      }
    } catch (e) {
      AvailLoaders.warningSnackBar(
        title: 'Data not saved',
        message:
            'Something went while saving your information. you can re-save your data in your profile',
      );
    }
  }

  /// Delete Account warning
  void deleteAccountWarningPop() {
    Get.defaultDialog(
      contentPadding: EdgeInsets.all(AvailSizes.sm),
      title: 'Delete Account',
      middleText:
          'Are you sure you want to delete your account permanently? This action is not reversible.',
      confirm: ElevatedButton(
        onPressed: () async {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }
          deleteUserAccount();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AvailSizes.lg),
          child: Text('Delete'),
        ),
      ),
      cancel: OutlinedButton(
        child: const Text('Cancel'),
        onPressed: () {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          } else if (Get.overlayContext != null) {
            Navigator.of(Get.overlayContext!).pop();
          }
        },
      ),
    );
  }

  /// Logout account warning
  void logOutAccountWarningPop() {
    Get.defaultDialog(
      contentPadding: const EdgeInsets.all(AvailSizes.sm),
      title: 'Logout',
      middleText: 'Are you sure you want to logout your account?',
      confirm: ElevatedButton(
        onPressed: () async {
          try {
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            await authRepository.logout();
          } catch (e) {
            AvailLoaders.errorSnackBar(
              title: 'Logout Failed',
              message: e.toString(),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AvailColors.primary,
          side: const BorderSide(color: AvailColors.primary),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AvailSizes.lg),
          child: Text('Logout'),
        ),
      ),
      cancel: OutlinedButton(
        child: const Text('Cancel'),
        onPressed: () {
          if (Get.isDialogOpen ?? false) {
            Get.back();
          } else if (Get.overlayContext != null) {
            Navigator.of(Get.overlayContext!).pop();
          }
        },
      ),
    );
  }

  /// Delete User Account
  void deleteUserAccount() async {
    try {
      AvailFullScreenLoader.openLoadingDialog(
        'Processing...',
        AvailImages.loadingAnimation,
      );
      // First re-authenticate user
      final auth = AuthenticationRepository.instance;
      final providers = auth.authUser?.providerData.map((e) => e.providerId).toList() ?? [];
      if (providers.contains('google.com')) {
        final credential = await auth.signInWithGoogle();
        if (credential == null) {
          AvailFullScreenLoader.stopLoading();
          return;
        }
        await auth.deleteAccount();
        AvailFullScreenLoader.stopLoading();
        Get.offAllNamed(AvailRoutes.signIn);
      } else if (providers.contains('password')) {
        AvailFullScreenLoader.stopLoading();
        Get.to(
          () => const ReAuthLoginForm(),
          routeName: '/re-authenticate',
        );
      } else {
        await auth.deleteAccount();
        AvailFullScreenLoader.stopLoading();
        Get.offAllNamed(AvailRoutes.signIn);
      }
    } catch (e) {
      if (AvailFullScreenLoader.isLoading()) {
        AvailFullScreenLoader.stopLoading();
      }
      AvailLoaders.errorSnackBar(title: 'Oh Snap!', message: e.toString());
    }
  }

  /// == RE-AUTHENTICATE before deleting
  Future<void> reAuthenticateEmailAndPasswordUser() async {
    try {
      AvailFullScreenLoader.openLoadingDialog(
        'Processing...',
        'Images.deleteAnimation',
      );
      // Check Internet
      if (!(await NetworkManager.instance.isConnected())) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      if (!reAuthFormKey.currentState!.validate()) {
        AvailFullScreenLoader.stopLoading();
        return;
      }

      await AuthenticationRepository.instance
          .reAuthenticateWithEmailAndPassword(
            verifyEmail.text.trim(),
            verifyPassword.text.trim(),
          );
      await AuthenticationRepository.instance.deleteAccount();

      AvailFullScreenLoader.stopLoading();
      Get.offAllNamed(AvailRoutes.signIn);
    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.warningSnackBar(title: 'Oh Snap!', message: e.toString());
    }
  }

  /// Upload user profile picture
  Future<void> uploadProfilePicture() async {
    try {
      final pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxHeight: 512,
        maxWidth: 512,
      );

      if (pickedImage != null) {
        // Upload image using your repository
        imageUploading.value = true;
        final imageUrl = await userRepository.uploadImage(
          'Users/Images/Profile',
          pickedImage,
        );

        // Update user record in Firestore
        Map<String, dynamic> json = {
          'profilePicture': imageUrl,
          'ProfilePicture': imageUrl,
        };
        await userRepository.updateSingleField(json);

        // Update the user object in memory
        user.value.profilePicture = imageUrl;
        user.refresh();

        AvailLoaders.successSnackBar(
          title: 'Success',
          message: 'Your profile picture has been successfully updated!',
        );
      } else {
        AvailLoaders.errorSnackBar(
          title: 'No Image',
          message: 'Please select an image to upload.',
        );
      }
    } catch (e) {
      AvailLoaders.errorSnackBar(
        title: 'Oh Snap!',
        message: 'Something went wrong: $e',
      );
    }finally{
      imageUploading.value = false;
    }
  }

  /// Update Gender
  Future<void> updateGender(String gender) async {
    try {
      // Update user record
      Map<String, dynamic> json = {'gender': gender};
      await userRepository.updateSingleField(json);

      // Update the user object in memory
      user.value.gender = gender;
      user.refresh();
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Oh Snap!', message: 'Something went wrong while updating gender: $e');
    }
  }
}
