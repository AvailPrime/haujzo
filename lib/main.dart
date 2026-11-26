import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'commons/widgets/splash/splash_screen.dart';
import 'bindings/general_bindings.dart';
import 'routes/app_routes.dart';
import 'routes/routes.dart';
import 'utils/constants/text_strings.dart';
import 'utils/theme/theme.dart';
import 'utils/url_strategy/url_strategy.dart';
import 'firebase_options.dart';

void main() async {
  /// -- Configure URL strategy (removes '#' in Web URLs)
  configureUrlStrategy();

  /// -- Widgets Binding
  final WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  /// -- GetX Local Storage
  await GetStorage.init();

  /// -- Await Native Splash
  AvailSplashHelper.preserveSplash(widgetsBinding: widgetsBinding);

  /// -- Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase Initialized Successfully");
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  /// -- Activate Firebase App Check immediately after Firebase initialization
  const String recaptchaSiteKey = '6LfjCCguAAAAABXw5_CmHQo9tWvyOqUbyICJdcUx';

  try {
    var appCheckActivated = false;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
        appleProvider:
            kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
      );
      appCheckActivated = true;
    } else if (kIsWeb && recaptchaSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(recaptchaSiteKey),
      );
      appCheckActivated = true;
    }

    if (appCheckActivated) {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

      if (kDebugMode) {
        try {
          final token = await FirebaseAppCheck.instance.getToken();
          debugPrint('--- FIREBASE APP CHECK TOKEN ---');
          debugPrint('$token');
          debugPrint(
            'Register this debug token in Firebase Console > App Check > Apps > Manage Debug Tokens',
          );
          debugPrint('--------------------------------');
        } catch (e) {
          debugPrint('App Check Debug Token Error: $e');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase App Check Activation Error: $e');
    }
  }

  /// -- Setup Error reporting (Crashlytics on supported native platforms)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// -- Main App
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AvailTexts.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AvailAppTheme.lighttheme,
      darkTheme: AvailAppTheme.darktheme,
      initialBinding: GeneralBindings(),
      initialRoute: AvailRoutes.navigationMenu,
      getPages: AppRoutes.pages,
      defaultTransition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 180),
    );
  }
}
