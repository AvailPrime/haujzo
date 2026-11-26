import 'package:get/get.dart';

import '../../../commons/widgets/loader/loaders.dart';
import '../../../data/repositories/banners/banner_repository.dart';
import '../models/banner_model.dart';

class BannerController extends GetxController{

  /// Variable
  final isLoading = false.obs;
  final carousalCurrentIndex = 0.obs;
  final RxList<BannerModel> banners = <BannerModel>[].obs;


  @override
  void onInit() {
    super.onInit();
    // Don't fetch banners here - let it be called explicitly to avoid blocking controller init
  }

  void updatePageIndicator(index){
    carousalCurrentIndex.value = index;
  }

  /// Fetch Banner
  Future<void> fetchBanners() async{
    try{
      // Show loader while loading categories
      isLoading.value = true;

      // Fetch Banners
      final bannerRepo = Get.put(BannerRepository());
      final banners = await bannerRepo.fetchBanners();

      // Assign Banners
      this.banners.assignAll(banners);


    }catch(e){
      print('Error ${e.toString()}');
    }finally{
      // Remove Loader
      isLoading.value = false;
    }
  }
}
