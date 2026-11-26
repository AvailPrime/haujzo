import 'package:get_storage/get_storage.dart';

class AvailLocalStorage {
  GetStorage? storage;

  static AvailLocalStorage? _instance;

  AvailLocalStorage._internal();

  factory AvailLocalStorage.instance() {
    _instance ??= AvailLocalStorage._internal();
    return _instance!;
  }

  static Future<void> init(String bucketName) async {
    await GetStorage.init(bucketName);
    _instance = AvailLocalStorage._internal();
    _instance!.storage = GetStorage(bucketName);
  }

  /// NEW: Method to switch buckets without re-initializing the factory
  static Future<void> switchBucket(String bucketName) async {
    await GetStorage.init(bucketName);
    AvailLocalStorage.instance().storage = GetStorage(bucketName);
  }

  T? readData<T>(String key) {
    if (storage == null) return null; // ✅ prevent crash
    return storage!.read<T>(key);
  }

  Future<void> writeData<T>(String key, T value) async {
    if (storage == null) return;
    await storage!.write(key, value);
  }

  Future<void> removeData(String key) async {
    await storage?.remove(key);
  }

  /// Clear all
  Future<void> clearAll() async {
    await storage?.erase();
  }
}
