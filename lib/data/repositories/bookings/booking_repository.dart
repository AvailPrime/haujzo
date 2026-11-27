import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../features/shop/models/booking_model.dart';
import '../../../utils/exceptions/firebase_exception.dart';
import '../../../utils/exceptions/format_exception.dart';
import '../../../utils/exceptions/platform_exception.dart';
import '../authentication/authentication_repository.dart';

class BookingRepository extends GetxController {
  static BookingRepository get instance => Get.find();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Get all bookings for the current user
  Future<List<BookingModel>> getAllUserBookings() async {
    try {
      final userId = AuthenticationRepository.instance.authUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final snapshot = await _db
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) => BookingModel.fromSnapshot(doc)).toList();
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } on AvailFormatException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  /// Fetch booking by ID
  Future<BookingModel?> fetchBookingById(String bookingId) async {
    try {
      final doc = await _db.collection('bookings').doc(bookingId).get();
      if (doc.exists) {
        return BookingModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save new booking
  Future<String> saveBooking(BookingModel booking) async {
    final payload = booking.toJson();
    try {
      debugPrint('[BOOKING REPO] Attempting Firestore bookings.add(...) for bookingId=${booking.bookingId}, userId=${booking.userId}');
      final docRef = await _db.collection('bookings').add(payload);
      debugPrint('[BOOKING REPO] ✅ Successfully created booking document: bookings/${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e, stack) {
      debugPrint('============================================================');
      debugPrint('[BOOKING REPO ERROR] ❌ Firestore saveBooking FirebaseException!');
      debugPrint('  plugin : ${e.plugin}');
      debugPrint('  code   : ${e.code}');
      debugPrint('  message: ${e.message}');
      debugPrint('  uid    : ${AuthenticationRepository.instance.authUser?.uid}');
      debugPrint('  payload keys (${payload.keys.length}): ${payload.keys.toList()}');
      debugPrint('  stack  : $stack');
      debugPrint('============================================================');
      throw AvailFirebaseException(e.code).message;
    } on PlatformException catch (e, stack) {
      debugPrint('[BOOKING REPO ERROR] ❌ saveBooking PlatformException: code=${e.code}, message=${e.message}\n$stack');
      throw AvailPlatformException(e.code).message;
    } on AvailFormatException catch (e) {
      debugPrint('[BOOKING REPO ERROR] ❌ saveBooking AvailFormatException: ${e.message}');
      throw e.message;
    } catch (e, stack) {
      debugPrint('[BOOKING REPO ERROR] ❌ saveBooking Unexpected error: $e\n$stack');
      throw 'Something went wrong. Please try again';
    }
  }

  /// Update existing booking
  Future<void> updateBooking(BookingModel booking) async {
    final payload = booking.toJson();
    try {
      debugPrint('[BOOKING REPO] Attempting Firestore bookings.doc(${booking.id}).update(...)');
      await _db.collection('bookings').doc(booking.id).update(payload);
      debugPrint('[BOOKING REPO] ✅ Successfully updated booking document: bookings/${booking.id}');
    } on FirebaseException catch (e, stack) {
      debugPrint('============================================================');
      debugPrint('[BOOKING REPO ERROR] ❌ Firestore updateBooking FirebaseException!');
      debugPrint('  docId  : ${booking.id}');
      debugPrint('  plugin : ${e.plugin}');
      debugPrint('  code   : ${e.code}');
      debugPrint('  message: ${e.message}');
      debugPrint('  uid    : ${AuthenticationRepository.instance.authUser?.uid}');
      debugPrint('  stack  : $stack');
      debugPrint('============================================================');
      throw AvailFirebaseException(e.code).message;
    } on PlatformException catch (e, stack) {
      debugPrint('[BOOKING REPO ERROR] ❌ updateBooking PlatformException: code=${e.code}, message=${e.message}\n$stack');
      throw AvailPlatformException(e.code).message;
    } on AvailFormatException catch (e) {
      debugPrint('[BOOKING REPO ERROR] ❌ updateBooking AvailFormatException: ${e.message}');
      throw e.message;
    } catch (e, stack) {
      debugPrint('[BOOKING REPO ERROR] ❌ updateBooking Unexpected error: $e\n$stack');
      throw 'Something went wrong. Please try again';
    }
  }

  /// Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _db.collection('bookings').doc(bookingId).update({'status': status});
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } on AvailFormatException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  /// Cancel booking & request refund (via Cloud Function so paid-online bookings are safely flagged for Admin)
  Future<Map<String, dynamic>> cancelBookingAndRequestRefund({
    required String bookingId,
    String reason = '',
    String refundMethodId = '',
    String refundMethodType = '',
    String refundNetworkOrBankCode = '',
    String refundAccountNumber = '',
    String refundAccountName = '',
    String refundMethodLabel = '',
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestShipperBookingRefund');
      final res = await callable.call({
        'bookingId': bookingId,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (refundMethodId.trim().isNotEmpty) 'refundMethodId': refundMethodId.trim(),
        if (refundMethodType.trim().isNotEmpty) 'refundMethodType': refundMethodType.trim(),
        if (refundNetworkOrBankCode.trim().isNotEmpty) 'refundNetworkOrBankCode': refundNetworkOrBankCode.trim(),
        if (refundAccountNumber.trim().isNotEmpty) 'refundAccountNumber': refundAccountNumber.trim(),
        if (refundAccountName.trim().isNotEmpty) 'refundAccountName': refundAccountName.trim(),
        if (refundMethodLabel.trim().isNotEmpty) 'refundMethodLabel': refundMethodLabel.trim(),
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Could not cancel booking and request refund.';
    } catch (e) {
      throw 'Cancellation error: $e';
    }
  }

  /// Update booking documents
  Future<void> updateBookingDocuments(String bookingId, List<Map<String, String>> documents) async {
    try {
      await _db.collection('bookings').doc(bookingId).update({'documents': documents});
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } catch (e) {
      throw 'Something went wrong. Please try again';
    }
  }

  /// Stream of user bookings
  Stream<List<BookingModel>> getUserBookingsStream() {
    final userId = AuthenticationRepository.instance.authUser?.uid;
    if (userId == null) return const Stream.empty();

    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BookingModel.fromSnapshot(doc)).toList());
  }

  /// Stream of a specific booking
  Stream<BookingModel> getBookingStream(String bookingId) {
    if (bookingId.trim().isEmpty) return const Stream.empty();
    return _db
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .where((snapshot) => snapshot.exists)
        .map((snapshot) => BookingModel.fromSnapshot(snapshot));
  }
}
