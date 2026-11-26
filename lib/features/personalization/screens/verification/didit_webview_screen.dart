import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../utils/constants/colors.dart';
import '../../controllers/verification_controller.dart';

class DiditWebViewScreen extends StatefulWidget {
  const DiditWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.isKyb = false,
    this.vendorSessionId,
  });

  final String url;
  final String title;
  final bool isKyb;
  final String? vendorSessionId;

  @override
  State<DiditWebViewScreen> createState() => _DiditWebViewScreenState();
}

class _DiditWebViewScreenState extends State<DiditWebViewScreen> {
  late final WebViewController webViewController;
  bool isLoading = true;
  Worker? _verificationWorker;

  @override
  void initState() {
    super.initState();

    debugPrint('[DIDIT WEBVIEW INIT] Loading URL: ${widget.url} | Track: ${widget.isKyb ? "KYB" : "KYC"} | VendorSession: ${widget.vendorSessionId}');

    // 1. Listen for real-time Firestore approval for this specific track
    if (Get.isRegistered<VerificationController>()) {
      final controller = VerificationController.instance;
      final initialVerified = widget.isKyb
          ? controller.userModel.value.kybVerified
          : controller.userModel.value.kycVerified;

      _verificationWorker = ever(controller.userModel, (user) {
        final isVerified = widget.isKyb ? user.kybVerified : user.kycVerified;
        final trackStatus = widget.isKyb ? user.kybStatus.toLowerCase() : user.kycStatus.toLowerCase();
        final isDeclined = trackStatus == 'declined' || trackStatus == 'rejected' || user.verificationStatus.toLowerCase() == 'declined';

        // Only pop if it actually transitioned to approved from a non-approved state during this session
        if (!initialVerified && (isVerified || trackStatus == 'approved')) {
          if (mounted) {
            AvailLoaders.successSnackBar(
              title: widget.isKyb ? 'Corporate KYB Approved' : 'Identity KYC Approved',
              message: widget.isKyb
                  ? 'Your company credentials have been verified via Didit!'
                  : 'Your identity has been verified via Didit!',
            );
            Navigator.of(context).pop();
          }
        } else if (isDeclined) {
          if (mounted) {
            AvailLoaders.errorSnackBar(
              title: widget.isKyb ? 'Corporate KYB Declined' : 'Identity KYC Declined',
              message: user.rejectionReason.isNotEmpty
                  ? user.rejectionReason
                  : 'Automated verification was declined. Please check your documents and try again.',
            );
            Navigator.of(context).pop();
          }
        }
      });
    }

    // 2. Initialize WebViewController
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.105 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[DIDIT WEBVIEW PAGE START] $url');
            if (mounted) setState(() => isLoading = true);
          },
          onPageFinished: (String url) {
            debugPrint('[DIDIT WEBVIEW PAGE FINISHED] $url');
            if (mounted) setState(() => isLoading = false);

            final lower = url.toLowerCase();
            if (lower.contains('approved') || lower.contains('success') || lower.contains('complete') || lower.contains('finished') ||
                lower.contains('declined') || lower.contains('rejected') || lower.contains('failed')) {
              if (Get.isRegistered<VerificationController>()) {
                VerificationController.instance.syncDiditVerificationStatus(
                  isKyb: widget.isKyb,
                  expectedVendorSession: widget.vendorSessionId,
                );
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[DIDIT WEBVIEW RESOURCE ERROR] Code: ${error.errorCode} | Description: ${error.description} | Type: ${error.errorType} | Url: ${error.url}');
            if (mounted) setState(() => isLoading = false);
          },
        ),
      );

    // 3. Configure Android platform specific permission handlers for WebRTC camera stream, console logging, & file selector
    if (webViewController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = webViewController.platform as AndroidWebViewController;
      androidController.setOnPlatformPermissionRequest((request) {
        debugPrint('[DIDIT WEBVIEW PERMISSION REQUESTED] Granting WebRTC Camera/Microphone access...');
        request.grant();
      });
      androidController.setOnConsoleMessage((JavaScriptConsoleMessage consoleMessage) {
        debugPrint('[DIDIT WEBVIEW CONSOLE] [${consoleMessage.level.name}] ${consoleMessage.message}');
      });

      // Enable file picker for document uploads (KYC/KYB licenses, certificates, IDs)
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        debugPrint('[DIDIT FILE CHOOSER] Intercepted onShowFileChooser. Mode: ${params.mode} | Accept: ${params.acceptTypes} | Capture: ${params.isCaptureEnabled}');
        return await _handleFileSelection(params);
      });
    }

    // 4. Purge cookies, cache, and local storage to prevent Didit session persistence
    WebViewCookieManager().clearCookies();
    webViewController
      ..clearCache()
      ..clearLocalStorage();

    // 5. Load verification URL
    webViewController.loadRequest(Uri.parse(widget.url));

    // 6. Request native Android camera & microphone permissions
    _requestPermissions();
  }

  @override
  void dispose() {
    _verificationWorker?.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      final statuses = await [Permission.camera, Permission.microphone].request();
      debugPrint('[DIDIT NATIVE PERMISSIONS STATUS] Camera: ${statuses[Permission.camera]}, Microphone: ${statuses[Permission.microphone]}');
    } catch (e, stackTrace) {
      debugPrint('[DIDIT PERMISSION ERROR] $e\n$stackTrace');
    }
  }

  /// Handles HTML `<input type="file">` file uploads triggered by Didit Webview (e.g. KYB/KYC documents, PDF, JPG, PNG)
  Future<List<String>> _handleFileSelection(FileSelectorParams params) async {
    try {
      // 1. Direct camera capture if requested
      if (params.isCaptureEnabled) {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.camera);
        if (photo != null) {
          debugPrint('[DIDIT FILE CHOOSER] Captured photo: ${photo.path}');
          return [Uri.file(photo.path).toString()];
        }
        return <String>[];
      }

      // 2. Open native device file picker (supports PDF, PNG, JPG, WEBP, etc.)
      final bool allowMultiple = params.mode == FileSelectorMode.openMultiple;
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<String> uris = result.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
        debugPrint('[DIDIT FILE CHOOSER] Returning ${uris.length} file URI(s): $uris');
        return uris;
      }
    } catch (e, stackTrace) {
      debugPrint('[DIDIT FILE CHOOSER ERROR] $e\n$stackTrace');
    }
    // Always return empty list on cancel/error so Android WebView releases file chooser lock
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AvailAppbar(
        title: Text(widget.title),
        showBackArrow: true,
        showBackgroundColor: true,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            WebViewWidget(controller: webViewController),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: AvailColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}
