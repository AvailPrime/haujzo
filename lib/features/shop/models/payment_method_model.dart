import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentMethodModel {
  String id;
  final String name;
  final String image;
  final String code;
  final String type;

  PaymentMethodModel({
    required this.id,
    required this.name,
    required this.image,
    required this.code,
    required this.type,
  });

  // Factory constructor for an empty payment method
  static PaymentMethodModel empty() => PaymentMethodModel(
    id: '',
    name: '',
    image: '',
    code: '',
    type: '',
  );

  // Convert the object to JSON (for Firestore or API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'code': code,
      'type': type,
    };
  }

  // Create a PaymentMethodModel from a Map (Firestore or API)
  factory PaymentMethodModel.fromMap(Map<String, dynamic> data) {
    return PaymentMethodModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      image: data['image'] ?? '',
      code: data['code'] ?? '',
      type: data['type'] ?? '',
    );
  }

  // Create a PaymentMethodModel from a Firestore DocumentSnapshot
  factory PaymentMethodModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return PaymentMethodModel(
      id: data['id'] ?? snapshot.id,
      name: data['name'] ?? '',
      image: data['image'] ?? '',
      code: data['code'] ?? '',
      type: data['type'] ?? '',
    );
  }

  @override
  String toString() {
    return '$name ($type)';
  }
}
