import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../commons/widgets/loader/loaders.dart';
import '../../../commons/widgets/network/network_manager.dart';
import '../../../data/repositories/user/app_user_repository.dart';
import '../../../data/services/didit_verification_service.dart';
import '../../../utils/popups/full_screen_loader.dart';
import 'package:truck_booking/features/shop/models/user_account_model.dart';
import '../screens/verification/didit_webview_screen.dart';
import 'user_controller.dart';

class VerificationController extends GetxController {
  static VerificationController get instance => Get.find();

  final diditService = Get.put(DiditVerificationService());
  final userRepository = AppUserRepository.instance;

  Rx<UserAccountModel> userModel = UserAccountModel.empty().obs;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userStreamSubscription;

  // Default Didit Verification Portal URLs & Workflow UUIDs
  String kycUrl = 'https://verify.didit.me/u/feF_OTZ5Qum4aKXGsawKIw';
  String kybUrl = 'https://verify.didit.me/u/J3SsDesfQUaE2Ufnr8-azQ';
  String kycWorkflowId = '7de17f39-3679-42e9-b868-a5c6b1ac0a23';
  String kybWorkflowId = '2774ac0d-eb1f-4146-84d9-47e7afcf9acd';

  // Legacy file fields maintained for backward compatibility
  Rx<File?> frontIdFile = Rx<File?>(null);
  Rx<File?> backIdFile = Rx<File?>(null);
  Rx<File?> selfieFile = Rx<File?>(null);
  Rx<File?> proofOfAddressFile = Rx<File?>(null);

  final companyNameSearch = TextEditingController();
  final registrationNumberInput = TextEditingController();

  final isLoading = false.obs;
  final isStartingVerification = false.obs;
  String? activeVendorSession;
  String? activeSessionId;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<UserController>()) {
      userModel.value = UserController.instance.user.value;
    }
    loadCurrentUser();
    fetchDiditSettingsFromFirestore();
    _startRealtimeUserStream();
  }

  @override
  void onClose() {
    _userStreamSubscription?.cancel();
    super.onClose();
  }

  /// Fetch Didit configuration (API Keys / Custom Portal URLs / Workflow UUIDs) from Firestore settings
  Future<void> fetchDiditSettingsFromFirestore() async {
    try {
      final doc1 = await FirebaseFirestore.instance.collection('Settings').doc('didit_settings').get();
      final doc2 = await FirebaseFirestore.instance.collection('app_settings').doc('didit_settings').get();

      final data = (doc1.exists && doc1.data() != null)
          ? doc1.data()!
          : ((doc2.exists && doc2.data() != null) ? doc2.data()! : null);

      if (data != null) {
        if (data['diditKycUrl'] != null && data['diditKycUrl'].toString().isNotEmpty) {
          kycUrl = data['diditKycUrl'].toString().trim();
        }
        if (data['diditKybUrl'] != null && data['diditKybUrl'].toString().isNotEmpty) {
          kybUrl = data['diditKybUrl'].toString().trim();
        }
        if (data['diditKycWorkflowId'] != null && data['diditKycWorkflowId'].toString().isNotEmpty) {
          kycWorkflowId = data['diditKycWorkflowId'].toString().trim();
        }
        if (data['diditKybWorkflowId'] != null && data['diditKybWorkflowId'].toString().isNotEmpty) {
          kybWorkflowId = data['diditKybWorkflowId'].toString().trim();
        }
        if (data['diditApiKey'] != null && data['diditApiKey'].toString().isNotEmpty) {
          diditService.setApiKey(data['diditApiKey'].toString().trim());
        }
        debugPrint('[DIDIT SETTINGS LOADED] kycUrl: $kycUrl | kybUrl: $kybUrl | HasApiKey: ${diditService.apiKey.isNotEmpty}');
      }
    } catch (e) {
      debugPrint('[DIDIT SETTINGS LOAD ERROR] $e');
    }
  }

  /// Real-time Firestore Stream Listener for immediate UI update upon approval
  void _startRealtimeUserStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _userStreamSubscription?.cancel();
      _userStreamSubscription = FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final updatedUser = UserAccountModel.fromSnapshot(snapshot);
            userModel.value = updatedUser;
            userModel.refresh();

            // Sync with UserController if active
            if (Get.isRegistered<UserController>()) {
              final userCtrl = UserController.instance;
              userCtrl.user.value = updatedUser;
              userCtrl.user.refresh();
            }

            debugPrint('[DIDIT REALTIME STREAM UPDATE] VerificationStatus: ${updatedUser.verificationStatus} | DiditStatus: ${updatedUser.diditStatus} | DiditVerified: ${updatedUser.diditVerified} | AdminApproval: ${updatedUser.adminApprovalStatus}');
          }
        },
        onError: (e, stackTrace) {
          debugPrint('[DIDIT FIRESTORE STREAM ERROR] $e\n$stackTrace');
        },
      );
    }
  }

  Future<void> loadCurrentUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final user = await userRepository.fetchUserRecord(uid);
        userModel.value = user;
        userModel.refresh();
        if (Get.isRegistered<UserController>()) {
          UserController.instance.user.value = user;
          UserController.instance.user.refresh();
        }
        debugPrint('[DIDIT LOAD USER RECORD SUCCESS] UID: $uid | Status: ${user.verificationStatus} / ${user.diditStatus} | AdminApproval: ${user.adminApprovalStatus}');
      }
    } catch (e, stackTrace) {
      debugPrint('[DIDIT LOAD USER ERROR] $e\n$stackTrace');
    }
  }

  /// Start or resume Didit Real-Time Automated Verification Portal (KYC or KYB)
  Future<void> startDiditVerification({bool? isKyb}) async {
    if (isStartingVerification.value || isLoading.value) {
      debugPrint('[DIDIT START IGNORED] Verification initiation already in progress');
      return;
    }
    isStartingVerification.value = true;
    try {
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        debugPrint('[DIDIT START ERROR] Network not connected');
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        debugPrint('[DIDIT START ERROR] User ID is null or empty');
        AvailLoaders.errorSnackBar(title: 'Error', message: 'User account not found.');
        return;
      }

      // Fetch latest settings in case updated in Firestore
      await fetchDiditSettingsFromFirestore();

      final user = userModel.value;
      final bool runKyb = isKyb ?? (user.accountType == 'business');
      final String baseUrl = runKyb ? kybUrl : kycUrl;
      final String targetWorkflowId = runKyb ? kybWorkflowId : kycWorkflowId;

      // Track-isolated unique timestamped session vendor ID
      final String vendorSessionUid = runKyb
          ? 'kyb_${uid}_${DateTime.now().millisecondsSinceEpoch}'
          : 'kyc_${uid}_${DateTime.now().millisecondsSinceEpoch}';

      activeVendorSession = vendorSessionUid;

      final Uri parsedBaseUri = Uri.parse(baseUrl);
      final newParams = Map<String, String>.from(parsedBaseUri.queryParameters);
      newParams['vendor_data'] = vendorSessionUid;
      final Uri uri = parsedBaseUri.replace(queryParameters: newParams);
      String selectedUrl = uri.toString();
      String? actualSessionId;

      // Try dynamic session creation via Didit API if API key is provided
      if (diditService.apiKey.isNotEmpty && diditService.apiKey != 'YOUR_DIDIT_API_KEY') {
        try {
          final sessionData = await (diditService as dynamic).createVerificationSession(
            vendorData: vendorSessionUid,
            workflowId: targetWorkflowId,
          );
          if (sessionData['session_id'] != null && sessionData['session_id'].toString().isNotEmpty) {
            actualSessionId = sessionData['session_id'].toString();
            activeSessionId = actualSessionId;
          }
          if (sessionData['url'] != null && sessionData['url'].toString().isNotEmpty) {
            selectedUrl = sessionData['url'].toString();
          } else if (sessionData['session_url'] != null && sessionData['session_url'].toString().isNotEmpty) {
            selectedUrl = sessionData['session_url'].toString();
          }
        } catch (e) {
          debugPrint('[DIDIT API DYNAMIC SESSION FALLBACK] $e');
        }
      }

      debugPrint('[DIDIT START VERIFICATION] Type: ${runKyb ? "KYB" : "KYC"} | UID: $uid | VendorSession: $vendorSessionUid | SessionID: $actualSessionId | URL: $selectedUrl');

      AvailFullScreenLoader.openLoadingDialog(
        'Initiating Didit ${runKyb ? "Business (KYB)" : "Individual (KYC)"} Verification...',
        'assets/images/animations/loader-animation.json',
      );

      final Map<String, dynamic> updateData = {
        'diditStatus': 'In Progress',
        'verificationStatus': 'pending',
        'diditVerified': false,
        if (runKyb) ...{
          'kybStatus': 'In Progress',
          'kybSessionId': actualSessionId ?? vendorSessionUid,
          'kybVerified': false,
          'diditBusinessSessionId': actualSessionId ?? vendorSessionUid,
        } else ...{
          'kycStatus': 'In Progress',
          'kycSessionId': actualSessionId ?? vendorSessionUid,
          'kycVerified': false,
          'diditSessionId': actualSessionId ?? vendorSessionUid,
        },
      };

      await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateData, SetOptions(merge: true));
      await loadCurrentUser();

      AvailFullScreenLoader.stopLoading();

      // Launch in WebView
      debugPrint('[DIDIT LAUNCHING IN-APP WEBVIEW] URL: $selectedUrl');
      await Get.to(
        () => DiditWebViewScreen(
          url: selectedUrl,
          title: runKyb ? 'Didit Business (KYB) Verification' : 'Didit Identity (KYC) Verification',
          isKyb: runKyb,
          vendorSessionId: vendorSessionUid,
        ),
        routeName: '/didit-verification-session',
      );

      debugPrint('[DIDIT RETURNED FROM WEBVIEW] Auto-syncing status for UID: $uid');
      await syncDiditVerificationStatus(
        isKyb: runKyb,
        expectedVendorSession: vendorSessionUid,
        expectedSessionId: actualSessionId,
      );
    } catch (e, stackTrace) {
      debugPrint('[DIDIT START VERIFICATION EXCEPTION] $e\n$stackTrace');
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    } finally {
      isStartingVerification.value = false;
    }
  }

  /// Extracts user-friendly decline reasons and warnings from Didit decision
  String _extractDeclineReason(Map<String, dynamic>? decision) {
    if (decision == null) return 'Verification declined by Didit automated checks.';
    final List<String> reasons = [];

    if (decision['decline_reasons'] is List) {
      for (var r in decision['decline_reasons']) {
        if (r != null && r.toString().trim().isNotEmpty) reasons.add(r.toString().trim());
      }
    }
    if (decision['warnings'] is List) {
      for (var w in decision['warnings']) {
        if (w != null && w.toString().trim().isNotEmpty) reasons.add(w.toString().trim());
      }
    }
    if (decision['reviews'] is List) {
      for (var rev in decision['reviews']) {
        if (rev is Map) {
          if (rev['comment'] != null && rev['comment'].toString().trim().isNotEmpty) {
            reasons.add(rev['comment'].toString().trim());
          }
          if (rev['reason'] != null && rev['reason'].toString().trim().isNotEmpty) {
            reasons.add(rev['reason'].toString().trim());
          }
        }
      }
    }

    final checkKeys = [
      'id_verifications',
      'liveness_checks',
      'face_matches',
      'aml_screenings',
      'poa_verifications',
      'database_validations',
      'business_verifications',
      'registry_checks',
    ];

    for (final key in checkKeys) {
      if (decision[key] is List) {
        for (var item in decision[key]) {
          if (item is Map) {
            if (item['decline_reasons'] is List) {
              for (var dr in item['decline_reasons']) {
                if (dr != null && dr.toString().trim().isNotEmpty) reasons.add(dr.toString().trim());
              }
            }
            if (item['warnings'] is List) {
              for (var w in item['warnings']) {
                if (w != null && w.toString().trim().isNotEmpty) reasons.add(w.toString().trim());
              }
            }
            final st = (item['status'] ?? '').toString();
            if (st.isNotEmpty && st.toLowerCase() != 'approved' && st.toLowerCase() != 'passed') {
              reasons.add('$key: $st');
            }
          }
        }
      }
    }

    final unique = reasons.toSet().toList();
    return unique.isNotEmpty ? unique.join('; ') : 'Verification declined by Didit automated checks.';
  }

  /// Sync/Reload verification status directly from Didit API, Firestore & Webhook Logs
  Future<void> syncDiditVerificationStatus({
    bool? isKyb,
    String? expectedVendorSession,
    String? expectedSessionId,
  }) async {
    try {
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) return;

      AvailFullScreenLoader.openLoadingDialog(
        'Syncing Verification Status...',
        'assets/images/animations/loader-animation.json',
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('[DIDIT SYNC START] Target UID: $uid');

      if (uid != null && uid.isNotEmpty) {
        // 1. Reload current user record from Firestore
        await loadCurrentUser();
        final currentUser = userModel.value;
        final bool isBiz = isKyb ?? currentUser.isBusiness;
        final String targetWorkflow = isBiz ? kybWorkflowId : kycWorkflowId;

        debugPrint('[DIDIT SYNC BEFORE] Firestore diditStatus: ${currentUser.diditStatus} | Track: ${isBiz ? "KYB" : "KYC"} | kybStatus: ${currentUser.kybStatus} | kycStatus: ${currentUser.kycStatus}');

        bool foundApproved = false;
        String approvedSessionId = '';
        bool foundDeclined = false;
        String declinedSessionId = '';
        String declineReason = '';

        // 2. Direct Didit REST API Check: Query live sessions from Didit Platform
        if (diditService.apiKey.isNotEmpty) {
          try {
            // A. Check specific session decision first if session ID is known
            final candidateSessionId = expectedSessionId ??
                (isBiz ? currentUser.diditBusinessSessionId : currentUser.diditSessionId);

            if (candidateSessionId.isNotEmpty && candidateSessionId.contains('-')) {
              debugPrint('[DIDIT SYNC API] Checking specific session decision: $candidateSessionId');
              final decision = await diditService.getSessionDecision(candidateSessionId);
              if (decision != null) {
                final status = (decision['status'] ?? '').toString();
                final statusLower = status.toLowerCase();
                debugPrint('[DIDIT SYNC API SPECIFIC DECISION] Session: $candidateSessionId | Status: $status');
                if (statusLower == 'approved') {
                  foundApproved = true;
                  approvedSessionId = candidateSessionId;
                } else if (statusLower == 'declined' || statusLower == 'rejected' || statusLower == 'failed') {
                  foundDeclined = true;
                  declinedSessionId = candidateSessionId;
                  declineReason = _extractDeclineReason(decision);
                }
              }
            }

            // B. Direct sessions list check
            if (!foundApproved && !foundDeclined) {
              debugPrint('[DIDIT SYNC API] Querying GET /v3/sessions/?session_kind=${isBiz ? "business" : "user"} ...');
              final sessions = await diditService.fetchSessions(
                sessionKind: isBiz ? 'business' : 'user',
              );
              debugPrint('[DIDIT SYNC API] Fetched ${sessions.length} sessions from Didit API');

              for (var session in sessions) {
                final status = (session['status'] ?? session['kyb_status'] ?? '').toString();
                final statusLower = status.toLowerCase();
                final isApproved = statusLower == 'approved';
                final isDeclined = statusLower == 'declined' || statusLower == 'rejected' || statusLower == 'failed';

                if (!isApproved && !isDeclined) continue;

                final vendorData = (session['vendor_data'] ?? '').toString();
                final sessionId = (session['session_id'] ?? '').toString();
                final sessionWorkflow = (session['workflow_id'] ?? session['workflowId'] ?? '').toString();

                debugPrint('[DIDIT SYNC API SESSION ITEM] ID: $sessionId | Status: $status | VendorData: $vendorData | Workflow: $sessionWorkflow');

                bool isMatch = false;

                // Match exact active vendor session if provided
                if (expectedVendorSession != null && expectedVendorSession.isNotEmpty) {
                  if (vendorData == expectedVendorSession) isMatch = true;
                } else if (activeVendorSession != null && activeVendorSession!.isNotEmpty) {
                  if (vendorData == activeVendorSession) isMatch = true;
                }

                if (!isMatch) {
                  if (isBiz) {
                    // Corporate KYB track: Must strictly start with kyb_<uid> or match kybWorkflowId (and NEVER start with kyc_)
                    if (vendorData.startsWith('kyb_$uid')) {
                      isMatch = true;
                    } else if (targetWorkflow.isNotEmpty && sessionWorkflow == targetWorkflow && (vendorData == uid || vendorData.startsWith(uid))) {
                      if (!vendorData.startsWith('kyc_')) {
                        isMatch = true;
                      }
                    }
                  } else {
                    // Individual KYC track: Must start with kyc_<uid> or legacy <uid> (and NEVER start with kyb_)
                    if (vendorData.startsWith('kyc_$uid')) {
                      isMatch = true;
                    } else if (targetWorkflow.isNotEmpty && sessionWorkflow == targetWorkflow && (vendorData == uid || vendorData.startsWith(uid))) {
                      if (!vendorData.startsWith('kyb_')) {
                        isMatch = true;
                      }
                    } else if (vendorData == uid || (vendorData.startsWith(uid) && !vendorData.startsWith('kyb_'))) {
                      // Legacy KYC session created before prefixing
                      if (sessionWorkflow.isEmpty || sessionWorkflow != kybWorkflowId) {
                        isMatch = true;
                      }
                    }
                  }
                }

                if (isMatch) {
                  if (isApproved) {
                    foundApproved = true;
                    approvedSessionId = sessionId;
                    debugPrint('[DIDIT SYNC MATCH SUCCESS] Approved Session found on Didit API! SessionID: $sessionId | VendorData: $vendorData');
                    break;
                  } else if (isDeclined) {
                    foundDeclined = true;
                    declinedSessionId = sessionId;
                    if (sessionId.isNotEmpty && sessionId.contains('-')) {
                      try {
                        final decision = await diditService.getSessionDecision(sessionId);
                        declineReason = _extractDeclineReason(decision);
                      } catch (_) {}
                    }
                    if (declineReason.isEmpty) {
                      declineReason = 'Verification declined by Didit automated checks.';
                    }
                    debugPrint('[DIDIT SYNC MATCH DECLINED] Declined Session found on Didit API! SessionID: $sessionId | Reason: $declineReason');
                    break;
                  }
                }
              }
            }
          } catch (e, stackTrace) {
            debugPrint('[DIDIT SYNC API ERROR] $e\n$stackTrace');
          }
        }

        // 3. Fallback: inspect DiditWebhookLogs & DiditWebhookEvents in Firestore with strict track filtering
        if (!foundApproved && !foundDeclined) {
          debugPrint('[DIDIT SYNC FIRESTORE FALLBACK] Inspecting DiditWebhookLogs and DiditWebhookEvents...');
          final logsQuery = await FirebaseFirestore.instance
              .collection('DiditWebhookLogs')
              .limit(50)
              .get();

          debugPrint('[DIDIT SYNC LOGS COUNT] Found ${logsQuery.docs.length} documents in DiditWebhookLogs');

          if (logsQuery.docs.isNotEmpty) {
            for (var doc in logsQuery.docs) {
              final data = doc.data();
              final status = (data['status'] ?? '').toString();
              final statusLower = status.toLowerCase();
              final isApproved = statusLower == 'approved';
              final isDeclined = statusLower == 'declined' || statusLower == 'rejected' || statusLower == 'failed';
              if (!isApproved && !isDeclined) continue;

              final vendorData = (data['vendorData'] ?? data['vendor_data'] ?? '').toString();
              final payload = data['payload'] is Map ? data['payload'] as Map : {};
              final payloadVendorData = (payload['vendor_data'] ?? payload['vendorData'] ?? '').toString();

              debugPrint('[DIDIT SYNC WEBHOOK LOG ITEM] ID: ${doc.id} | Status: $status | VendorData: $vendorData');

              bool isMatch = false;
              if (isBiz) {
                // Must belong to KYB track
                if (vendorData.startsWith('kyb_$uid') || payloadVendorData.startsWith('kyb_$uid')) {
                  isMatch = true;
                }
              } else {
                // Must belong to KYC track
                if ((vendorData.startsWith('kyc_$uid') || payloadVendorData.startsWith('kyc_$uid')) ||
                    (!vendorData.startsWith('kyb_') && !payloadVendorData.startsWith('kyb_') &&
                     (vendorData == uid || vendorData.startsWith(uid) || payloadVendorData == uid || payloadVendorData.startsWith(uid)))) {
                  isMatch = true;
                }
              }

              if (isMatch) {
                if (isApproved) {
                  foundApproved = true;
                  debugPrint('[DIDIT SYNC MATCH LOGS] Approved Webhook Log found for UID: $uid');
                  break;
                } else if (isDeclined) {
                  foundDeclined = true;
                  declineReason = _extractDeclineReason(payload['decision'] is Map ? Map<String, dynamic>.from(payload['decision']) : null);
                  debugPrint('[DIDIT SYNC MATCH LOGS] Declined Webhook Log found for UID: $uid | Reason: $declineReason');
                  break;
                }
              }
            }
          }

          if (!foundApproved && !foundDeclined) {
            final eventsQuery = await FirebaseFirestore.instance
                .collection('DiditWebhookEvents')
                .limit(50)
                .get();

            debugPrint('[DIDIT SYNC EVENTS COUNT] Found ${eventsQuery.docs.length} documents in DiditWebhookEvents');

            if (eventsQuery.docs.isNotEmpty) {
              for (var doc in eventsQuery.docs) {
                final data = doc.data();
                final status = (data['status'] ?? '').toString().toLowerCase();
                final isApproved = status == 'approved';
                final isDeclined = status == 'declined' || status == 'rejected' || status == 'failed';
                if (!isApproved && !isDeclined) continue;

                final vendorData = (data['vendorData'] ?? data['vendor_data'] ?? '').toString();
                bool isMatch = false;
                if (isBiz) {
                  if (vendorData.startsWith('kyb_$uid')) {
                    isMatch = true;
                  }
                } else {
                  if (vendorData.startsWith('kyc_$uid') ||
                      (!vendorData.startsWith('kyb_') && (vendorData == uid || vendorData.startsWith(uid)))) {
                    isMatch = true;
                  }
                }

                if (isMatch) {
                  if (isApproved) {
                    foundApproved = true;
                    debugPrint('[DIDIT SYNC MATCH EVENTS] Approved Event found for UID: $uid');
                    break;
                  } else if (isDeclined) {
                    foundDeclined = true;
                    if (declineReason.isEmpty) {
                      declineReason = 'Verification declined by Didit automated checks.';
                    }
                    debugPrint('[DIDIT SYNC MATCH EVENTS] Declined Event found for UID: $uid');
                    break;
                  }
                }
              }
            }
          }
        }

        // 4. Update Firestore user document if Approved session was confirmed
        if (foundApproved) {
          debugPrint('[DIDIT SYNC UPDATING FIRESTORE] Updating Users/$uid to Approved for track: ${isBiz ? "KYB" : "KYC"}...');
          final updateMap = <String, dynamic>{
            'diditStatus': 'Approved',
            'diditVerified': true,
            'verificationStatus': 'approved',
            if (approvedSessionId.isNotEmpty) 'diditSessionId': approvedSessionId,
            'verifiedAt': DateTime.now().toIso8601String(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (isBiz) ...{
              'kybStatus': 'Approved',
              'kybVerified': true,
              if (approvedSessionId.isNotEmpty) 'kybSessionId': approvedSessionId,
              if (currentUser.kybAdminApprovalStatus != 'approved') 'kybAdminApprovalStatus': 'pending',
            } else ...{
              'kycStatus': 'Approved',
              'kycVerified': true,
              if (approvedSessionId.isNotEmpty) 'kycSessionId': approvedSessionId,
              if (currentUser.kycAdminApprovalStatus != 'approved') 'kycAdminApprovalStatus': 'pending',
            },
          };

          // Policy: Ensure active admin approval status is preserved or initialized to pending
          if (currentUser.adminApprovalStatus.isEmpty) {
            updateMap['adminApprovalStatus'] = 'pending';
          }

          await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateMap, SetOptions(merge: true));
          await loadCurrentUser();
        } else if (foundDeclined) {
          debugPrint('[DIDIT SYNC UPDATING FIRESTORE] Updating Users/$uid to Declined for track: ${isBiz ? "KYB" : "KYC"}...');
          final updateMap = <String, dynamic>{
            'diditStatus': 'Declined',
            'diditVerified': false,
            'verificationStatus': 'declined',
            if (declinedSessionId.isNotEmpty) 'diditSessionId': declinedSessionId,
            'rejectionReason': declineReason.isNotEmpty ? declineReason : 'Verification declined by Didit automated checks.',
            'updatedAt': FieldValue.serverTimestamp(),
            if (isBiz) ...{
              'kybStatus': 'Declined',
              'kybVerified': false,
              if (declinedSessionId.isNotEmpty) 'kybSessionId': declinedSessionId,
              'kybAdminRejectionReason': declineReason,
            } else ...{
              'kycStatus': 'Declined',
              'kycVerified': false,
              if (declinedSessionId.isNotEmpty) 'kycSessionId': declinedSessionId,
              'kycAdminRejectionReason': declineReason,
            },
          };

          await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateMap, SetOptions(merge: true));
          await loadCurrentUser();
        }
      }

      AvailFullScreenLoader.stopLoading();

      final user = userModel.value;
      final currentStatus = user.diditStatus;
      debugPrint('[DIDIT FINAL SYNC STATUS] Status: $currentStatus | Verified: ${user.diditVerified} | AdminApproval: ${user.adminApprovalStatus}');

      if (user.canWork) {
        AvailLoaders.successSnackBar(
          title: 'Account Fully Activated',
          message: 'Your account is verified and approved by admin. You can dispatch freight anytime!',
        );
      } else if (user.isUnderAdminReview) {
        AvailLoaders.successSnackBar(
          title: 'KYC Verified - Admin Review Pending',
          message: 'Identity verified successfully! Fleet Operations Admin is reviewing your profile for final activation.',
        );
      } else if (user.isAdminRejected) {
        AvailLoaders.errorSnackBar(
          title: 'Admin Review Declined',
          message: user.adminRejectionReason.isNotEmpty
              ? 'Reason: ${user.adminRejectionReason}'
              : 'Your verification was declined by the administration.',
        );
      } else if (currentStatus.toLowerCase() == 'declined' || user.verificationStatus == 'declined') {
        AvailLoaders.errorSnackBar(
          title: 'Verification Declined',
          message: 'Your biometric/document verification was declined by Didit. Please try again.',
        );
      } else {
        AvailLoaders.warningSnackBar(
          title: 'Verification In Progress',
          message: 'Your verification status is being synced. Please tap refresh in a moment.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[DIDIT MANUAL SYNC ERROR] $e\n$stackTrace');
      AvailFullScreenLoader.stopLoading();
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    }
  }

  /// Reset verification for the current active track (KYB or KYC) back to 'Not Started' / 'pending'
  Future<void> resetVerificationForActiveTrack() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      AvailFullScreenLoader.openLoadingDialog(
        'Resetting Verification...',
        'assets/images/animations/loader-animation.json',
      );

      final isBiz = userModel.value.isBusiness;
      final updateMap = <String, dynamic>{
        'diditStatus': 'Not Started',
        'diditVerified': false,
        'verificationStatus': 'pending',
        'adminApprovalStatus': 'pending',
        'adminApproved': false,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isBiz) ...{
          'kybStatus': 'Not Started',
          'kybVerified': false,
          'kybSessionId': '',
          'diditBusinessSessionId': '',
          'kybAdminApprovalStatus': 'pending',
          'kybAdminApproved': false,
        } else ...{
          'kycStatus': 'Not Started',
          'kycVerified': false,
          'kycSessionId': '',
          'diditSessionId': '',
          'kycAdminApprovalStatus': 'pending',
          'kycAdminApproved': false,
        },
      };

      await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateMap, SetOptions(merge: true));
      await loadCurrentUser();

      AvailFullScreenLoader.stopLoading();
      AvailLoaders.successSnackBar(
        title: 'Status Reset',
        message: 'Verification status has been reset to Not Started.',
      );
    } catch (e) {
      AvailFullScreenLoader.stopLoading();
      debugPrint('[DIDIT RESET ERROR] $e');
      AvailLoaders.errorSnackBar(title: 'Error', message: e.toString());
    }
  }

  /// Save or update Shipper ID (National ID/Passport) or Company registration details
  Future<bool> saveShipperKycDocuments({
    String? idDocumentType,
    String? idDocumentName,
    String? idDocumentNumber,
    String? idDocumentExpiry,
    String? companyName,
    String? registrationNumber,
    String? businessAddress,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        AvailLoaders.errorSnackBar(title: 'Error', message: 'User session not found.');
        return false;
      }

      final isBiz = userModel.value.isBusiness;
      final updateData = <String, dynamic>{
        if (idDocumentType != null) 'idDocumentType': idDocumentType.trim(),
        if (idDocumentName != null) 'idDocumentName': idDocumentName.trim(),
        if (idDocumentNumber != null) 'idDocumentNumber': idDocumentNumber.trim(),
        if (idDocumentExpiry != null) 'idDocumentExpiry': idDocumentExpiry.trim(),
        if (companyName != null && companyName.trim().isNotEmpty) 'companyName': companyName.trim(),
        if (registrationNumber != null && registrationNumber.trim().isNotEmpty)
          'registrationNumber': registrationNumber.trim(),
        if (businessAddress != null && businessAddress.trim().isNotEmpty)
          'businessAddress': businessAddress.trim(),
        if (isBiz) 'kybFormSubmitted': true else 'kycFormSubmitted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateData, SetOptions(merge: true));
      await loadCurrentUser();

      AvailLoaders.successSnackBar(
        title: 'Credentials Saved',
        message: 'Document details registered successfully. Ready for DIDIT Live Scan.',
      );
      return true;
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Save Failed', message: e.toString());
      return false;
    }
  }

  /// Update shipper account type ('individual' vs 'business') with track separation
  Future<void> updateAccountType(
    String newType, {
    String? companyName,
    String? registrationNumber,
    String? businessAddress,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      final isNewBusiness = newType.toLowerCase() == 'business';
      final currentUser = userModel.value;

      // Extract existing verification and admin approval status for the TARGET track
      final targetVerified = isNewBusiness
          ? currentUser.kybVerified
          : currentUser.kycVerified;
      final targetStatus = isNewBusiness
          ? (currentUser.kybStatus.isNotEmpty ? currentUser.kybStatus : 'Not Started')
          : (currentUser.kycStatus.isNotEmpty ? currentUser.kycStatus : 'Not Started');
      final targetAdminStatus = isNewBusiness
          ? (currentUser.kybAdminApprovalStatus.isNotEmpty ? currentUser.kybAdminApprovalStatus : 'pending')
          : (currentUser.kycAdminApprovalStatus.isNotEmpty ? currentUser.kycAdminApprovalStatus : 'pending');
      final targetRejectionReason = isNewBusiness
          ? currentUser.kybAdminRejectionReason
          : currentUser.kycAdminRejectionReason;

      final updateData = <String, dynamic>{
        'accountType': newType.toLowerCase(),
        'role': isNewBusiness ? 'business_shipper' : 'shipper',
        'verificationType': isNewBusiness ? 'kyb' : 'kyc',
        // Update top-level cache to match the TARGET track
        'diditStatus': targetStatus,
        'diditVerified': targetVerified,
        'verificationStatus': targetVerified ? 'approved' : (targetStatus == 'Not Started' ? 'unverified' : targetStatus.toLowerCase()),
        'adminApprovalStatus': targetAdminStatus,
        'adminApproved': targetAdminStatus.toLowerCase() == 'approved',
        'adminRejectionReason': targetRejectionReason,
        if (companyName != null && companyName.trim().isNotEmpty) 'companyName': companyName.trim(),
        if (registrationNumber != null && registrationNumber.trim().isNotEmpty)
          'registrationNumber': registrationNumber.trim(),
        if (businessAddress != null && businessAddress.trim().isNotEmpty)
          'businessAddress': businessAddress.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateData, SetOptions(merge: true));
      await loadCurrentUser();

      AvailLoaders.successSnackBar(
        title: 'Account Type Switched',
        message: isNewBusiness
            ? 'Switched to Corporate Shipper. Business KYB & Admin Approval required to dispatch corporate freight.'
            : 'Switched to Individual Shipper. Personal KYC & Admin Approval required to dispatch personal freight.',
      );
    } catch (e) {
      AvailLoaders.errorSnackBar(title: 'Update Failed', message: e.toString());
    }
  }

  /// Helper method to manually set verification status for testing/debugging
  Future<void> debugSetVerificationStatus(String status) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        final isApproved = status.toLowerCase() == 'approved';
        final isBiz = userModel.value.isBusiness;
        final updateMap = <String, dynamic>{
          'diditStatus': status,
          'diditVerified': isApproved,
          'verificationStatus': isApproved ? 'approved' : status.toLowerCase(),
          'verifiedAt': isApproved ? DateTime.now().toIso8601String() : null,
          'updatedAt': FieldValue.serverTimestamp(),
          if (isBiz) ...{
            'kybStatus': status,
            'kybVerified': isApproved,
          } else ...{
            'kycStatus': status,
            'kycVerified': isApproved,
          },
        };
        await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateMap, SetOptions(merge: true));
        await loadCurrentUser();
      }
    } catch (e) {
      debugPrint('[DIDIT DEBUG SET STATUS ERROR] $e');
    }
  }

  /// Helper method to manually set Admin Operations Approval status for testing/debugging
  Future<void> debugSetAdminApprovalStatus(String status, {String rejectionReason = ''}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        final isApproved = status.toLowerCase() == 'approved';
        final isBiz = userModel.value.isBusiness;
        final updateMap = <String, dynamic>{
          'adminApprovalStatus': status.toLowerCase(),
          'adminApproved': isApproved,
          'adminApprovalDate': isApproved ? DateTime.now().toIso8601String() : '',
          'adminRejectionReason': rejectionReason,
          'updatedAt': FieldValue.serverTimestamp(),
          if (isBiz) ...{
            'kybAdminApprovalStatus': status.toLowerCase(),
            'kybAdminApprovalDate': isApproved ? DateTime.now().toIso8601String() : '',
            'kybAdminRejectionReason': rejectionReason,
          } else ...{
            'kycAdminApprovalStatus': status.toLowerCase(),
            'kycAdminApprovalDate': isApproved ? DateTime.now().toIso8601String() : '',
            'kycAdminRejectionReason': rejectionReason,
          },
        };

        await FirebaseFirestore.instance.collection('Users').doc(uid).set(updateMap, SetOptions(merge: true));
        await loadCurrentUser();
      }
    } catch (e) {
      debugPrint('[DIDIT DEBUG SET ADMIN STATUS ERROR] $e');
    }
  }

  Future<void> pickImage(ImageSource source, String type) async {}
  Future<void> submitKycVerification() async {}
  Future<void> submitKybVerification() async {}
}
