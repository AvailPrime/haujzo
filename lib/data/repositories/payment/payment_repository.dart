import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/shop/models/payment_details_model.dart';
import '../authentication/authentication_repository.dart';

class PaymentRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// ================= STORE FULL DETAILS =================
  Future<String> storePaymentDetails(
      PaymentDetailsModel paymentDetails) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;

      final paymentRef = await _firestore
          .collection('Users')
          .doc(userId)
          .collection('PaymentDetails')
          .add(paymentDetails.toJson());

      return paymentRef.id;
    } catch (e) {
      throw 'Error saving payment details';
    }
  }

  /// ================= UPDATE ACCOUNT NAME =================
  Future<void> updatePaymentAccountName(String paymentId, String accountName) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      await _firestore
          .collection('Users')
          .doc(authUser.uid)
          .collection('PaymentDetails')
          .doc(paymentId)
          .set({'accountName': accountName.trim()}, SetOptions(merge: true));
    } catch (e) {
      throw 'Error updating account name: $e';
    }
  }

  /// ================= FETCH SAVED =================
  Future<List<PaymentDetailsModel>> fetchSavedPayments() async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;

      final snapshot = await _firestore
          .collection('Users')
          .doc(userId)
          .collection('PaymentDetails')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
          PaymentDetailsModel.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      print("❌ Error fetching payment details: $e");
      throw 'Error fetching payment details: $e';
    }
  }

  /// ================= DELETE PAYMENT METHOD =================
  Future<void> deletePaymentMethod(String paymentId) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;
      await _firestore
          .collection('Users')
          .doc(userId)
          .collection('PaymentDetails')
          .doc(paymentId)
          .delete();
    } catch (e) {
      throw 'Error deleting payment method: $e';
    }
  }

  /// ================= SAVE AUTHORIZATION AFTER PAYMENT =================
  Future<void> saveAuthorization({
    required String userId,
    required String authorizationCode,
    required String last4,
    required String brand,
    required int expMonth,
    required int expYear,
  }) async {
    try {
      await _firestore
          .collection('Users')
          .doc(userId)
          .collection('PaymentDetails')
          .doc(authorizationCode) // 🔥 use auth_code as ID
          .set({
        'method': {
          'type': 'card',
          'name': 'Card Payment',
          'code': 'card',
        },
        'authorizationCode': authorizationCode,
        'last4': last4,
        'brand': brand,
        'expMonth': expMonth,
        'expYear': expYear,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("❌ Error saving authorization: $e");
    }
  }

  /// ================= HELPERS =================
  int? _getExpMonth(String input) {
    if (!input.contains('/')) return null;
    return int.tryParse(input.split('/')[0]);
  }

  int? _getExpYear(String input) {
    if (!input.contains('/')) return null;
    return int.tryParse('20${input.split('/')[1]}');
  }
}
