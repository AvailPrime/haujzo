import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../../../utils/constants/api_constants.dart';
import '../../../../commons/widgets/loader/loaders.dart';
import '../../../../data/repositories/address/address_repository.dart';
import '../../../shop/models/address_model.dart';
import '../../../../features/personalization/controllers/user_controller.dart';

class PlaceSearchController extends GetxController {
  static PlaceSearchController get instance => Get.find();

  final RxList<dynamic> placePredictions = <dynamic>[].obs;
  final RxList<Map<String, dynamic>> recentSearches = <Map<String, dynamic>>[].obs;
  final RxList<AddressModel> userSavedAddresses = <AddressModel>[].obs;
  final RxString userBusinessAddress = ''.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadFirebaseUserAddresses();
  }

  Future<void> loadFirebaseUserAddresses() async {
    try {
      final addressRepo = Get.isRegistered<AddressRepository>() ? AddressRepository.instance : Get.put(AddressRepository());
      final list = await addressRepo.fetchUserAddresses();
      userSavedAddresses.assignAll(list);
    } catch (_) {}

    try {
      if (Get.isRegistered<UserController>()) {
        userBusinessAddress.value = UserController.instance.user.value.businessAddress;
      }
    } catch (_) {}
  }

  void addToRecent(Map<String, dynamic> place) {
    // Avoid duplicates
    recentSearches.removeWhere((element) => element['description'] == place['description']);
    recentSearches.insert(0, place);
    
    // Keep only last 5
    if (recentSearches.length > 5) {
      recentSearches.removeLast();
    }
  }

  Future<void> findPlaceAutocomplete(String input) async {
    if (input.isEmpty) {
      placePredictions.clear();
      return;
    }

    final encodedInput = Uri.encodeComponent(input);
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedInput&key=${APIConstants.googleMapsAPIKey}');

    try {
      isLoading.value = true;
      print('Fetching places for: $input');
      print('URL: $url');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Places API Response: $data');
        
        if (data['status'] == 'OK') {
          placePredictions.assignAll(data['predictions']);
        } else {
          final status = data['status'];
          final errorMsg = data['error_message'] ?? 'Unknown error';
          print('Places API Status Error: $status - $errorMsg');
          
          if (status == 'REQUEST_DENIED') {
            AvailLoaders.errorSnackBar(
              title: 'API Error',
              message: 'Places API request denied. Please check your API key restrictions and ensure Places API is enabled.',
            );
          } else if (status == 'OVER_QUERY_LIMIT') {
            AvailLoaders.errorSnackBar(title: 'API Error', message: 'Quota exceeded.');
          }

          placePredictions.clear();
        }
      } else {
        print('Places API HTTP Error: ${response.statusCode}');
        placePredictions.clear();
      }
    } catch (e) {
      print('Places API Exception: $e');
      placePredictions.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, double>?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${APIConstants.googleMapsAPIKey}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result']?['geometry']?['location'] != null) {
          final location = data['result']['geometry']['location'];
          return {
            'lat': (location['lat'] as num).toDouble(),
            'lng': (location['lng'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      debugPrint('getPlaceDetails error: $e');
      return null;
    }
    return null;
  }

  /// Geocodes a free-form address string to LatLng when user types custom text & presses Enter
  Future<Map<String, dynamic>?> geocodeAddress(String query) async {
    if (query.trim().isEmpty) return null;
    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=${APIConstants.googleMapsAPIKey}');

    try {
      isLoading.value = true;
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final first = data['results'][0];
          final loc = first['geometry']['location'];
          final formatted = first['formatted_address'] ?? query;
          return {
            'description': formatted,
            'lat': (loc['lat'] as num).toDouble(),
            'lng': (loc['lng'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    } finally {
      isLoading.value = false;
    }
    return null;
  }
}

