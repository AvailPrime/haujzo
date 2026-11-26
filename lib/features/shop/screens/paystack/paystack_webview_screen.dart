import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../controllers/customer/trip_payment_controller.dart';

class PaystackWebViewScreen extends StatefulWidget {
  const PaystackWebViewScreen({
    super.key,
    required this.url,
    required this.reference,
  });

  final String url;
  final String reference;

  @override
  State<PaystackWebViewScreen> createState() => _PaystackWebViewScreenState();
}

class _PaystackWebViewScreenState extends State<PaystackWebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  double loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                loadingProgress = progress / 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('/paystack-redirect') ||
                request.url.contains('/payment-success') ||
                request.url.contains('standard.paystack.co/close')) {
              debugPrint('✅ WebView Success Redirect Detected: ${request.url}');

              final uri = Uri.parse(request.url);
              final reference = uri.queryParameters['reference'] ??
                  uri.queryParameters['trxref'] ??
                  widget.reference;

              if (Get.isRegistered<TripPaymentController>()) {
                Get.back();
                TripPaymentController.instance.verifyTripPayment(reference);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Get.back();
        if (Get.isRegistered<TripPaymentController>()) {
          TripPaymentController.instance.handleWebViewReturn(widget.reference);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure Paystack Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Get.back();
              if (Get.isRegistered<TripPaymentController>()) {
                TripPaymentController.instance.handleWebViewReturn(widget.reference);
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: loadingProgress < 1.0
                ? LinearProgressIndicator(
                    value: loadingProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
