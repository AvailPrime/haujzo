import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

class DiditVerificationService extends GetxController {
  static DiditVerificationService get instance => Get.find();

  static const String baseUrl = 'https://verification.didit.me/v3';

  /// Didit API Key configured via --dart-define=DIDIT_API_KEY=... or setApiKey()
  String apiKey = const String.fromEnvironment('DIDIT_API_KEY');

  void setApiKey(String key) {
    apiKey = key;
  }

  Map<String, String> get _jsonHeaders => {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      };

  /// --------------------------------------------------------------------------
  /// SESSIONS & HOSTED FLOWS
  /// --------------------------------------------------------------------------

  /// POST /v3/session/ - Create a dynamic verification session for a user
  Future<Map<String, dynamic>> createVerificationSession({
    required String vendorData,
    String? workflowId,
    String? callbackUrl,
  }) async {
    try {
      final body = {
        'vendor_data': vendorData,
        if (workflowId != null && workflowId.isNotEmpty) 'workflow_id': workflowId,
        if (callbackUrl != null && callbackUrl.isNotEmpty) 'callback_url': callbackUrl,
      };

      debugPrint('[DIDIT API CREATE SESSION] POST $baseUrl/session/ | Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/session/'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      debugPrint('[DIDIT API CREATE SESSION RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json;
      }
      return json;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API CREATE SESSION ERROR] $e\n$stackTrace');
      throw Exception('Create Session Error: $e');
    }
  }

  /// GET /v3/session/{sessionId}/decision/ - Get authoritative live decision of a specific Didit session
  Future<Map<String, dynamic>?> getSessionDecision(String sessionId) async {
    try {
      debugPrint('[DIDIT API GET DECISION] GET $baseUrl/session/$sessionId/decision/');
      final response = await http.get(
        Uri.parse('$baseUrl/session/$sessionId/decision/'),
        headers: _jsonHeaders,
      );
      debugPrint('[DIDIT API GET DECISION RESPONSE] Code: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API GET DECISION ERROR] $e\n$stackTrace');
      return null;
    }
  }

  /// GET /v3/sessions/ - Fetch list of verification sessions from Didit API (supports session_kind and vendor_data)
  Future<List<Map<String, dynamic>>> fetchSessions({String? sessionKind, String? vendorData}) async {
    try {
      final queryParams = <String, String>{
        'page_size': '50',
        if (sessionKind != null && sessionKind.isNotEmpty) 'session_kind': sessionKind,
        if (vendorData != null && vendorData.isNotEmpty) 'vendor_data': vendorData,
      };
      final uri = Uri.parse('$baseUrl/sessions/').replace(queryParameters: queryParams);
      debugPrint('[DIDIT API FETCH SESSIONS] GET $uri');
      final response = await http.get(
        uri,
        headers: _jsonHeaders,
      );
      debugPrint('[DIDIT API FETCH SESSIONS RESPONSE] Code: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['results'] is List) {
          return List<Map<String, dynamic>>.from(json['results']);
        }
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API FETCH SESSIONS ERROR] $e\n$stackTrace');
      return [];
    }
  }

  /// --------------------------------------------------------------------------
  /// IDENTITY & DOCUMENTS (KYC)
  /// --------------------------------------------------------------------------

  /// POST /v3/id-verification/ (multipart/form-data)
  Future<Map<String, dynamic>> verifyIdDocument({
    required File frontImage,
    File? backImage,
    String? vendorData,
  }) async {
    try {
      debugPrint('[DIDIT API ID-VERIFICATION] POST $baseUrl/id-verification/ | VendorData: $vendorData');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/id-verification/'));
      request.headers['x-api-key'] = apiKey;

      request.files.add(await http.MultipartFile.fromPath('front_image', frontImage.path));
      if (backImage != null) {
        request.files.add(await http.MultipartFile.fromPath('back_image', backImage.path));
      }
      if (vendorData != null) {
        request.fields['vendor_data'] = vendorData;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[DIDIT API ID-VERIFICATION RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonResponse;
      } else {
        throw jsonResponse['message'] ?? 'ID verification failed with code ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API ID-VERIFICATION ERROR] $e\n$stackTrace');
      throw Exception('ID Verification Error: $e');
    }
  }

  /// POST /v3/passive-liveness/ (multipart/form-data)
  Future<Map<String, dynamic>> checkPassiveLiveness({
    required File userImage,
    String? vendorData,
  }) async {
    try {
      debugPrint('[DIDIT API PASSIVE-LIVENESS] POST $baseUrl/passive-liveness/ | VendorData: $vendorData');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/passive-liveness/'));
      request.headers['x-api-key'] = apiKey;
      request.files.add(await http.MultipartFile.fromPath('user_image', userImage.path));
      if (vendorData != null) request.fields['vendor_data'] = vendorData;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[DIDIT API LIVENESS RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API LIVENESS ERROR] $e\n$stackTrace');
      throw Exception('Liveness Check Error: $e');
    }
  }

  /// POST /v3/face-match/ (multipart/form-data)
  Future<Map<String, dynamic>> checkFaceMatch({
    required File userImage,
    required File refImage,
    String? vendorData,
  }) async {
    try {
      debugPrint('[DIDIT API FACE-MATCH] POST $baseUrl/face-match/ | VendorData: $vendorData');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/face-match/'));
      request.headers['x-api-key'] = apiKey;
      request.files.add(await http.MultipartFile.fromPath('user_image', userImage.path));
      request.files.add(await http.MultipartFile.fromPath('ref_image', refImage.path));
      if (vendorData != null) request.fields['vendor_data'] = vendorData;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[DIDIT API FACE-MATCH RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API FACE-MATCH ERROR] $e\n$stackTrace');
      throw Exception('Face Match Error: $e');
    }
  }

  /// POST /v3/poa/ (multipart/form-data) - Proof of Address
  Future<Map<String, dynamic>> verifyProofOfAddress({
    required File documentFile,
    String? vendorData,
  }) async {
    try {
      debugPrint('[DIDIT API POA] POST $baseUrl/poa/ | VendorData: $vendorData');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/poa/'));
      request.headers['x-api-key'] = apiKey;
      request.files.add(await http.MultipartFile.fromPath('document', documentFile.path));
      if (vendorData != null) request.fields['vendor_data'] = vendorData;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[DIDIT API POA RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API POA ERROR] $e\n$stackTrace');
      throw Exception('Proof of Address Error: $e');
    }
  }

  /// --------------------------------------------------------------------------
  /// COMPLIANCE & AML
  /// --------------------------------------------------------------------------

  /// POST /v3/aml/ (JSON)
  Future<Map<String, dynamic>> runAmlCheck({
    required String fullName,
    String entityType = 'person', // 'person' or 'company'
    String? nationality,
    String? documentNumber,
    bool includeAdverseMedia = true,
    bool includeOngoingMonitoring = false,
  }) async {
    try {
      final body = {
        'full_name': fullName,
        'entity_type': entityType,
        if (nationality != null) 'nationality': nationality,
        if (documentNumber != null) 'document_number': documentNumber,
        'include_adverse_media': includeAdverseMedia,
        'include_ongoing_monitoring': includeOngoingMonitoring,
      };

      debugPrint('[DIDIT API AML CHECK] POST $baseUrl/aml/ | Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/aml/'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      debugPrint('[DIDIT API AML RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API AML ERROR] $e\n$stackTrace');
      throw Exception('AML Check Error: $e');
    }
  }

  /// --------------------------------------------------------------------------
  /// BUSINESS VERIFICATION (KYB)
  /// --------------------------------------------------------------------------

  /// POST /v3/kyb/search/ (JSON)
  Future<Map<String, dynamic>> searchBusinessRegistry({
    required String countryCode,
    String? name,
    String? registrationNumber,
    String tier = 'basic', // 'basic', 'shareholders', 'ubo'
    String? vendorData,
  }) async {
    try {
      final body = {
        'country_code': countryCode,
        if (name != null && name.isNotEmpty) 'name': name,
        if (registrationNumber != null && registrationNumber.isNotEmpty)
          'registration_number': registrationNumber,
        'tier': tier,
        'search_type': 'contains',
        if (vendorData != null) 'vendor_data': vendorData,
      };

      debugPrint('[DIDIT API KYB SEARCH] POST $baseUrl/kyb/search/ | Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/kyb/search/'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      debugPrint('[DIDIT API KYB SEARCH RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API KYB SEARCH ERROR] $e\n$stackTrace');
      throw Exception('KYB Search Error: $e');
    }
  }

  /// POST /v3/kyb/select/ (JSON)
  Future<Map<String, dynamic>> selectBusinessRecord({
    required String kybResponseId,
    String? vendorData,
  }) async {
    try {
      final body = {
        'kyb_response_id': kybResponseId,
        'save_api_request': true,
        if (vendorData != null) 'vendor_data': vendorData,
      };

      debugPrint('[DIDIT API KYB SELECT] POST $baseUrl/kyb/select/ | Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/kyb/select/'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      debugPrint('[DIDIT API KYB SELECT RESPONSE] Code: ${response.statusCode} | Body: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint('[DIDIT API KYB SELECT ERROR] $e\n$stackTrace');
      throw Exception('KYB Select Error: $e');
    }
  }

  /// --------------------------------------------------------------------------
  /// CONTACT VERIFICATION (OTP)
  /// --------------------------------------------------------------------------

  Future<bool> sendEmailOtp(String email) async {
    try {
      debugPrint('[DIDIT API EMAIL OTP SEND] Email: $email');
      final response = await http.post(
        Uri.parse('$baseUrl/email/send/'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email}),
      );
      debugPrint('[DIDIT API EMAIL OTP RESPONSE] Code: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[DIDIT API EMAIL OTP ERROR] $e');
      return false;
    }
  }

  Future<bool> verifyEmailOtp(String email, String code) async {
    try {
      debugPrint('[DIDIT API EMAIL OTP CHECK] Email: $email | Code: $code');
      final response = await http.post(
        Uri.parse('$baseUrl/email/check/'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'code': code}),
      );
      debugPrint('[DIDIT API EMAIL OTP CHECK RESPONSE] Code: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[DIDIT API EMAIL OTP CHECK ERROR] $e');
      return false;
    }
  }

  Future<bool> sendPhoneOtp(String phone, {String channel = 'sms'}) async {
    try {
      debugPrint('[DIDIT API PHONE OTP SEND] Phone: $phone | Channel: $channel');
      final response = await http.post(
        Uri.parse('$baseUrl/phone/send/'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phone, 'channel': channel}),
      );
      debugPrint('[DIDIT API PHONE OTP RESPONSE] Code: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[DIDIT API PHONE OTP ERROR] $e');
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String phone, String code) async {
    try {
      debugPrint('[DIDIT API PHONE OTP CHECK] Phone: $phone | Code: $code');
      final response = await http.post(
        Uri.parse('$baseUrl/phone/check/'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phone, 'code': code}),
      );
      debugPrint('[DIDIT API PHONE OTP CHECK RESPONSE] Code: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[DIDIT API PHONE OTP CHECK ERROR] $e');
      return false;
    }
  }
}
