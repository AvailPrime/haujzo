import 'dart:io';

import '../../../features/shop/models/user_account_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../utils/exceptions/firebase_exception.dart';
import '../../../utils/exceptions/format_exception.dart';
import '../../../utils/exceptions/platform_exception.dart';
import '../authentication/authentication_repository.dart';

class AppUserRepository extends GetxController{
  static AppUserRepository get instance => Get.find();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Function to save user data in Firestore
  Future<void> saveUserRecord(UserAccountModel user)async{
    try{
      await _db.collection('Users').doc(user.id).set(user.toJson());
    }on FirebaseException catch(e){
      throw AvailFirebaseException(e.code).message;
    }on FormatException catch(_){
      throw AvailFormatException('invalid-json').message;
    }on PlatformException catch(e){
      throw AvailPlatformException(e.code).message;
    }catch(e){
      throw 'Something Went Wrong. Please Try again';
    }
  }

  /// Function to fetch user details based on user id
  Future<UserAccountModel> fetchUserRecord(String userId)async{
    try{
      final documentSnapshot = await _db.collection('Users').doc(userId).get();
      if(documentSnapshot.exists){
        return UserAccountModel.fromSnapshot(documentSnapshot);
      }else{
        return UserAccountModel.empty();
      }
    }on FirebaseException catch(e){
      throw AvailFirebaseException(e.code).message;
    }on FormatException catch(_){
      throw AvailFormatException('invalid-json').message;
    }on PlatformException catch(e){
      throw AvailPlatformException(e.code).message;
    }catch(e){
      throw 'Something Went Wrong. Please Try again';
    }
  }

  /// Function to fetch current user details
  Future<UserAccountModel> fetchUserDetails()async{
    return await fetchUserRecord(AuthenticationRepository.instance.authUser?.uid ?? '');
  }

  /// Real-time stream of user details from Firestore
  Stream<UserAccountModel> getUserDetailsStream() {
    final uid = AuthenticationRepository.instance.authUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.value(UserAccountModel.empty());
    }
    return _db.collection('Users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserAccountModel.fromSnapshot(snapshot);
      }
      return UserAccountModel.empty();
    });
  }

  /// Function to update user data in Firestore
  Future<void> updateUserRecord(UserAccountModel updatedUser)async{
    try{
      await _db.collection('Users').doc(updatedUser.id).set(updatedUser.toJson(), SetOptions(merge: true));
    }on FirebaseException catch(e){
      throw AvailFirebaseException(e.code).message;
    }on FormatException catch(_){
      throw AvailFormatException('invalid-json').message;
    }on PlatformException catch(e){
      throw AvailPlatformException(e.code).message;
    }catch(e){
      throw 'Something Went Wrong. Please Try again';
    }
  }

  /// update any field in the user collection
  Future<void> updateSingleField(Map<String, dynamic> json)async{
    try{
      final uid = AuthenticationRepository.instance.authUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await _db.collection('Users').doc(uid).set(json, SetOptions(merge: true));
      }
    }on FirebaseException catch(e){
      throw AvailFirebaseException(e.code).message;
    }on FormatException catch(_){
      throw AvailFormatException('invalid-json').message;
    }on PlatformException catch(e){
      throw AvailPlatformException(e.code).message;
    }catch(e){
      throw 'Something Went Wrong. Please Try again';
    }
  }

  /// Function to remove user data from FireStore
  Future<void> removeUserRecord(String userId)async{
    try{
      await _db.collection('Users').doc(userId).delete();
    }on FirebaseException catch(e){
      throw AvailFirebaseException(e.code).message;
    }on FormatException catch(_){
      throw AvailFormatException('invalid-json').message;
    }on PlatformException catch(e){
      throw AvailPlatformException(e.code).message;
    }catch(e){
      throw 'Something Went Wrong. Please Try again';
    }
  }

  /// upload any image
  Future<String> uploadImage(String path, XFile image) async {
    try {
      // Give every upload a unique filename using timestamp + original name
      final uniqueFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      final ref = FirebaseStorage.instance.ref(path).child(uniqueFileName);

      await ref.putFile(File(image.path));

      // Always return the download URL of the uploaded file
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      throw AvailFirebaseException(e.code).message;
    } on FormatException catch (_) {
      throw AvailFormatException('invalid-json').message;
    } on PlatformException catch (e) {
      throw AvailPlatformException(e.code).message;
    } catch (e) {
      throw 'Something Went Wrong. Please Try again';
    }
  }
}
