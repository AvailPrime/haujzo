import 'package:cloud_firestore/cloud_firestore.dart';

class IdGenerator {
  static Future<String> generate({
    required String prefix,
    required bool includeYear,
    required bool includeMonth,
    required bool includeDay,
  }) async {
    final firestore = FirebaseFirestore.instance;

    /// Each prefix has its own counter
    final counterRef = firestore.collection('counters').doc(prefix);

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int newNumber = 1;

      if (snapshot.exists) {
        final lastNumber = snapshot.data()?['lastNumber'] ?? 0;
        newNumber = lastNumber + 1;
      }

      transaction.set(counterRef, {
        'lastNumber': newNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final now = DateTime.now();

      final yy = now.year.toString().substring(2);
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');

      String datePart = '';

      if (includeYear) datePart += yy;
      if (includeMonth) datePart += mm;
      if (includeDay) datePart += dd;

      final series = newNumber.toString().padLeft(6, '0');

      return '$prefix$datePart$series';
    });
  }
}
