/// A utility class to map formatting-related exceptions to readable messages.
class AvailFormatException implements Exception {
  /// The format error code or context identifier.
  final String code;

  /// Constructor to initialize with the error code.
  AvailFormatException(this.code);

  /// Returns a user-friendly message based on the formatting issue.
  String get message {
    switch (code) {
    // JSON-related
      case 'invalid-json':
        return 'The JSON structure is invalid or corrupted.';
      case 'json-syntax-error':
        return 'There is a syntax error in the JSON string.';
      case 'json-depth-exceeded':
        return 'The JSON nesting depth is too deep.';
      case 'json-key-missing':
        return 'A required key is missing from the JSON object.';
      case 'json-type-mismatch':
        return 'The JSON value type does not match the expected type.';

    // XML-related
      case 'invalid-xml':
        return 'The XML document is invalid.';
      case 'xml-syntax-error':
        return 'There is a syntax error in the XML document.';
      case 'xml-missing-element':
        return 'A required XML element is missing.';
      case 'xml-mismatched-tag':
        return 'Mismatched XML tag found.';
      case 'xml-attribute-error':
        return 'Invalid or missing XML attribute.';

    // CSV-related
      case 'invalid-csv':
        return 'The CSV format is invalid.';
      case 'csv-missing-header':
        return 'The CSV file is missing a header row.';
      case 'csv-column-mismatch':
        return 'Row length does not match header length in CSV.';
      case 'csv-empty-field':
        return 'One or more required CSV fields are empty.';

    // Date/time formatting
      case 'date-format-error':
        return 'Invalid date format. Use a valid format like YYYY-MM-DD.';
      case 'invalid-time-format':
        return 'Invalid time format. Use a format like HH:mm:ss.';
      case 'invalid-datetime-format':
        return 'The datetime format is invalid. Use ISO 8601 (YYYY-MM-DDTHH:mm:ss).';
      case 'date-out-of-range':
        return 'The date provided is out of the acceptable range.';
      case 'time-zone-error':
        return 'Invalid or unsupported timezone provided.';

    // Number formatting
      case 'number-format-error':
        return 'Expected a numeric value but received something else.';
      case 'decimal-format-error':
        return 'Invalid decimal format. Ensure proper use of dot or comma.';
      case 'currency-format-error':
        return 'Invalid currency format.';
      case 'percentage-format-error':
        return 'Invalid percentage format.';
      case 'out-of-range':
        return 'The numeric value is out of the valid range.';

    // String/character formatting
      case 'unexpected-null':
        return 'Unexpected null value encountered during parsing.';
      case 'empty-string':
        return 'An empty string was provided when a value was expected.';
      case 'invalid-charset':
        return 'Unsupported character set or encoding.';
      case 'invalid-escape-sequence':
        return 'Invalid escape sequence in string.';
      case 'whitespace-error':
        return 'Unexpected whitespace in input string.';

    // Encoding/decoding issues
      case 'invalid-base64':
        return 'The Base64 string is invalid.';
      case 'invalid-utf8':
        return 'The UTF-8 string contains invalid byte sequences.';
      case 'invalid-hex':
        return 'The hex string format is invalid.';
      case 'encoding-failed':
        return 'Failed to encode the input data.';
      case 'decoding-failed':
        return 'Failed to decode the input data.';

    // Validation / structure
      case 'missing-fields':
        return 'Required fields are missing from the input.';
      case 'type-mismatch':
        return 'Data type mismatch. Please check your input values.';
      case 'unexpected-token':
        return 'Unexpected token found during parsing.';
      case 'duplicate-key':
        return 'Duplicate key detected where uniqueness is required.';
      case 'invalid-identifier':
        return 'The identifier format is invalid.';

    // File/data integrity
      case 'file-corrupted':
        return 'The input file is corrupted or unreadable.';
      case 'unsupported-format':
        return 'The file format is not supported.';
      case 'truncated-data':
        return 'The input data appears to be truncated or incomplete.';
      case 'extra-data':
        return 'Unexpected extra data found at the end of input.';

    // General formatting errors
      case 'syntax-error':
        return 'General syntax error in input.';
      case 'parsing-failed':
        return 'Failed to parse the provided input.';
      case 'serialization-failed':
        return 'Failed to serialize the data to the desired format.';
      case 'deserialization-failed':
        return 'Failed to deserialize the input data.';
      case 'validation-failed':
        return 'Input failed validation checks.';

    // Catch-all
      default:
        return 'A formatting error occurred. [$code]';
    }
  }
}
