class SupportConfigModel {
  final String supportEmail;
  final String supportPhone;
  final String emergencyNumber;
  final String supportHours;
  final String disputeNotice;

  const SupportConfigModel({
    required this.supportEmail,
    required this.supportPhone,
    required this.emergencyNumber,
    required this.supportHours,
    required this.disputeNotice,
  });

  factory SupportConfigModel.defaults() {
    return const SupportConfigModel(
      supportEmail: 'support@haujzo.com',
      supportPhone: '+233 55 123 4567',
      emergencyNumber: '112',
      supportHours: '24/7 Dispatch & Customer Care',
      disputeNotice:
          'For fare, demurrage, or cargo disputes, contact Dispatch Support with your Booking ID for fast resolution.',
    );
  }

  factory SupportConfigModel.fromJson(Map<String, dynamic> json) {
    final defaults = SupportConfigModel.defaults();

    String pick(List<String> keys, String fallback) {
      for (final key in keys) {
        final val = json[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString().trim();
        }
      }
      return fallback;
    }

    return SupportConfigModel(
      supportEmail: pick(const ['supportEmail', 'email', 'contactEmail'], defaults.supportEmail),
      supportPhone: pick(const ['supportPhone', 'phoneNumber', 'supportPhoneNumber', 'hotline'], defaults.supportPhone),
      emergencyNumber: pick(const ['emergencyNumber', 'emergencyPhone', 'sosNumber'], defaults.emergencyNumber),
      supportHours: pick(const ['supportHours', 'operatingHours'], defaults.supportHours),
      disputeNotice: pick(const ['disputeNotice', 'supportNotice', 'guidance'], defaults.disputeNotice),
    );
  }
}
