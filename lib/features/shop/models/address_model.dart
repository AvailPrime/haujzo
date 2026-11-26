import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/formatters/formatter.dart';

class AddressModel {
  String id;
  final String name;
  final String phoneNumber;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final DateTime? dateTime;

  AddressModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.dateTime,
  });

  /// Formatted phone number
  String get formattedPhoneNo => AvailFormatter.formatPhoneNumber(phoneNumber);

  /// Empty address (for initialization)
  static AddressModel empty() => AddressModel(
    id: '',
    name: '',
    phoneNumber: '',
    street: '',
    city: '',
    state: '',
    postalCode: '',
    country: '',
  );

  /// Convert address to Firestore-compatible map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'street': street,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'dateTime': dateTime ?? DateTime.now(),
    };
  }

  /// Create an AddressModel from a Map
  factory AddressModel.fromMap(Map<String, dynamic> data) {
    return AddressModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      street: data['street'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? '',
      dateTime: data['dateTime'] != null
          ? (data['dateTime'] as Timestamp).toDate()
          : null,
    );
  }

  factory AddressModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    // Get the raw data from Firestore document
    final data = snapshot.data() as Map<String, dynamic>?;

    // Safety check in case document is empty
    if (data == null) {
      return AddressModel.empty();
    }

    // Build the AddressModel using fromMap
    final address = AddressModel.fromMap(data);

    // Assign the Firestore document ID as the id
    address.id = snapshot.id;

    return address;
  }

  /// Formatted address string for UI
  @override
  String toString() {
    return '$street, $city, $state $postalCode, $country';
  }
}
