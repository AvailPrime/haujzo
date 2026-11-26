import '../authentication/authentication_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../../features/shop/models/address_model.dart';

class AddressRepository extends GetxController {
  static AddressRepository get instance => Get.find();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Fetch all addresses for the current user
  Future<List<AddressModel>> fetchUserAddresses() async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;
      if (userId.isEmpty) throw 'Unable to find user information. Please try again later';

      final result = await _db.collection('Users').doc(userId).collection('Addresses').get();
      return result.docs
          .map((doc) => AddressModel.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      throw 'Something went wrong while fetching addresses. Please try again later';
    }
  }

  /// Add a new address
  Future<String> addAddress(AddressModel address) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;
      final docRef = await _db.collection('Users').doc(userId).collection('Addresses').add(address.toJson());
      return docRef.id;
    } catch (e) {
      throw 'Something went wrong while saving address. Try again later';
    }
  }

  /// Get a specific address by its Firestore ID
  Future<AddressModel> getAddressById(String addressId) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;
      final doc = await _db.collection('Users').doc(userId).collection('Addresses').doc(addressId).get();
      if (!doc.exists) throw 'Address not found';
      return AddressModel.fromDocumentSnapshot(doc);
    } catch (e) {
      throw 'Unable to fetch address: $e';
    }
  }

  /// Set the default address for the user
  Future<void> setDefaultAddress(String addressId) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;
      await _db.collection('Users').doc(userId).update({
        'defaultAddressId': addressId,
      });
    } catch (e) {
      throw 'Unable to set default address: $e';
    }
  }

  /// Get the user's default address ID
  Future<String?> getDefaultAddressId() async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) return null;
      final userId = authUser.uid;
      final doc = await _db.collection('Users').doc(userId).get();
      return doc.data()?['defaultAddressId'] as String?;
    } catch (e) {
      throw 'Unable to fetch default address ID: $e';
    }
  }

  /// Delete an address
  Future<void> deleteAddress(String addressId) async {
    try {
      final authUser = AuthenticationRepository.instance.authUser;
      if (authUser == null) throw 'User not authenticated. Please log in again.';
      final userId = authUser.uid;
      await _db.collection('Users').doc(userId).collection('Addresses').doc(addressId).delete();
    } catch (e) {
      throw 'Something went wrong while deleting address. Try again later';
    }
  }
}
