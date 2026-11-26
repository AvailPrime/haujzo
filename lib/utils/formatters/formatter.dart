import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class AvailFormatter {
  // Format Date with a customizable locale and format
  static String formatDate(DateTime? date,
      {String locale = 'en_US', String pattern = 'dd-MMM-yyyy'}) {
    date ??= DateTime.now();
    return DateFormat(pattern, locale).format(date);
  }

  // Format Currency with a customizable locale
  static String formatCurrency(double amount,
      {String locale = 'en_US', String? currencySymbol}) {
    final format = NumberFormat.currency(
      locale: locale,
      symbol: currencySymbol ??
          NumberFormat.simpleCurrency(locale: locale).currencySymbol,
    );
    return format.format(amount);
  }

  // Format Phone Number with support for country codes
  static String formatPhoneNumber(String phoneNumber, {String? countryCode}) {
    phoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

    String formatted = phoneNumber;
    if (phoneNumber.length == 10) {
      formatted = '(${phoneNumber.substring(0, 3)}) ${phoneNumber.substring(3, 6)}-${phoneNumber.substring(6)}';
    } else if (phoneNumber.length == 11) {
      formatted = '${phoneNumber.substring(0, 1)}-${phoneNumber.substring(1, 4)}-${phoneNumber.substring(4, 7)}-${phoneNumber.substring(7)}';
    }

    if (countryCode != null && countryCode.isNotEmpty) {
      return '$countryCode $formatted';
    }

    return formatted;
  }

  /// -------------------------------
  /// CARD FORMATTERS
  /// -------------------------------

  // Auto-format card number: 1234567812345678 → 1234 5678 1234 5678
  static String formatCardNumber(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i + 1) % 4 == 0 && i != digitsOnly.length - 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  // Auto-format expiry date: 1225 → 12/25
  static String formatExpiryDate(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length <= 2) return digitsOnly;
    return digitsOnly.substring(0, 2) + '/' + digitsOnly.substring(2, digitsOnly.length.clamp(2, 4));
  }

  // Detect card type (Visa/MasterCard)
  static String detectCardType(String input) {
    final number = input.replaceAll(' ', '');
    if (number.startsWith('4')) return 'visa';
    if (number.startsWith('5')) return 'mastercard';
    return 'unknown';
  }

  static List<TextInputFormatter> cardNumberInputFormatters() => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(19),
    CardNumberTextFormatter(),
  ];

  /// Expiry date input formatter: allows only digits, formats MM/YY
  static List<TextInputFormatter> expiryDateInputFormatters() => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
    ExpiryDateTextFormatter(),
  ];
}

/// Card Number Text Formatter for TextFormField
/// Card Number Text Formatter for TextFormField
class CardNumberTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i + 1) % 4 == 0 && i != digitsOnly.length - 1) buffer.write(' ');
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Expiry Date Text Formatter for TextFormField
class ExpiryDateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = digitsOnly;
    if (digitsOnly.length > 2) {
      formatted = digitsOnly.substring(0, 2) +
          '/' +
          digitsOnly.substring(2, digitsOnly.length.clamp(2, 4));
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
