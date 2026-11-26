import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/constants/country_codes.dart';
import '../../../utils/formatters/formatter.dart';

class UserAccountModel {
  /// Keep those values final which you do not want to update
  String id;
  String firstName;
  String lastName;
  String username;
  String email;
  String phoneNumber;
  String profilePicture;
  String gender;
  String country;
  String countryCode;
  bool allowDataUsage;
  String fcmToken;
  Map<String, bool> notificationPreferences;
  
  // User / Shipper / Driver Role
  String role; // admin, shipper, business_shipper, driver
  String vehicleType; // motor, car, van
  String licensePlate;
  String status; // online, offline, busy
  GeoPoint? currentLocation;

  // Account Type & Business Fields
  String accountType; // 'individual' or 'business'
  String companyName;
  String registrationNumber; // Tax ID / Business Reg Number
  String businessAddress;

  // Shipper KYC Document Fields (National ID / Passport)
  String idDocumentType; // 'National ID', 'Passport', 'Driver License', 'Voter ID'
  String idDocumentName; // Legal Name on ID Document
  String idDocumentNumber; // ID or Passport Number
  String idDocumentExpiry; // Expiry Date (YYYY-MM-DD)
  bool kycFormSubmitted;

  // Individual KYC Track Fields
  bool kycVerified;
  String kycStatus; // 'Not Started', 'In Progress', 'Pending Review', 'Approved', 'Declined'
  String kycSessionId;
  String kycAdminApprovalStatus; // 'pending', 'approved', 'rejected'
  String kycAdminRejectionReason;
  String kycAdminApprovalDate;

  // Business KYB Track Fields
  bool kybVerified;
  String kybStatus; // 'Not Started', 'In Progress', 'Pending Review', 'Approved', 'Declined'
  String kybSessionId;
  String kybAdminApprovalStatus; // 'pending', 'approved', 'rejected'
  String kybAdminRejectionReason;
  String kybAdminApprovalDate;
  bool kybFormSubmitted;

  // DID / Didit Identity Verification Fields (Active track / top-level cache)
  String verificationStatus; // 'unverified', 'pending', 'approved', 'declined'
  String verificationType; // 'none', 'kyc', 'kyb'
  String diditRequestId;
  String verifiedAt;
  String rejectionReason;

  // Didit Hosted Session Verification Fields (matching admin panel implementation)
  String diditSessionId;
  String diditBusinessSessionId;
  String diditStatus; // 'Not Started', 'In Progress', 'Pending Review', 'Approved', 'Declined'
  bool diditVerified;

  // Admin Approval Fields (Active track / top-level cache)
  String adminApprovalStatus; // 'pending', 'approved', 'rejected'
  String adminRejectionReason;
  String adminApprovalDate;

  /// Constructor for UserAccountModel
  UserAccountModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.profilePicture,
    this.gender = '',
    this.country = '',
    this.countryCode = '',
    this.allowDataUsage = true,
    this.fcmToken = '',
    this.notificationPreferences = const {},
    this.role = 'shipper',
    this.vehicleType = '',
    this.licensePlate = '',
    this.status = 'offline',
    this.currentLocation,
    this.accountType = 'individual',
    this.companyName = '',
    this.registrationNumber = '',
    this.businessAddress = '',
    this.idDocumentType = 'National ID',
    this.idDocumentName = '',
    this.idDocumentNumber = '',
    this.idDocumentExpiry = '',
    this.kycFormSubmitted = false,
    this.kycVerified = false,
    this.kycStatus = 'Not Started',
    this.kycSessionId = '',
    this.kycAdminApprovalStatus = 'pending',
    this.kycAdminRejectionReason = '',
    this.kycAdminApprovalDate = '',
    this.kybVerified = false,
    this.kybStatus = 'Not Started',
    this.kybSessionId = '',
    this.kybAdminApprovalStatus = 'pending',
    this.kybAdminRejectionReason = '',
    this.kybAdminApprovalDate = '',
    this.kybFormSubmitted = false,
    this.verificationStatus = 'unverified',
    this.verificationType = 'none',
    this.diditRequestId = '',
    this.verifiedAt = '',
    this.rejectionReason = '',
    this.diditSessionId = '',
    this.diditBusinessSessionId = '',
    this.diditStatus = 'Not Started',
    this.diditVerified = false,
    this.adminApprovalStatus = 'pending',
    this.adminRejectionReason = '',
    this.adminApprovalDate = '',
  });

  /// Helper function to get the full name.
  String get fullName => '$firstName $lastName';

  bool get isBusiness =>
      accountType.toLowerCase() == 'business' ||
      role == 'business_shipper' ||
      role == 'agent';
  bool get isIndividual => !isBusiness;

  /// Active profile's automated verification status
  bool get isVerified {
    if (isBusiness) {
      return kybVerified ||
          kybStatus.toLowerCase() == 'approved' ||
          (accountType == 'business' && (diditVerified || diditStatus.toLowerCase() == 'approved' || verificationStatus.toLowerCase() == 'approved'));
    } else {
      return kycVerified ||
          kycStatus.toLowerCase() == 'approved' ||
          (accountType == 'individual' && (diditVerified || diditStatus.toLowerCase() == 'approved' || verificationStatus.toLowerCase() == 'approved'));
    }
  }

  /// Active profile's admin operations approval status
  bool get isApprovedByAdmin {
    if (isBusiness) {
      return kybAdminApprovalStatus.toLowerCase() == 'approved' ||
          (accountType == 'business' && adminApprovalStatus.toLowerCase() == 'approved');
    } else {
      return kycAdminApprovalStatus.toLowerCase() == 'approved' ||
          (accountType == 'individual' && adminApprovalStatus.toLowerCase() == 'approved');
    }
  }

  /// Active profile was declined by admin
  bool get isAdminRejected {
    final status = isBusiness ? kybAdminApprovalStatus.toLowerCase() : kycAdminApprovalStatus.toLowerCase();
    return status == 'rejected' || adminApprovalStatus.toLowerCase() == 'rejected';
  }

  /// Active profile is waiting for admin approval
  bool get isUnderAdminReview => isVerified && !isApprovedByAdmin && !isAdminRejected;

  String get activeAdminApprovalStatus {
    if (isApprovedByAdmin) return 'approved';
    if (isAdminRejected) return 'rejected';
    final status = isBusiness ? kybAdminApprovalStatus : kycAdminApprovalStatus;
    if (status.isNotEmpty) return status;
    return adminApprovalStatus;
  }

  String get activeAdminRejectionReason {
    final specific = isBusiness ? kybAdminRejectionReason : kycAdminRejectionReason;
    if (specific.isNotEmpty) return specific;
    return adminRejectionReason;
  }

  String get activeVerificationStatus => isBusiness ? kybStatus : kycStatus;

  /// Shipper can ONLY book trucks, dispatch loads, and work in the app if BOTH:
  /// 1. Identity / Corporate verification is completed (isVerified)
  /// 2. Freight Operations Admin has approved the account (isApprovedByAdmin)
  bool get canWork => isVerified && isApprovedByAdmin;

  bool get canBookFreight => canWork;

  /// Checks whether shipper has filled in required KYC/KYB credentials
  bool get hasSubmittedKycDocs {
    if (isBusiness) {
      return kybFormSubmitted || (companyName.trim().isNotEmpty && registrationNumber.trim().isNotEmpty);
    }
    return kycFormSubmitted || idDocumentNumber.trim().isNotEmpty;
  }

  /// Check whether ID document is expired
  bool get isIdDocumentExpired {
    if (idDocumentExpiry.trim().isEmpty) return false;
    try {
      final expiry = DateTime.parse(idDocumentExpiry.trim());
      return expiry.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Helper function to format phone number with country code.
  String get formattedPhoneNo {
    if (countryCode.isEmpty) return AvailFormatter.formatPhoneNumber(phoneNumber);

    // Find the country to get the phone code
    final country = AvailCountry.africanCountries.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => AvailCountry.africanCountries.firstWhere((c) => c.name == 'Ghana'),
    );

    return AvailFormatter.formatPhoneNumber(phoneNumber, countryCode: country.phoneCode);
  }

  /// Static function to split full name into first and last name.
  static List<String> nameParts(String fullName) => fullName.split(" ");

  /// Static function to generate a username from the full name.
  static String generateUsername(String fullName) {
    // Split the full name into parts (e.g., first and last name)
    List<String> nameParts = fullName.split(" ");

    // Convert first name to lowercase
    String firstName = nameParts[0].toLowerCase();

    // Convert last name to lowercase if it exists
    String lastName = nameParts.length > 1 ? nameParts[1].toLowerCase() : "";

    // Combine first and last name into camelCase format
    String camelCaseUsername = firstName + lastName;

    // Add "crt_" prefix to the username
    String usernameWithPrefix = "user_$camelCaseUsername";

    // Return the final formatted username
    return usernameWithPrefix;
  }

  /// Static function to create an empty user model.
  static UserAccountModel empty() => UserAccountModel(
    id: '',
    firstName: '',
    lastName: '',
    username: '',
    email: '',
    phoneNumber: '',
    profilePicture: '',
    country: '',
    countryCode: '',
    allowDataUsage: true,
    fcmToken: '',
    notificationPreferences: {},
    accountType: 'individual',
    companyName: '',
    registrationNumber: '',
    businessAddress: '',
    idDocumentType: 'National ID',
    idDocumentName: '',
    idDocumentNumber: '',
    idDocumentExpiry: '',
    kycFormSubmitted: false,
    kycVerified: false,
    kycStatus: 'Not Started',
    kycSessionId: '',
    kycAdminApprovalStatus: 'pending',
    kycAdminRejectionReason: '',
    kycAdminApprovalDate: '',
    kybVerified: false,
    kybStatus: 'Not Started',
    kybSessionId: '',
    kybAdminApprovalStatus: 'pending',
    kybAdminRejectionReason: '',
    kybAdminApprovalDate: '',
    kybFormSubmitted: false,
    verificationStatus: 'unverified',
    verificationType: 'none',
    diditRequestId: '',
    verifiedAt: '',
    rejectionReason: '',
    diditSessionId: '',
    diditBusinessSessionId: '',
    diditStatus: 'Not Started',
    diditVerified: false,
    adminApprovalStatus: 'pending',
    adminRejectionReason: '',
    adminApprovalDate: '',
  );

  /// Convert the user model to a JSON map for Firebase or API usage.
  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
      'gender': gender,
      'country': country,
      'countryCode': countryCode,
      'allowDataUsage': allowDataUsage,
      'fcmToken': fcmToken,
      'notificationPreferences': notificationPreferences,
      'role': role,
      'vehicleType': vehicleType,
      'licensePlate': licensePlate,
      'status': status,
      'currentLocation': currentLocation,
      'accountType': accountType,
      'companyName': companyName,
      'registrationNumber': registrationNumber,
      'businessAddress': businessAddress,
      'idDocumentType': idDocumentType,
      'idDocumentName': idDocumentName,
      'idDocumentNumber': idDocumentNumber,
      'idDocumentExpiry': idDocumentExpiry,
      'kycFormSubmitted': kycFormSubmitted,
      'kycVerified': kycVerified,
      'kycStatus': kycStatus,
      'kycSessionId': kycSessionId,
      'kycAdminApprovalStatus': kycAdminApprovalStatus,
      'kycAdminRejectionReason': kycAdminRejectionReason,
      'kycAdminApprovalDate': kycAdminApprovalDate,
      'kybVerified': kybVerified,
      'kybStatus': kybStatus,
      'kybSessionId': kybSessionId,
      'kybAdminApprovalStatus': kybAdminApprovalStatus,
      'kybAdminRejectionReason': kybAdminRejectionReason,
      'kybAdminApprovalDate': kybAdminApprovalDate,
      'kybFormSubmitted': kybFormSubmitted,
      'verificationStatus': verificationStatus,
      'verificationType': verificationType,
      'diditRequestId': diditRequestId,
      'verifiedAt': verifiedAt,
      'rejectionReason': rejectionReason,
      'diditSessionId': diditSessionId,
      'diditBusinessSessionId': diditBusinessSessionId,
      'diditStatus': diditStatus,
      'diditVerified': diditVerified,
      'adminApprovalStatus': adminApprovalStatus,
      'adminRejectionReason': adminRejectionReason,
      'adminApprovalDate': adminApprovalDate,
    };
  }

  /// Factory constructor to create a UserAccountModel from a Firebase document snapshot.
  factory UserAccountModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data != null) {
      final accType = (data['accountType'] ?? data['AccountType'] ?? 'individual').toString().toLowerCase();
      final isBiz = accType == 'business' ||
          data['role'] == 'business_shipper' ||
          data['role'] == 'agent';

      final topDiditVerified = data['diditVerified'] ?? (data['verificationStatus'] == 'approved');
      final topDiditStatus = (data['diditStatus'] ?? 'Not Started').toString();
      final topAdminStatus = (data['adminApprovalStatus'] ?? (data['adminApproved'] == true ? 'approved' : 'pending')).toString();
      final isTopApproved = topAdminStatus.toLowerCase() == 'approved' || data['adminApproved'] == true;
      final isTopRejected = topAdminStatus.toLowerCase() == 'rejected';

      final rawKycAdmin = (data['kycAdminApprovalStatus'] ?? '').toString().toLowerCase();
      final rawKybAdmin = (data['kybAdminApprovalStatus'] ?? '').toString().toLowerCase();

      final kycAdminStatus = (rawKycAdmin == 'approved' || (!isBiz && isTopApproved))
          ? 'approved'
          : (rawKycAdmin == 'rejected' || (!isBiz && isTopRejected)
              ? 'rejected'
              : (rawKycAdmin.isNotEmpty ? rawKycAdmin : (!isBiz ? topAdminStatus : 'pending')));

      final kybAdminStatus = (rawKybAdmin == 'approved' || (isBiz && isTopApproved))
          ? 'approved'
          : (rawKybAdmin == 'rejected' || (isBiz && isTopRejected)
              ? 'rejected'
              : (rawKybAdmin.isNotEmpty ? rawKybAdmin : (isBiz ? topAdminStatus : 'pending')));

      return UserAccountModel(
        id: document.id,
        firstName: data['firstName'] ?? data['FirstName'] ?? data['first_name'] ?? '',
        lastName: data['lastName'] ?? data['LastName'] ?? data['last_name'] ?? '',
        username: data['username'] ?? data['Username'] ?? '',
        email: data['email'] ?? data['Email'] ?? '',
        phoneNumber: data['phoneNumber'] ?? data['PhoneNumber'] ?? data['phone_number'] ?? '',
        profilePicture: data['profilePicture'] ?? data['ProfilePicture'] ?? data['profile_picture'] ?? '',
        gender: data['gender'] ?? data['Gender'] ?? '',
        country: data['country'] ?? data['Country'] ?? '',
        countryCode: data['countryCode'] ?? data['CountryCode'] ?? '',
        allowDataUsage: data['allowDataUsage'] ?? data['AllowDataUsage'] ?? true,
        fcmToken: data['fcmToken'] ?? data['FcmToken'] ?? '',
        notificationPreferences: Map<String, bool>.from(data['notificationPreferences'] ?? data['NotificationPreferences'] ?? {}),
        role: data['role'] ?? data['Role'] ?? (isBiz ? 'business_shipper' : 'shipper'),
        vehicleType: data['vehicleType'] ?? data['VehicleType'] ?? '',
        licensePlate: data['licensePlate'] ?? data['LicensePlate'] ?? '',
        status: data['status'] ?? data['Status'] ?? 'offline',
        currentLocation: (data['currentLocation'] ?? data['CurrentLocation']) as GeoPoint?,
        accountType: accType,
        companyName: data['companyName'] ?? data['CompanyName'] ?? '',
        registrationNumber: data['registrationNumber'] ?? data['RegistrationNumber'] ?? '',
        businessAddress: data['businessAddress'] ?? data['BusinessAddress'] ?? '',
        idDocumentType: data['idDocumentType'] ?? data['IdDocumentType'] ?? 'National ID',
        idDocumentName: data['idDocumentName'] ?? data['IdDocumentName'] ?? '',
        idDocumentNumber: data['idDocumentNumber'] ?? data['IdDocumentNumber'] ?? '',
        idDocumentExpiry: data['idDocumentExpiry'] ?? data['IdDocumentExpiry'] ?? '',
        kycFormSubmitted: data['kycFormSubmitted'] ?? data['KycFormSubmitted'] ?? false,
        kycVerified: data['kycVerified'] ?? (!isBiz ? topDiditVerified : false),
        kycStatus: data['kycStatus'] ?? (!isBiz ? topDiditStatus : 'Not Started'),
        kycSessionId: data['kycSessionId'] ?? (!isBiz ? (data['diditSessionId'] ?? '') : ''),
        kycAdminApprovalStatus: kycAdminStatus,
        kycAdminRejectionReason: data['kycAdminRejectionReason'] ?? (!isBiz ? (data['adminRejectionReason'] ?? '') : ''),
        kycAdminApprovalDate: data['kycAdminApprovalDate'] ?? (!isBiz ? (data['adminApprovalDate'] ?? data['adminApprovedAt'] ?? '') : ''),
        kybVerified: data['kybVerified'] ?? (isBiz ? topDiditVerified : false),
        kybStatus: data['kybStatus'] ?? (isBiz ? topDiditStatus : 'Not Started'),
        kybSessionId: data['kybSessionId'] ?? (isBiz ? (data['diditBusinessSessionId'] ?? data['diditSessionId'] ?? '') : ''),
        kybAdminApprovalStatus: kybAdminStatus,
        kybAdminRejectionReason: data['kybAdminRejectionReason'] ?? (isBiz ? (data['adminRejectionReason'] ?? '') : ''),
        kybAdminApprovalDate: data['kybAdminApprovalDate'] ?? (isBiz ? (data['adminApprovalDate'] ?? data['adminApprovedAt'] ?? '') : ''),
        kybFormSubmitted: data['kybFormSubmitted'] ?? (data['companyName'] != null && data['companyName'].toString().trim().isNotEmpty),
        verificationStatus: data['verificationStatus'] ?? data['VerificationStatus'] ?? 'unverified',
        verificationType: data['verificationType'] ?? data['VerificationType'] ?? (isBiz ? 'kyb' : 'kyc'),
        diditRequestId: data['diditRequestId'] ?? data['DiditRequestId'] ?? '',
        verifiedAt: data['verifiedAt'] ?? data['VerifiedAt'] ?? '',
        rejectionReason: data['rejectionReason'] ?? data['RejectionReason'] ?? '',
        diditSessionId: data['diditSessionId'] ?? '',
        diditBusinessSessionId: data['diditBusinessSessionId'] ?? '',
        diditStatus: data['diditStatus'] ?? 'Not Started',
        diditVerified: topDiditVerified,
        adminApprovalStatus: topAdminStatus,
        adminRejectionReason: data['adminRejectionReason'] ?? '',
        adminApprovalDate: data['adminApprovalDate'] ?? data['adminApprovedAt'] ?? '',
      );
    }
    return UserAccountModel.empty();
  }
}
