import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../controllers/verification_controller.dart';
import '../../../shop/models/user_account_model.dart';

class DiditVerificationScreen extends StatefulWidget {
  const DiditVerificationScreen({super.key});

  @override
  State<DiditVerificationScreen> createState() => _DiditVerificationScreenState();
}

class _DiditVerificationScreenState extends State<DiditVerificationScreen> {
  final _individualFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();

  // Individual Shipper Form Controllers
  String _idDocType = 'National ID';
  late final TextEditingController _idDocNameController;
  late final TextEditingController _idDocNumberController;
  late final TextEditingController _idDocExpiryController;

  // Business Shipper Form Controllers
  late final TextEditingController _companyNameController;
  late final TextEditingController _registrationNumberController;
  late final TextEditingController _businessAddressController;

  bool _isEditingDocs = false;
  bool _isSavingDocs = false;
  bool _initializedWithUser = false;

  @override
  void initState() {
    super.initState();
    _idDocNameController = TextEditingController();
    _idDocNumberController = TextEditingController();
    _idDocExpiryController = TextEditingController();

    _companyNameController = TextEditingController();
    _registrationNumberController = TextEditingController();
    _businessAddressController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<VerificationController>()) {
        VerificationController.instance.loadCurrentUser();
      }
    });
  }

  @override
  void dispose() {
    _idDocNameController.dispose();
    _idDocNumberController.dispose();
    _idDocExpiryController.dispose();

    _companyNameController.dispose();
    _registrationNumberController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  void _syncControllersWithUser(UserAccountModel user) {
    if (_initializedWithUser) return;
    if (user.id.isNotEmpty) {
      if (user.idDocumentType.isNotEmpty) _idDocType = user.idDocumentType;
      _idDocNameController.text = user.idDocumentName.isNotEmpty ? user.idDocumentName : user.fullName;
      _idDocNumberController.text = user.idDocumentNumber;
      _idDocExpiryController.text = user.idDocumentExpiry;

      _companyNameController.text = user.companyName;
      _registrationNumberController.text = user.registrationNumber;
      _businessAddressController.text = user.businessAddress;

      _initializedWithUser = true;
    }
  }

  Future<void> _selectExpiryDate(BuildContext context, TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initial = now.add(const Duration(days: 365));

    if (controller.text.isNotEmpty) {
      try {
        initial = DateTime.parse(controller.text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 15)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AvailColors.primary,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveIndividualDocs(VerificationController controller) async {
    if (!_individualFormKey.currentState!.validate()) return;

    setState(() => _isSavingDocs = true);
    final success = await controller.saveShipperKycDocuments(
      idDocumentType: _idDocType,
      idDocumentName: _idDocNameController.text.trim(),
      idDocumentNumber: _idDocNumberController.text.trim(),
      idDocumentExpiry: _idDocExpiryController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSavingDocs = false;
        if (success) _isEditingDocs = false;
      });
    }
  }

  Future<void> _saveBusinessDocs(VerificationController controller) async {
    if (!_businessFormKey.currentState!.validate()) return;

    setState(() => _isSavingDocs = true);
    final success = await controller.saveShipperKycDocuments(
      companyName: _companyNameController.text.trim(),
      registrationNumber: _registrationNumberController.text.trim(),
      businessAddress: _businessAddressController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSavingDocs = false;
        if (success) _isEditingDocs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(VerificationController());

    return Obx(() {
      final user = controller.userModel.value;
      _syncControllersWithUser(user);

      final isBusiness = user.isBusiness;
      final isKycVerified = user.isVerified;
      final isAdminApproved = user.isApprovedByAdmin;
      final trackStatus = isBusiness ? user.kybStatus : user.kycStatus;
      final statusLower = trackStatus.isNotEmpty && trackStatus != 'Not Started'
          ? trackStatus.toLowerCase()
          : user.diditStatus.toLowerCase();
      final isDeclined = statusLower == 'declined' ||
          statusLower == 'banned' ||
          statusLower == 'rejected' ||
          user.verificationStatus.toLowerCase() == 'declined';

      Color diditStatusColor;
      IconData diditStatusIcon;

      if (isKycVerified) {
        diditStatusColor = Colors.green;
        diditStatusIcon = Iconsax.verify;
      } else if (isDeclined) {
        diditStatusColor = Colors.red;
        diditStatusIcon = Iconsax.close_circle;
      } else if (statusLower == 'in review' ||
          statusLower == 'pending_review' ||
          user.verificationStatus == 'pending') {
        diditStatusColor = Colors.orange;
        diditStatusIcon = Iconsax.clock;
      } else if (statusLower == 'in progress') {
        diditStatusColor = Colors.blue;
        diditStatusIcon = Iconsax.refresh;
      } else {
        diditStatusColor = Colors.grey;
        diditStatusIcon = Iconsax.info_circle;
      }

      final displayStatus = isKycVerified
          ? 'Approved'
          : isDeclined
              ? 'Declined'
              : (trackStatus.isNotEmpty && trackStatus != 'Not Started'
                  ? trackStatus
                  : (user.diditStatus.isEmpty || user.diditStatus == 'Not Started'
                      ? (user.verificationStatus.isEmpty ? 'Not Started' : user.verificationStatus.capitalizeFirst!)
                      : user.diditStatus));

      final screenTitle = isBusiness ? 'Corporate Shipper Verification (KYB)' : 'Shipper Identity Verification (KYC)';
      final isWide = SiteLayout.isWideScreen(context);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final businessAccent = dark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);

      return AppPageLayout(
        title: screenTitle,
        child: Scaffold(
          appBar: isWide
              ? null
              : AvailAppbar(
                  title: Text(screenTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  showBackArrow: true,
                  showBackgroundColor: true,
                  backArrowColor: Colors.white,
                ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AvailSizes.defaultSpace),
          child: ResponsiveCenter(
            maxWidth: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              /// 1. Account Profile Context Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isBusiness
                      ? businessAccent.withValues(alpha: dark ? 0.12 : 0.05)
                      : AvailColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isBusiness
                        ? businessAccent.withValues(alpha: dark ? 0.35 : 0.2)
                        : AvailColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isBusiness
                            ? (dark ? const Color(0xFF0284C7) : const Color(0xFF0F172A))
                            : AvailColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isBusiness ? Iconsax.buildings : Iconsax.user,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isBusiness ? 'Corporate Shipper Account' : 'Individual Shipper Account',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isBusiness ? businessAccent : AvailColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBusiness ? Colors.purple.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isBusiness ? 'KYB Required' : 'KYC Required',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isBusiness ? Colors.purple.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isBusiness
                                ? 'Company: ${user.companyName.isNotEmpty ? user.companyName : "Corporate Business"}'
                                : 'Shipper: ${user.fullName.isNotEmpty ? user.fullName : "Individual Account"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          if (isBusiness && user.registrationNumber.isNotEmpty)
                            Text(
                              'Tax ID / Reg No: ${user.registrationNumber}',
                              style: TextStyle(fontSize: 11, color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          if (!isBusiness && user.idDocumentNumber.isNotEmpty)
                            Text(
                              '${user.idDocumentType}: ${user.idDocumentNumber}',
                              style: TextStyle(fontSize: 11, color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          const SizedBox(height: 8),
                          // Profile verification badge (Single track for user's account type)
                          _buildTrackMiniBadge(
                            label: isBusiness ? 'Corporate KYB' : 'Individual KYC',
                            isVerified: isKycVerified,
                            isApproved: isAdminApproved,
                            isActive: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              /// 2. Didit Real-Time Automated Verification Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: diditStatusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: diditStatusColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(diditStatusIcon, color: diditStatusColor, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isBusiness
                                ? 'DIDIT Corporate (KYB) Verification'
                                : 'DIDIT Identity (KYC) Verification',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: diditStatusColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: diditStatusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            displayStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => controller.syncDiditVerificationStatus(),
                          icon: const Icon(Iconsax.refresh, size: 20),
                          tooltip: 'Sync / Refresh Verification Status',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isBusiness
                          ? 'Real-time cryptographic corporate entity and tax registration verification via Didit Protocol.'
                          : 'Real-time cryptographic verification of National ID/Passport and live biometric face scan via Didit Protocol.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                    ),
                    if (isBusiness && user.diditBusinessSessionId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Business Session ID: ${user.diditBusinessSessionId}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                    ] else if (!isBusiness && user.diditSessionId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Session ID: ${user.diditSessionId}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                    ],
                    if (isDeclined && user.rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Iconsax.info_circle, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Automated Check Decline Reason:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.rejectionReason,
                                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              /// 2.1 Admin Operations Approval Status Card
              _buildAdminApprovalCard(context, user: user),

              const SizedBox(height: AvailSizes.spacebtwsections),

              /// 3. STEP-BY-STEP WORKFLOW
              if (!isBusiness)
                _buildIndividualShipperKycSection(
                  context,
                  controller: controller,
                  user: user,
                  isKycVerified: isKycVerified,
                  isAdminApproved: isAdminApproved,
                )
              else
                _buildBusinessShipperKybSection(
                  context,
                  controller: controller,
                  user: user,
                  isKycVerified: isKycVerified,
                  isAdminApproved: isAdminApproved,
                ),

              const SizedBox(height: AvailSizes.spacebtwsections),

              /// 4. Cargo & Shipper Security Trust Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Iconsax.shield_tick, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBusiness ? 'Why Corporate KYB & Admin Approval?' : 'Why Shipper KYC & Admin Approval?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isBusiness
                                ? 'Corporate vetting protects carriers against fraudulent cargo consignments, ensures commercial transport tax compliance, and unlocks high-capacity commercial freight dispatch.'
                                : 'Commercial freight transport involves high-value cargo and transit liability. Requiring both cryptographic ID verification (KYC) and Admin review ensures transport insurance coverage, legal compliance, and carrier trust.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  });
}

  /// Admin Operations Approval Card
  Widget _buildAdminApprovalCard(BuildContext context, {required UserAccountModel user}) {
    final isApproved = user.isApprovedByAdmin;
    final isRejected = user.isAdminRejected;
    final reason = user.activeAdminRejectionReason;

    Color cardColor;
    Color borderColor;
    IconData icon;
    String title;
    String message;
    String badgeText;

    if (isApproved) {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade400;
      icon = Iconsax.verify;
      title = 'Admin Operations: Approved & Active';
      badgeText = 'APPROVED';
      message = 'Your shipper credentials and profile have been officially approved by Fleet Operations Admin. You are fully authorized to book trucks and dispatch commercial freight.';
    } else if (isRejected) {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade400;
      icon = Iconsax.close_circle;
      title = 'Admin Operations: Application Declined';
      badgeText = 'DECLINED';
      message = reason.isNotEmpty
          ? 'Declined Reason: $reason\nPlease update your documents or contact operations support.'
          : 'Your shipper account could not be approved by the administrator. Please update your details or contact operations.';
    } else {
      cardColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade400;
      icon = Iconsax.clock;
      title = 'Admin Operations: Pending Review';
      badgeText = 'PENDING APPROVAL';
      message = user.isVerified
          ? 'Didit identity verification passed! Fleet Operations Admin is currently reviewing your declared credentials before unlocking freight booking.'
          : 'Admin review commences automatically once your Didit identity verification (Steps 1 & 2) is completed.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: borderColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: borderColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
          ),
        ],
      ),
    );
  }

  /// Individual Shipper Flow (Step 1 -> Step 2 -> Step 3)
  Widget _buildIndividualShipperKycSection(
    BuildContext context, {
    required VerificationController controller,
    required UserAccountModel user,
    required bool isKycVerified,
    required bool isAdminApproved,
  }) {
    final bool hasDocs = user.hasSubmittedKycDocs;
    final bool showForm = !hasDocs || _isEditingDocs;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shipper KYC Verification Flow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: dark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (hasDocs && !isAdminApproved)
              TextButton.icon(
                onPressed: () => setState(() => _isEditingDocs = !_isEditingDocs),
                icon: Icon(_isEditingDocs ? Icons.close : Iconsax.edit_2, size: 14),
                label: Text(_isEditingDocs ? 'Cancel Edit' : 'Edit Details', style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        /// STEP 1: Shipper Credentials Form or Summary
        if (!showForm)
          _buildDeclaredCredentialsSummary(context, user: user)
        else
          _buildIndividualCredentialsForm(context, controller: controller),

        const SizedBox(height: 18),

        /// STEP 2: Didit Live Biometric & Document Scan
        _buildDiditScanCard(
          context,
          controller: controller,
          hasDocs: hasDocs,
          isKycVerified: isKycVerified,
          isBusiness: false,
        ),

        const SizedBox(height: 18),

        /// STEP 3: Admin Review Status & Activation Card
        _buildStep3AdminReviewCard(context, user: user),
      ],
    );
  }

  /// Business Shipper Flow (Step 1 -> Step 2 -> Step 3)
  Widget _buildBusinessShipperKybSection(
    BuildContext context, {
    required VerificationController controller,
    required UserAccountModel user,
    required bool isKycVerified,
    required bool isAdminApproved,
  }) {
    final bool hasDocs = user.hasSubmittedKycDocs;
    final bool showForm = !hasDocs || _isEditingDocs;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Corporate KYB Verification Flow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: dark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (hasDocs && !isAdminApproved)
              TextButton.icon(
                onPressed: () => setState(() => _isEditingDocs = !_isEditingDocs),
                icon: Icon(_isEditingDocs ? Icons.close : Iconsax.edit_2, size: 14),
                label: Text(_isEditingDocs ? 'Cancel Edit' : 'Edit Details', style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        /// STEP 1: Company Credentials Form or Summary
        if (!showForm)
          _buildDeclaredBusinessSummary(context, user: user)
        else
          _buildBusinessCredentialsForm(context, controller: controller),

        const SizedBox(height: 18),

        /// STEP 2: Didit Live KYB Corporate Scan
        _buildDiditScanCard(
          context,
          controller: controller,
          hasDocs: hasDocs,
          isKycVerified: isKycVerified,
          isBusiness: true,
        ),

        const SizedBox(height: 18),

        /// STEP 3: Admin Review Status & Activation Card
        _buildStep3AdminReviewCard(context, user: user),
      ],
    );
  }

  /// Individual Credentials Input Form
  Widget _buildIndividualCredentialsForm(BuildContext context, {required VerificationController controller}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF1E3A5F) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Form(
        key: _individualFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AvailColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Iconsax.edit, color: AvailColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Step 1: Declare Identity Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your official government ID details exactly as printed on your card/passport.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 14),

            // Document Type Choices
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('National ID', style: TextStyle(fontSize: 12)),
                    selected: _idDocType == 'National ID',
                    selectedColor: AvailColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _idDocType = 'National ID');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Passport', style: TextStyle(fontSize: 12)),
                    selected: _idDocType == 'Passport',
                    selectedColor: AvailColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _idDocType = 'Passport');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Driver's License", style: TextStyle(fontSize: 12)),
                    selected: _idDocType == "Driver's License",
                    selectedColor: AvailColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _idDocType = "Driver's License");
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Voter ID', style: TextStyle(fontSize: 12)),
                    selected: _idDocType == 'Voter ID',
                    selectedColor: AvailColors.primary.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _idDocType = 'Voter ID');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _idDocNameController,
              decoration: InputDecoration(
                labelText: 'Legal Name on $_idDocType',
                prefixIcon: const Icon(Iconsax.user),
                hintText: 'e.g. Kwame Mensah',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Legal name required' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _idDocNumberController,
              decoration: InputDecoration(
                labelText: '$_idDocType Number',
                prefixIcon: const Icon(Iconsax.card),
                hintText: _idDocType == 'National ID' ? 'e.g. GHA-721839201-4' : 'e.g. G1289012',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Document number required' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _idDocExpiryController,
              readOnly: true,
              onTap: () => _selectExpiryDate(context, _idDocExpiryController),
              decoration: InputDecoration(
                labelText: '$_idDocType Expiry Date',
                prefixIcon: const Icon(Iconsax.calendar_1),
                suffixIcon: IconButton(
                  icon: const Icon(Iconsax.calendar_search),
                  onPressed: () => _selectExpiryDate(context, _idDocExpiryController),
                ),
                hintText: 'YYYY-MM-DD',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Expiry date required' : null,
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingDocs ? null : () => _saveIndividualDocs(controller),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AvailColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSavingDocs
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Iconsax.document_upload, color: Colors.white, size: 18),
                label: Text(
                  _isSavingDocs ? 'Saving Credentials...' : 'Save & Register Details',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual Credentials Summary Card
  Widget _buildDeclaredCredentialsSummary(BuildContext context, {required UserAccountModel user}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: const Icon(Iconsax.tick_circle, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Step 1: Declared Shipper Credentials',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Document Type', user.idDocumentType.isNotEmpty ? user.idDocumentType : 'National ID'),
          _buildInfoRow('Legal Name', user.idDocumentName.isNotEmpty ? user.idDocumentName : user.fullName),
          _buildInfoRow('Document Number', user.idDocumentNumber),
          if (user.idDocumentExpiry.isNotEmpty) _buildInfoRow('Expiry Date', user.idDocumentExpiry),
        ],
      ),
    );
  }

  /// Business Credentials Input Form
  Widget _buildBusinessCredentialsForm(BuildContext context, {required VerificationController controller}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final businessIconColor = dark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF1E3A5F) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Form(
        key: _businessFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: businessIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Iconsax.buildings, color: businessIconColor, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Step 1: Declare Corporate Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Input your company registration and tax details for Corporate KYB validation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Registered Company / Business Name',
                prefixIcon: Icon(Iconsax.buildings),
                hintText: 'e.g. Apex Freight Logistics Ltd',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Company name required' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _registrationNumberController,
              decoration: const InputDecoration(
                labelText: 'Business Registration / TIN (Tax ID)',
                prefixIcon: Icon(Iconsax.document_text),
                hintText: 'e.g. C0002910291 or TIN-9821890',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Tax ID / Registration number required' : null,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _businessAddressController,
              decoration: const InputDecoration(
                labelText: 'Physical Business Address',
                prefixIcon: Icon(Iconsax.location),
                hintText: 'e.g. Plot 14, Industrial Area, Tema, Ghana',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Business address required' : null,
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingDocs ? null : () => _saveBusinessDocs(controller),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark ? AvailColors.primary : const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSavingDocs
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Iconsax.document_upload, color: Colors.white, size: 18),
                label: Text(
                  _isSavingDocs ? 'Saving Company Details...' : 'Save & Register Company',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Business Credentials Summary Card
  Widget _buildDeclaredBusinessSummary(BuildContext context, {required UserAccountModel user}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: const Icon(Iconsax.tick_circle, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Step 1: Declared Corporate Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Company Name', user.companyName),
          _buildInfoRow('Tax ID / Reg No', user.registrationNumber),
          if (user.businessAddress.isNotEmpty) _buildInfoRow('Registered Address', user.businessAddress),
        ],
      ),
    );
  }

  /// Step 2: Didit Live Biometric & Document Scan Card
  Widget _buildDiditScanCard(
    BuildContext context, {
    required VerificationController controller,
    required bool hasDocs,
    required bool isKycVerified,
    required bool isBusiness,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isKycVerified
              ? Colors.green.shade300
              : (hasDocs
                  ? AvailColors.primary.withValues(alpha: 0.4)
                  : (dark ? const Color(0xFF1E3A5F) : Colors.grey.shade300)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isKycVerified ? Colors.green.shade50 : AvailColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isKycVerified ? Iconsax.verify : Iconsax.camera,
                  color: isKycVerified ? Colors.green : AvailColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBusiness ? 'Step 2: Live Corporate KYB Scan' : 'Step 2: Live ID & Biometric Liveness Scan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      isKycVerified ? 'Cryptographically verified via Didit' : 'Powered by Didit Identity Network',
                      style: TextStyle(fontSize: 11, color: isKycVerified ? Colors.green : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isBusiness
                ? 'Launch the Didit portal to perform automated registry cross-checking for commercial business validation.'
                : 'Take a clear photo of your physical ID card / passport and complete a quick facial liveness selfie.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),

          if (isKycVerified) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.tick_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBusiness
                          ? 'Step 2 Completed: Corporate KYB verification passed!'
                          : 'Step 2 Completed: Cryptographic ID verification passed!',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.startDiditVerification(isKyb: isBusiness),
                    icon: const Icon(Iconsax.refresh, size: 15),
                    label: const Text('Re-verify with Didit', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.resetVerificationForActiveTrack(),
                    icon: const Icon(Iconsax.trash, size: 15, color: Colors.red),
                    label: const Text('Reset Status', style: TextStyle(fontSize: 11.5, color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Obx(() {
              final isStarting = controller.isStartingVerification.value || controller.isLoading.value;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (hasDocs && !isStarting)
                      ? () => controller.startDiditVerification(isKyb: isBusiness)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Iconsax.scan, color: Colors.white, size: 18),
                  label: Text(
                    isStarting
                        ? 'Initiating Didit Portal...'
                        : (hasDocs
                            ? (isBusiness ? 'Start Corporate KYB Live Scan' : 'Start Live ID & Selfie Scan')
                            : 'Complete Step 1 Above First'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Step 3: Admin Review Status & Final Activation Card
  Widget _buildStep3AdminReviewCard(BuildContext context, {required UserAccountModel user}) {
    final bool isKycDone = user.isVerified;
    final bool isAdminApproved = user.isApprovedByAdmin;
    final bool isRejected = user.isAdminRejected;
    final String rejectionReason = user.activeAdminRejectionReason;

    Color badgeColor;
    String badgeText;
    IconData icon;
    String title;
    String description;

    if (isAdminApproved) {
      badgeColor = Colors.green;
      badgeText = 'FINALIZED & ACTIVE';
      icon = Iconsax.verify;
      title = 'Step 3: Admin Review Finalized';
      description = 'Congratulations! Your shipper account has been approved by Fleet Operations Admin. You are fully authorized to book freight shipments.';
    } else if (isRejected) {
      badgeColor = Colors.red;
      badgeText = 'ACTION REQUIRED';
      icon = Iconsax.close_circle;
      title = 'Step 3: Admin Review Declined';
      description = rejectionReason.isNotEmpty
          ? 'Declined reason: $rejectionReason. Please update your details or contact operations.'
          : 'Your account was declined by the administrator. Please update your documents or contact support.';
    } else if (isKycDone) {
      badgeColor = Colors.orange;
      badgeText = 'UNDER ADMIN REVIEW';
      icon = Iconsax.clock;
      title = 'Step 3: Fleet Operations Review';
      description = 'Your identity verification is successful! Our operations administrator is currently verifying your profile details before unlocking freight bookings.';
    } else {
      badgeColor = Colors.grey;
      badgeText = 'STEP 3 PENDING';
      icon = Iconsax.info_circle;
      title = 'Step 3: Admin Authorization';
      description = 'Admin review will begin automatically once Steps 1 and 2 are completed.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: badgeColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: badgeColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  badgeText,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackMiniBadge({
    required String label,
    required bool isVerified,
    required bool isApproved,
    required bool isActive,
  }) {
    Color bg;
    Color text;
    String statusStr;

    if (isApproved && isVerified) {
      bg = Colors.green.shade50;
      text = Colors.green.shade800;
      statusStr = 'Approved & Active';
    } else if (isApproved) {
      bg = Colors.green.shade50;
      text = Colors.green.shade800;
      statusStr = 'Admin Approved';
    } else if (isVerified) {
      bg = Colors.orange.shade50;
      text = Colors.orange.shade800;
      statusStr = 'Admin Pending';
    } else {
      bg = Colors.grey.shade100;
      text = Colors.grey.shade700;
      statusStr = 'Unverified';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? text.withValues(alpha: 0.6) : text.withValues(alpha: 0.2),
          width: isActive ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.circle, size: 6, color: text),
            ),
          Text(
            '$label: $statusStr',
            style: TextStyle(fontSize: 9.5, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: text),
          ),
        ],
      ),
    );
  }
}
