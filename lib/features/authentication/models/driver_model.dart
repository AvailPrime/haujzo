import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String id;
  String firstName;
  String lastName;
  String email;
  String phoneNumber;
  String profilePicture;
  String vehicleType; // motor, car, van, truck, container, flatbed, tipper
  String vehicleModel;
  String licensePlate;
  String status; // online, offline, busy
  GeoPoint? currentLocation;
  double rating;
  int completedTrips;

  DriverModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.profilePicture = '',
    this.vehicleType = 'truck',
    this.vehicleModel = '',
    this.licensePlate = '',
    this.status = 'offline',
    this.currentLocation,
    this.rating = 5.0,
    this.completedTrips = 0,
  });

  String get fullName => '$firstName $lastName';

  static DriverModel empty() => DriverModel(
    id: '',
    firstName: '',
    lastName: '',
    email: '',
    phoneNumber: '',
  );

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'licensePlate': licensePlate,
      'status': status,
      'currentLocation': currentLocation,
      'rating': rating,
      'completedTrips': completedTrips,
      'role': 'driver',
    };
  }

  factory DriverModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> document) {
    if (document.data() != null) {
      final data = document.data()!;
      return DriverModel(
        id: document.id,
        firstName: data['firstName'] ?? '',
        lastName: data['lastName'] ?? '',
        email: data['email'] ?? '',
        phoneNumber: data['phoneNumber'] ?? '',
        profilePicture: data['profilePicture'] ?? '',
        vehicleType: data['vehicleType'] ?? 'truck',
        vehicleModel: data['vehicleModel'] ?? '',
        licensePlate: data['licensePlate'] ?? '',
        status: data['status'] ?? 'offline',
        currentLocation: data['currentLocation'] as GeoPoint?,
        rating: (data['rating'] ?? 5.0).toDouble(),
        completedTrips: (data['completedTrips'] ?? 0).toInt(),
      );
    } else {
      return DriverModel.empty();
    }
  }
}
