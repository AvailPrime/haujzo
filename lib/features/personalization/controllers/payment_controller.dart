import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../commons/widgets/loader/loaders.dart';
import '../../../commons/widgets/texts/section_heading.dart';
import '../../../data/repositories/payment/payment_repository.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/country_codes.dart';
import '../../../utils/constants/image_strings.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../../shop/models/payment_details_model.dart';
import '../../shop/models/payment_method_model.dart';
import '../screens/payment_methods/add_new_payment.dart';
import '../../../routes/routes.dart';
import 'user_controller.dart';

class PaymentController extends GetxController {
  static PaymentController get instance => Get.find();

  // Form fields
  final mobileNumberController = TextEditingController();
  final accountNameController = TextEditingController();
  final cardNumberController = TextEditingController();
  final expiryDateController = TextEditingController();
  final cardHolderNameController = TextEditingController();
  final cvvController = TextEditingController();
  GlobalKey<FormState> paymentFormKey = GlobalKey<FormState>();

  // Reactive selected payment - default to Cash on Delivery
  final Rx<PaymentDetailsModel> selectedPayment = PaymentDetailsModel.cash().obs;

  final RxBool isLoading = false.obs;

  RxString selectedPaymentType = 'mobile_money'.obs; // default to mobile_money

  RxString selectedNetwork = 'mtn'.obs;

  final selectedCountryObject = Rx<AvailCountry?>(null);

  // Reactive list of payments
  RxList<PaymentDetailsModel> savedPayments = <PaymentDetailsModel>[].obs;

  // Repository
  final PaymentRepository paymentRepository = Get.put(PaymentRepository());

  @override
  void onInit() {
    super.onInit();
    initUserCountry();
    loadUserPayments();
  }

  /// Automatically initialize country based on user's registered country
  void initUserCountry() {
    try {
      if (Get.isRegistered<UserController>()) {
        final user = UserController.instance.user.value;
        if (user.countryCode.isNotEmpty || user.country.isNotEmpty) {
          final match = AvailCountry.africanCountries.firstWhereOrNull(
            (c) =>
                (user.countryCode.isNotEmpty && c.code.toLowerCase() == user.countryCode.toLowerCase()) ||
                (user.country.isNotEmpty && c.name.toLowerCase() == user.country.toLowerCase()),
          );
          if (match != null) {
            selectedCountryObject.value = match;
            return;
          }
        }
      }
    } catch (_) {}

    selectedCountryObject.value = AvailCountry.momoCountries.firstWhere(
      (c) => c.name == 'Ghana',
      orElse: () => AvailCountry.momoCountries.first,
    );
  }

  void selectCashPayment({bool closePopup = false}) {
    selectedPayment.value = PaymentDetailsModel.cash();
    if (closePopup && Get.context != null) {
      Navigator.of(Get.context!).pop(selectedPayment.value);
    }
  }

  void setPaymentType(String type, [String network = '']) {
    selectedPaymentType.value = type;
    selectedNetwork.value = network;
  }

  /// Load all payments and set default
  Future<void> loadUserPayments() async {
    try {
      isLoading.value = true;
      final fetchedPayments = await paymentRepository.fetchSavedPayments();
      savedPayments.assignAll(fetchedPayments);

      if (savedPayments.isNotEmpty && selectedPayment.value.id.isEmpty) {
        selectedPayment.value = savedPayments.first;
      }
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> chargeMobileMoney({
    required String email,
    required double amount,
  }) async {
    try {
      final payment = selectedPayment.value;

      if (payment.mobileNumber == null || payment.network == null) {
        throw 'Invalid mobile money details';
      }

      /// 🔥 SHOW LOADER
      AvailFullScreenLoader.openDialog('Processing payment...');

      final callable = FirebaseFunctions.instance
          .httpsCallable('chargeMobileMoney');

      final response = await callable.call({
        "email": email,
        "amount": amount,
        "phone": payment.mobileNumber, // should already include +233
        "network": payment.network,     // mtn | telecel | airteltigo
      });

      final data = response.data;

      /// 🔥 HANDLE RESPONSE
      if (data['status'] == true) {
        final paymentData = data['data'];

        final status = paymentData['status'];

        if (status == 'pending') {
          AvailLoaders.successSnackBar(
            title: 'Action Required',
            message: 'Approve payment on your phone',
          );
        } else if (status == 'success') {
          AvailLoaders.successSnackBar(
            title: 'Success',
            message: 'Payment successful',
          );
        } else {
          throw paymentData['gateway_response'] ?? 'Payment failed';
        }
      } else {
        throw 'Payment initialization failed';
      }

    } catch (e) {
      AvailLoaders.errorSnackBar(
        title: 'Payment Error',
        message: e.toString(),
      );
    } finally {
      AvailFullScreenLoader.stopLoading();
    }
  }

  /// Select a payment (like default)
  Future<void> selectPayment(PaymentDetailsModel payment, {bool closePopup = false}) async {
    selectedPayment.value = payment;

    if (closePopup && Get.context != null) {
      Navigator.of(Get.context!).pop(payment);
    }
  }

  /// Add new payment
  Future<bool> addNewPayment() async {
    try {
      final isMobile = selectedPaymentType.value == 'mobile_money';

      /// ✅ ONLY MOBILE MONEY ALLOWED
      if (!isMobile) {
        throw 'Card saving is disabled. Use Paystack to pay.';
      }

      if (mobileNumberController.text.trim().isEmpty) {
        throw 'Please enter your mobile money number';
      }

      final holderName = accountNameController.text.trim();
      if (holderName.length < 2) {
        throw 'Please enter the exact registered Account Name on this wallet';
      }

      if (selectedNetwork.value.isEmpty) {
        throw 'Please select a network (MTN, Telecel, AirtelTigo)';
      }

      final payment = createPaymentModel();

      /// ✅ CHECK FOR DUPLICATES (MOBILE MONEY)
      final existingPayment = savedPayments.firstWhereOrNull((p) {
        if (p.method.type != 'mobile_money') return false;
        
        // Normalize both for comparison
        final String? newNumber = PaymentDetailsModel.normalizePhone(payment.mobileNumber);
        final String? existingNumber = PaymentDetailsModel.normalizePhone(p.mobileNumber);

        return newNumber == existingNumber && p.network == payment.network;
      });

      if (existingPayment != null) {
        if ((existingPayment.accountName ?? '').trim().isEmpty) {
          AvailFullScreenLoader.openDialog('Updating Account Name...');
          await paymentRepository.updatePaymentAccountName(existingPayment.id, holderName);
          await loadUserPayments();
          AvailFullScreenLoader.stopLoading();
          AvailLoaders.successSnackBar(
            title: 'Account Name Updated',
            message: 'Registered account name "$holderName" saved to your existing wallet.',
          );
          clearFormFields();
          return true;
        }
        selectedPayment.value = existingPayment;
        AvailLoaders.successSnackBar(
          title: 'Already Saved',
          message: 'This Mobile Money number is already in your list.',
        );
        clearFormFields();
        return true;
      }

      AvailFullScreenLoader.openDialog('Saving Payment...');

      final id = await paymentRepository.storePaymentDetails(payment);
      payment.id = id;

      savedPayments.add(payment);
      selectedPayment.value = payment;

      AvailFullScreenLoader.stopLoading();

      AvailLoaders.successSnackBar(
        title: 'Success',
        message: 'Mobile Money saved successfully',
      );

      clearFormFields();
      return true;
    } catch (e) {
      if (AvailFullScreenLoader.isLoading()) {
        AvailFullScreenLoader.stopLoading();
      }
      AvailLoaders.errorSnackBar(
        title: 'Error',
        message: e.toString(),
      );
      return false;
    }
  }

  /// Clear form
  void clearFormFields() {
    mobileNumberController.clear();
    accountNameController.clear();
    cardNumberController.clear();
    expiryDateController.clear();
    cvvController.clear();
  }

  /// ================= DELETE PAYMENT =================
  Future<void> deletePayment(String paymentId) async {
    try {
      Get.defaultDialog(
        title: 'Delete Payment Method',
        middleText: 'Are you sure you want to delete this payment method?',
        onConfirm: () async {
          Navigator.of(Get.overlayContext!).pop(); // Close dialog
          AvailLoaders.customToast(message: 'Deleting...');

          await paymentRepository.deletePaymentMethod(paymentId);

          // Update local list
          savedPayments.removeWhere((element) => element.id == paymentId);

          // If the deleted payment was the selected one, clear selection
          if (selectedPayment.value.id == paymentId) {
            selectedPayment.value = PaymentDetailsModel.empty();
          }

          AvailLoaders.customToast(message: 'Payment method deleted successfully');
        },
        onCancel: () {},
        textConfirm: 'Delete',
        textCancel: 'Cancel',
        confirmTextColor: Colors.white,
        buttonColor: Colors.red,
      );
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Error', message: 'Failed to delete payment: $e');
    }
  }

  /// Build PaymentDetailsModel
  PaymentDetailsModel createPaymentModel() {
    final isMobile = selectedPaymentType.value == 'mobile_money';

    /// 🔥 FORMAT NUMBER FOR GATEWAY (E.164 FORMAT)
    String? formattedNumber;

    if (isMobile) {
      final raw = mobileNumberController.text.trim();
      final phoneCode = selectedCountryObject.value?.phoneCode ?? '+233';

      /// Clean prefix if manually entered
      var cleanedPhone = raw.replaceAll(RegExp(r'[\s\-]'), '');
      if (cleanedPhone.startsWith(phoneCode)) {
        cleanedPhone = cleanedPhone.substring(phoneCode.length);
      } else if (cleanedPhone.startsWith(phoneCode.replaceAll('+', ''))) {
        cleanedPhone = cleanedPhone.substring(phoneCode.replaceAll('+', '').length);
      }

      /// Convert 024XXXXXXX → 24XXXXXXX (if starting with 0)
      if (cleanedPhone.startsWith('0')) {
        cleanedPhone = cleanedPhone.substring(1);
      }

      formattedNumber = '$phoneCode$cleanedPhone';
    }

    /// 🔥 LAST 4 FOR DISPLAY
    final last4Digits = isMobile && mobileNumberController.text.length >= 4
        ? mobileNumberController.text
        .substring(mobileNumberController.text.length - 4)
        : null;

    return PaymentDetailsModel(
      id: '',

      method: PaymentMethodModel(
        id: '',
        name: '${selectedNetwork.value.toUpperCase()} Mobile Money',
        image: '',
        code: selectedNetwork.value,
        type: 'mobile_money',
      ),

      /// 🔥 CRITICAL FIX (THIS WAS MISSING)
      network: isMobile ? selectedNetwork.value : null,
      accountName: accountNameController.text.trim(),

      /// 🔥 USE FORMATTED NUMBER
      mobileNumber: formattedNumber,

      /// For display
      last4: last4Digits,

      /// Not used for MoMo
      brand: null,
      expMonth: null,
      expYear: null,

      /// No token for MoMo
      authorizationCode: null,

      createdAt: DateTime.now(),
    );
  }

  Future<void> selectPaymentMethod(BuildContext context) async {
    final controller = PaymentController.instance;

    final methods = [
      PaymentMethodModel(
        id: '',
        name: 'Card Payment',
        image: AvailImages.creditCard,
        code: 'card',
        type: 'card',
      ),
      PaymentMethodModel(
        id: '',
        name: 'MTN Mobile Money',
        image: AvailImages.mtn,
        code: 'mtn',
        type: 'mobile_money',
      ),
      PaymentMethodModel(
        id: '',
        name: 'Telecel Cash',
        image: AvailImages.telecel,
        code: 'telecel',
        type: 'mobile_money',
      ),
      PaymentMethodModel(
        id: '',
        name: 'AirtelTigo Money',
        image: AvailImages.airteltigo,
        code: 'airteltigo',
        type: 'mobile_money',
      ),
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(AvailSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AvailSizes.sm),
              ...methods.map((method) => Obx(() {
                final selectedType = controller.selectedPaymentType.value;
                final selectedNetwork = controller.selectedNetwork.value;

                final isSelected = method.type == 'card'
                    ? selectedType == 'card'
                    : selectedType == 'mobile_money' && selectedNetwork == method.code;

                return ListTile(
                  leading: Image.asset(method.image, width: 32, height: 32),
                  title: Text(method.name),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    // Update controller reactively
                    controller.setPaymentType(
                      method.type,
                      method.type == 'mobile_money' ? method.code : '',
                    );

                    // Close the bottom sheet
                    Navigator.of(context).pop();
                  },
                );
              })),
            ],
          ),
        ),
      ),
    );
  }

  /// Popup to select payment
  Future<PaymentDetailsModel?> selectNewPaymentPopup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<PaymentDetailsModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(AvailSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvailSectionHeading(
                  title: 'Select Payment Method',
                  showActionButton: false,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Obx(() {
                    return ListView(
                      controller: scrollController,
                      children: [
                        // Cash on Delivery Option
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedPayment.value.isCash
                                  ? AvailColors.primary
                                  : (isDark ? const Color(0xFF1E3A5F) : Colors.grey.shade300),
                              width: selectedPayment.value.isCash ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RadioListTile<String>(
                            title: const Text('Cash on Delivery (POD)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: const Text('Pay physical cash to verified driver upon delivery', style: TextStyle(fontSize: 12)),
                            value: 'cash_on_delivery',
                            groupValue: selectedPayment.value.id,
                            activeColor: AvailColors.primary,
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.money, color: Colors.green, size: 22),
                            ),
                            onChanged: (_) {
                              selectCashPayment(closePopup: true);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'SAVED MOBILE MONEY ACCOUNTS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        if (savedPayments.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text('No saved Mobile Money wallets yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          ),
                        ] else ...[
                          ...savedPayments.map((payment) {
                            final isSelected = selectedPayment.value.id == payment.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? AvailColors.primary
                                      : (isDark ? const Color(0xFF1E3A5F) : Colors.grey.shade300),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: RadioListTile<String>(
                                title: Text(payment.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  payment.mobileNumber != null ? 'Account: ${payment.mobileNumber}' : payment.displaySubtitle,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                value: payment.id,
                                groupValue: selectedPayment.value.id,
                                activeColor: AvailColors.primary,
                                onChanged: (_) async {
                                  await selectPayment(payment, closePopup: true);
                                },
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Get.toNamed(AvailRoutes.addNewPayment),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Mobile Money Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
