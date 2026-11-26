/// A utility class to map platform-specific exception codes to readable messages.
class AvailPlatformException implements Exception {
  /// The platform error code received from the exception.
  final String code;

  /// Constructor to initialize with the error code.
  AvailPlatformException(this.code);

  /// Returns a user-friendly message based on the platform error code.
  String get message {
    switch (code) {
    // Permissions
      case 'camera_access_denied':
        return 'Camera access was denied. Please check your permissions.';
      case 'camera_access_restricted':
        return 'Camera access is restricted by system policy.';
      case 'microphone_access_denied':
        return 'Microphone access was denied. Please grant permission.';
      case 'storage_permission_denied':
        return 'Storage access permission was denied.';
      case 'location_permission_denied':
        return 'Location permission was denied by the user.';
      case 'location_permission_permanently_denied':
        return 'Location permission is permanently denied. Please enable it from settings.';
      case 'notification_permission_denied':
        return 'Notification permissions were denied by the user.';

    // Location & GPS
      case 'location_services_disabled':
        return 'Location services are disabled. Enable them in settings.';
      case 'gps_signal_lost':
        return 'GPS signal lost. Please move to an open area.';
      case 'location_timeout':
        return 'Location request timed out. Try again.';

    // Connectivity
      case 'network_unavailable':
        return 'No internet connection available.';
      case 'wifi_disabled':
        return 'Wi-Fi is disabled. Enable it in settings.';
      case 'mobile_data_disabled':
        return 'Mobile data is disabled. Enable it in settings.';
      case 'bluetooth_disabled':
        return 'Bluetooth is disabled. Please turn it on.';
      case 'bluetooth_permission_denied':
        return 'Bluetooth permission denied by the user.';
      case 'nfc_not_supported':
        return 'This device does not support NFC.';
      case 'nfc_disabled':
        return 'NFC is disabled. Enable it in settings.';

    // Platform channel / method errors
      case 'method_not_found':
        return 'The requested platform method was not found.';
      case 'channel_error':
        return 'Communication with the platform channel failed.';
      case 'invalid_parameters':
        return 'Invalid parameters were passed to the platform method.';
      case 'activity_not_found':
        return 'Required activity not found. Check your AndroidManifest.';
      case 'service_unavailable':
        return 'The requested platform service is unavailable.';
      case 'platform_version_unsupported':
        return 'This feature is not supported on the current platform version.';

    // File & storage
      case 'file_not_found':
        return 'The specified file was not found on the device.';
      case 'file_read_error':
        return 'Failed to read the file from storage.';
      case 'file_write_error':
        return 'Failed to write the file to storage.';
      case 'file_permission_denied':
        return 'You do not have permission to access this file.';
      case 'storage_full':
        return 'The device storage is full. Free up space to continue.';

    // Media
      case 'media_playback_failed':
        return 'Media playback failed due to an unexpected error.';
      case 'media_format_not_supported':
        return 'The selected media format is not supported.';
      case 'media_recorder_failed':
        return 'Failed to initialize media recorder.';
      case 'screenshot_not_allowed':
        return 'Screenshots are not allowed for this content.';

    // Sensors
      case 'sensor_unavailable':
        return 'The requested sensor is unavailable on this device.';
      case 'accelerometer_error':
        return 'Accelerometer sensor is not functioning properly.';
      case 'gyroscope_error':
        return 'Gyroscope sensor error detected.';
      case 'magnetometer_error':
        return 'Magnetometer sensor is not working correctly.';
      case 'proximity_sensor_error':
        return 'Proximity sensor is unavailable or malfunctioning.';

    // Authentication / security
      case 'biometric_not_enrolled':
        return 'No biometric data enrolled on this device.';
      case 'biometric_unavailable':
        return 'Biometric authentication is unavailable.';
      case 'biometric_auth_failed':
        return 'Biometric authentication failed. Please try again.';
      case 'keychain_error':
        return 'Keychain or secure storage error occurred.';
      case 'security_policy_restricted':
        return 'This action is restricted by device security policy.';

    // Battery / power
      case 'battery_low':
        return 'Battery is too low to complete the operation.';
      case 'power_saving_mode_enabled':
        return 'Power saving mode may affect this feature.';
      case 'charging_required':
        return 'Device must be charging to use this feature.';

    // General platform/system
      case 'os_crash':
        return 'The operating system encountered a fatal error.';
      case 'os_version_not_supported':
        return 'The current OS version is not supported.';
      case 'api_deprecated':
        return 'This API is deprecated and no longer supported.';
      case 'timeout':
        return 'The platform operation timed out.';
      case 'unknown_platform_error':
        return 'An unknown platform error occurred. Please try again.';

    // Catch-all
      default:
        return 'An unexpected platform error occurred. [$code]';
    }
  }
}
