import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../features/shop/models/banner_model.dart';
import '../../../utils/exceptions/firebase_exception.dart';
import '../../../utils/exceptions/format_exception.dart';
import '../../../utils/exceptions/platform_exception.dart';

class BannerRepository extends GetxController{
  static BannerRepository get instance => Get.find();

  /// Variable
  final _db = FirebaseFirestore.instance;

  /// Get all order Related to current User
  Future<List<BannerModel>> fetchBanners() async {
    try {
      final results = await _db.collection('Banners').where('active', isEqualTo: true).get();
      return results.docs.map((documentSnapshot) => BannerModel.fromSnapshot(documentSnapshot)).toList();
    }on FirebaseException catch(e){
      throw AvailFirebaseException(e.code).message;
    }on FormatException catch(_){
      throw AvailFormatException('invalid-json').message;
    }on PlatformException catch(e){
      throw AvailPlatformException(e.code).message;
    } catch (e) {
      throw 'Something went wrong while fetching Banners';
    }
  }

  /// Upload Banners to the cloud Firebase
}
