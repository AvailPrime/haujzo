import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/constants/api_constants.dart';

class ExchangeRateService {
  static const String _apiKey = APIConstants.exchangeRateAPIKey;
  static const String _primaryUrl = 'https://v6.exchangerate-api.com/v6/$_apiKey/latest';
  static const String _fallbackUrl = 'https://open.er-api.com/v6/latest';

  /// Fetch latest exchange rates with USD as base currency
  Future<Map<String, double>?> getLatestRates({String baseCurrency = 'USD'}) async {
    try {
      final primaryResp = await http.get(Uri.parse('$_primaryUrl/$baseCurrency'));

      if (primaryResp.statusCode == 200) {
        final data = json.decode(primaryResp.body);
        if (data['result'] == 'success') {
          if (data['conversion_rates'] is Map) {
            final Map<String, dynamic> rates = data['conversion_rates'];
            return rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
          } else if (data['rates'] is Map) {
            final Map<String, dynamic> rates = data['rates'];
            return rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
          }
        }
      }

      // Fallback open endpoint
      final fallbackResp = await http.get(Uri.parse('$_fallbackUrl/$baseCurrency'));
      if (fallbackResp.statusCode == 200) {
        final data = json.decode(fallbackResp.body);
        if (data['result'] == 'success' && data['rates'] is Map) {
          final Map<String, dynamic> rates = data['rates'];
          return rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
