import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_auth;
import '../../../commons/widgets/splash/splash_screen.dart';

import '../../../features/personalization/controllers/address_controller.dart';
import '../../../features/personalization/controllers/user_controller.dart';
import '../../../navigation_menu.dart';
import '../../../utils/exceptions/firebase_auth_exception.dart';
import '../../../utils/exceptions/firebase_exception.dart';
import '../../../utils/exceptions/platform_exception.dart';
import '../../../features/authentication/screens/login/login.dart';
import '../../../features/authentication/screens/signup/verify_email.dart';

import '../../../routes/routes.dart';

class AuthenticationRepository extends GetxController {
  static AuthenticationRepository get instance => Get.find();

  final deviceStorage = GetStorage();
  final _auth = FirebaseAuth.instance;
  final g_auth.GoogleSignIn _googleSignIn = g_auth.GoogleSignIn(
    clientId: kIsWeb
        ? '674897217546-29ovlhe4snqhllt8t8qccgh6e6clfpbn.apps.googleusercontent.com'
        : null,
    serverClientId: kIsWeb
        ? null
        : '674897217546-29ovlhe4snqhllt8t8qccgh6e6clfpbn.apps.googleusercontent.com',
  );

  User? get authUser => _auth.currentUser;

  @override
  void onReady() {
    AvailSplashHelper.removeSplash();
    screenRedirect();
  }

  Future<void> screenRedirect() async {
    final user = _auth.currentUser;

    if (kIsWeb) {
      final current = Get.currentRoute;
      const publicRoutes = {
        AvailRoutes.termsOfService,
        AvailRoutes.privacyPolicy,
        AvailRoutes.aboutUs,
        AvailRoutes.helpSupport,
        AvailRoutes.signIn,
        AvailRoutes.signup,
        AvailRoutes.forgotPassword,
        AvailRoutes.resetPassword,
        AvailRoutes.noNetwork,
      };

      if (user == null && publicRoutes.contains(current)) {
        return;
      }

      const authRoutes = {
        AvailRoutes.signIn,
        AvailRoutes.signup,
        AvailRoutes.forgotPassword,
        AvailRoutes.resetPassword,
        AvailRoutes.onBoarding,
      };

      if (user != null &&
          user.emailVerified &&
          current.isNotEmpty &&
          current != '/' &&
          current != AvailRoutes.navigationMenu &&
          !authRoutes.contains(current)) {
        return;
      }
    }

    if (user != null) {
      if (user.emailVerified) {
        Get.offAllNamed(AvailRoutes.navigationMenu);
      } else {
        Get.offAllNamed(AvailRoutes.verifyEmail, arguments: user.email);
      }
    } else {
      Get.offAllNamed(AvailRoutes.signIn);
    }
  }

  Future<UserCredential> loginWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AvailFirebaseAuthException(e.code).message;
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AvailFirebaseAuthException(e.code).message;
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AvailFirebaseAuthException(e.code).message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AvailFirebaseAuthException(e.code).message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final g_auth.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final g_auth.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw 'Google Sign-In failed: $e';
    }
  }

  Future<void> reAuthenticateWithEmailAndPassword(String email, String password) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
      await _auth.currentUser?.reauthenticateWithCredential(credential);
    } catch (e) {
      throw 'Re-authentication failed';
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      throw 'Delete account failed';
    }
  }

  Future<void> onLoginSuccess() async {
    if (Get.isRegistered<UserController>()) {
      await UserController.instance.refreshUserSession();
    }
    if (Get.isRegistered<AddressController>()) {
      await AddressController.instance.loadUserAddresses();
    }
    if (Get.isRegistered<NavigationController>()) {
      NavigationController.instance.selectedIndex.value = 0;
    }
  }

  Future<void> logout() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('GoogleSignIn signOut skipped: $e');
      }

      await _auth.signOut();

      if (Get.isRegistered<UserController>()) {
        UserController.instance.clearUserSession();
      }
      if (Get.isRegistered<NavigationController>()) {
        NavigationController.instance.selectedIndex.value = 0;
      }

      Get.offAllNamed(AvailRoutes.signIn);
    } on FirebaseAuthException catch (e) {
      throw AvailFirebaseAuthException(e.code).message;
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } catch (e) {
      throw 'Logout failed. Please try again.';
    }
  }
}
