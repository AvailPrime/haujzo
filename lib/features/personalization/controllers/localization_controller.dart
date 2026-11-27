import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../../../data/services/exchange_rate_service.dart';

class LocalizationController extends GetxController {
  static LocalizationController get instance => Get.isRegistered<LocalizationController>()
      ? Get.find<LocalizationController>()
      : Get.put(LocalizationController(), permanent: true);

  static const String defaultCurrencyCode = 'GHS';
  // Use universal 'GH¢' (U+00A2) which reliably renders across 100% of Android / iOS devices
  static const String defaultCurrencySymbol = 'GH¢';
  static const String _kSelectedCurrencyKey = 'selectedCurrency';
  static const String _kSelectedCurrencySymbolKey = 'selectedCurrencySymbol';
  static const String _kHasUserSelectedCurrencyKey = 'hasUserSelectedCurrency';

  final _storage = GetStorage();
  final _exchangeRateService = ExchangeRateService();

  // Selected Currency & Symbol State (Defaults to Ghanaian Cedi before user changes it)
  final RxString selectedCurrency = defaultCurrencyCode.obs;
  final RxString selectedCurrencySymbol = defaultCurrencySymbol.obs;
  final RxDouble currentExchangeRate = 15.5.obs;
  final RxBool isLoadingRates = false.obs;

  // Comprehensive Global & African Supported Currency List
  final List<Map<String, String>> supportedCurrenciesList = const [
    {'name': 'GHS', 'symbol': 'GH¢', 'label': 'Ghanaian Cedi (GHS)'},
    {'name': 'USD', 'symbol': '\$', 'label': 'United States Dollar (USD)'},
    {'name': 'NGN', 'symbol': '₦', 'label': 'Nigerian Naira (NGN)'},
    {'name': 'EUR', 'symbol': '€', 'label': 'Eurozone Euro (EUR)'},
    {'name': 'GBP', 'symbol': '£', 'label': 'British Pound Sterling (GBP)'},
    {'name': 'KES', 'symbol': 'KSh', 'label': 'Kenyan Shilling (KES)'},
    {'name': 'ZAR', 'symbol': 'R', 'label': 'South African Rand (ZAR)'},
    {'name': 'CAD', 'symbol': 'CA\$', 'label': 'Canadian Dollar (CAD)'},
  ];

  Map<String, Map<String, String>> get supportedCurrencies {
    final Map<String, Map<String, String>> map = {};
    for (var item in supportedCurrenciesList) {
      map[item['name']!] = item;
    }
    return map;
  }

  String get selectedCurrencyLabel =>
      supportedCurrencies[selectedCurrency.value]?['label'] ?? 'Ghanaian Cedi (GHS)';

  // Fallback Offline Rates relative to 1 USD
  final Map<String, double> _fallbackRates = const {
    'USD': 1.0,
    'GHS': 15.5,
    'NGN': 1500.0,
    'KES': 130.0,
    'ZAR': 18.5,
    'EUR': 0.92,
    'GBP': 0.78,
    'CAD': 1.36,
  };

  @override
  void onInit() {
    super.onInit();
    _loadStoredCurrency();
    refreshRates();
  }

  void _loadStoredCurrency() {
    final hasUserSelected = _storage.read<bool>(_kHasUserSelectedCurrencyKey) == true;
    final storedCode = _storage.read<String>(_kSelectedCurrencyKey);

    // Always default to Ghanaian Cedi (GHS) unless the user has explicitly selected a currency
    final String resolvedCode = (hasUserSelected &&
            storedCode != null &&
            supportedCurrencies.containsKey(storedCode))
        ? storedCode
        : defaultCurrencyCode;

    var sym = supportedCurrencies[resolvedCode]?['symbol'] ?? defaultCurrencySymbol;
    // Migrate old Unicode U+20B5 which causes tofu box 'GH▯' on many Android monospace fonts
    if (sym == 'GH₵') sym = defaultCurrencySymbol;

    selectedCurrency.value = resolvedCode;
    selectedCurrencySymbol.value = sym;
    currentExchangeRate.value = getEffectiveRate(resolvedCode);
  }

  /// Resolve effective rate for currency code
  double getEffectiveRate(String currency) {
    if (currency == 'USD') return 1.0;

    final cached = _storage.read<Map<String, dynamic>>('cachedRates');
    if (cached != null && cached.containsKey(currency)) {
      final rate = (cached[currency] as num?)?.toDouble() ?? 0.0;
      if (rate > 0) return rate;
    }

    if (_fallbackRates.containsKey(currency)) {
      return _fallbackRates[currency]!;
    }

    return 15.5;
  }

  /// Refresh Live Exchange Rates from API using API Key
  Future<void> refreshRates() async {
    try {
      isLoadingRates.value = true;
      final rates = await _exchangeRateService.getLatestRates(baseCurrency: 'USD');
      if (rates != null && rates.isNotEmpty) {
        await _storage.write('cachedRates', rates);
        final newRate = rates[selectedCurrency.value] ?? getEffectiveRate(selectedCurrency.value);
        currentExchangeRate.value = newRate;
      }
    } catch (_) {
    } finally {
      isLoadingRates.value = false;
    }
  }

  /// Update Active Currency (persists explicit user selection)
  Future<void> updateCurrency(String currencyCode, [String? symbol]) async {
    final validCode =
        supportedCurrencies.containsKey(currencyCode) ? currencyCode : defaultCurrencyCode;
    var sym = symbol ?? (supportedCurrencies[validCode]?['symbol'] ?? defaultCurrencySymbol);
    if (sym == 'GH₵') sym = defaultCurrencySymbol;

    selectedCurrency.value = validCode;
    selectedCurrencySymbol.value = sym;
    currentExchangeRate.value = getEffectiveRate(validCode);

    await _storage.write(_kSelectedCurrencyKey, validCode);
    await _storage.write(_kSelectedCurrencySymbolKey, sym);
    await _storage.write(_kHasUserSelectedCurrencyKey, true);
  }

  /// Helper to change currency by code
  void changeCurrency(String currencyCode) {
    final option = supportedCurrencies[currencyCode];
    final sym = option?['symbol'] ?? defaultCurrencySymbol;
    updateCurrency(currencyCode, sym);
  }

  /// Convert amount from active local currency back to base USD (for saving to Firebase)
  double convertToUSD(double localAmount) {
    final rate = getEffectiveRate(selectedCurrency.value);
    if (rate <= 0) return localAmount;
    return localAmount / rate;
  }

  /// Convert base USD amount from Firebase specifically to active local currency
  double getConvertedPrice(double usdAmount) {
    if (selectedCurrency.value == 'USD') return usdAmount;
    final rate = currentExchangeRate.value > 0
        ? currentExchangeRate.value
        : getEffectiveRate(selectedCurrency.value);
    return usdAmount * rate;
  }

  /// Format base USD amount into active local currency text with symbol and thousands grouping
  String getFormattedPrice(double usdAmount) {
    final converted = getConvertedPrice(usdAmount);
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${selectedCurrencySymbol.value} ${formatter.format(converted)}';
  }

  /// Format base USD amount into a specific currency code (defaults to GHS)
  String formatPriceForCurrency(double usdAmount, String currencyCode) {
    final code = supportedCurrencies.containsKey(currencyCode)
        ? currencyCode
        : defaultCurrencyCode;
    final rate = code == selectedCurrency.value && currentExchangeRate.value > 0
        ? currentExchangeRate.value
        : getEffectiveRate(code);
    final converted = code == 'USD' ? usdAmount : usdAmount * rate;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '$code ${formatter.format(converted)}';
  }
}
