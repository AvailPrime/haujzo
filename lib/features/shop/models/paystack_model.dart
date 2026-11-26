class PaystackModel {
  final String testPublicKey;
  final String livePublicKey;
  final bool isLive;

  PaystackModel({
    required this.testPublicKey,
    required this.livePublicKey,
    required this.isLive,
  });

  /// Empty fallback
  static PaystackModel empty() => PaystackModel(
        testPublicKey: '',
        livePublicKey: '',
        isLive: true,
      );

  /// Active public key based on environment (defaults to livePublicKey when available)
  String get activeKey {
    if (isLive && livePublicKey.isNotEmpty) return livePublicKey;
    if (testPublicKey.isNotEmpty) return testPublicKey;
    return livePublicKey;
  }

  factory PaystackModel.fromMap(Map<String, dynamic> data) {
    final livePub = (data['livePublicKey'] ??
            data['paystackLivePublicKey'] ??
            data['publicKey'] ??
            data['public_key'] ??
            '')
        .toString()
        .trim();
    final testPub = (data['testPublicKey'] ?? data['paystackTestPublicKey'] ?? '').toString().trim();
    final bool isSandbox =
        data['isPaystackSandboxMode'] == true || data['isSandbox'] == true || data['isLive'] == false;

    return PaystackModel(
      testPublicKey: testPub,
      livePublicKey: livePub,
      isLive: !isSandbox,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'testPublicKey': testPublicKey,
      'livePublicKey': livePublicKey,
      'isLive': isLive,
    };
  }
}
