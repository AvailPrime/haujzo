import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SidebarController extends GetxController {
  static SidebarController get instance {
    if (!Get.isRegistered<SidebarController>()) {
      return Get.put(SidebarController(), permanent: true);
    }
    return Get.find<SidebarController>();
  }

  final isCollapsed = false.obs;
  GetStorage? _storage;

  @override
  void onInit() {
    super.onInit();
    try {
      _storage = GetStorage();
      isCollapsed.value = _storage?.read<bool>('shipper_sidebar_collapsed') ?? false;
    } catch (_) {}
  }

  void toggleSidebar() {
    isCollapsed.toggle();
    try {
      _storage?.write('shipper_sidebar_collapsed', isCollapsed.value);
    } catch (_) {}
  }

  void collapse() {
    isCollapsed.value = true;
    try {
      _storage?.write('shipper_sidebar_collapsed', true);
    } catch (_) {}
  }

  void expand() {
    isCollapsed.value = false;
    try {
      _storage?.write('shipper_sidebar_collapsed', false);
    } catch (_) {}
  }
}
