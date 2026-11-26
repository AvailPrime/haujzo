import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../data/repositories/bookings/booking_repository.dart';
import '../../features/shop/models/booking_model.dart';
import '../../features/shop/screens/bookings/widgets/trip_payment_sheet.dart';

/// Plays a loud alert chime + vibration and opens the online payment bottom sheet
/// when a booking is marked as loaded on truck / in transit and has not yet been paid online.
class TripPaymentAlertService extends GetxController {
  static TripPaymentAlertService get instance => Get.isRegistered<TripPaymentAlertService>()
      ? Get.find<TripPaymentAlertService>()
      : Get.put(TripPaymentAlertService(), permanent: true);

  final GetStorage _storage = GetStorage();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _sessionPromptedIds = {};
  bool _isSheetOpen = false;
  Timer? _vibrationTimer;

  static Uint8List? _cachedAlertWav;

  @override
  void onClose() {
    stopAlertSound();
    _audioPlayer.dispose();
    super.onClose();
  }

  void markBookingPromptHandled(String bookingId) {
    if (bookingId.isEmpty) return;
    _sessionPromptedIds.add(bookingId);
    _storage.write('prompted_loaded_pay_$bookingId', true);
    stopAlertSound();
  }

  /// Play a loud, unmistakable multi-tone alert chime + heavy haptic pulses
  Future<void> playLoudAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      if (!kIsWeb) {
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
      }

      _cachedAlertWav ??= _buildLoudAlertWav();
      await _audioPlayer.play(BytesSource(_cachedAlertWav!), volume: 1.0);

      // Pulse haptic vibration 4 times to grab attention
      _vibrationTimer?.cancel();
      int count = 0;
      HapticFeedback.heavyImpact();
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
        count++;
        if (count >= 4) {
          timer.cancel();
        } else {
          HapticFeedback.heavyImpact();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Loud alert sound skipped: $e');
      }
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> stopAlertSound() async {
    _vibrationTimer?.cancel();
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Fetches the latest booking and triggers the loud payment popup if unpaid & loaded/inTransit
  Future<void> triggerLoadedPaymentAlertById(String bookingId, {bool forceShow = false}) async {
    if (bookingId.isEmpty) return;
    try {
      final booking = await BookingRepository.instance.fetchBookingById(bookingId);
      if (booking != null) {
        await triggerLoadedPaymentAlert(booking, forceShow: forceShow);
      }
    } catch (_) {}
  }

  /// Shows the loud payment bottom sheet if the booking is loaded on truck and unpaid
  Future<void> triggerLoadedPaymentAlert(BookingModel booking, {bool forceShow = false}) async {
    if (booking.id.isEmpty || booking.isPaidOnline) return;
    if (!forceShow && !booking.requiresOnlinePaymentPrompt) return;

    if (!forceShow) {
      final alreadyPrompted =
          _sessionPromptedIds.contains(booking.id) || _storage.read('prompted_loaded_pay_${booking.id}') == true;
      if (alreadyPrompted) return;
    }

    if (_isSheetOpen) return;

    _sessionPromptedIds.add(booking.id);
    await _storage.write('prompted_loaded_pay_${booking.id}', true);

    await playLoudAlertSound();

    if (Get.context == null) return;
    _isSheetOpen = true;

    try {
      await showTripPaymentBottomSheet(
        booking: booking,
        isUrgentLoadedAlert: booking.isLoadedOnTruckOrInTransit,
      );
    } finally {
      _isSheetOpen = false;
      await stopAlertSound();
    }
  }

  /// Opens the payment bottom sheet on user tap (from Booking Details banner/button) without alarm
  Future<void> openManualPaymentSheet(BookingModel booking) async {
    if (booking.isPaidOnline || _isSheetOpen) return;
    _isSheetOpen = true;
    try {
      await showTripPaymentBottomSheet(
        booking: booking,
        isUrgentLoadedAlert: booking.isLoadedOnTruckOrInTransit,
      );
    } finally {
      _isSheetOpen = false;
      await stopAlertSound();
    }
  }

  /// Synthesizes a loud, crisp 2.1-second triple-pulse high-attention PCM WAV chime in memory
  static Uint8List _buildLoudAlertWav() {
    const int sampleRate = 22050;
    const double durationSec = 2.1;
    final int numSamples = (sampleRate * durationSec).toInt();
    final int dataBytes = numSamples * 2; // 16-bit mono
    final ByteData buffer = ByteData(44 + dataBytes);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    // RIFF WAV header
    writeAscii(0, 'RIFF');
    buffer.setUint32(4, 36 + dataBytes, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little);  // PCM format
    buffer.setUint16(22, 1, Endian.little);  // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    buffer.setUint32(40, dataBytes, Endian.little);

    // 3 urgent ascending chime bursts (A5 -> D6 -> F#6) repeated twice
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double amp = 0.0;
      double freq = 880.0;

      // Burst windows
      if (t < 0.28) {
        freq = 880.0;
        amp = _envelope(t, 0.0, 0.28);
      } else if (t >= 0.34 && t < 0.62) {
        freq = 1174.66;
        amp = _envelope(t, 0.34, 0.62);
      } else if (t >= 0.68 && t < 1.00) {
        freq = 1479.98;
        amp = _envelope(t, 0.68, 1.00);
      } else if (t >= 1.15 && t < 1.43) {
        freq = 880.0;
        amp = _envelope(t, 1.15, 1.43);
      } else if (t >= 1.49 && t < 1.77) {
        freq = 1174.66;
        amp = _envelope(t, 1.49, 1.77);
      } else if (t >= 1.83 && t < 2.10) {
        freq = 1479.98;
        amp = _envelope(t, 1.83, 2.10);
      }

      // Add slight harmonic overtone for clarity on small phone speakers
      final double wave = 0.78 * math.sin(2 * math.pi * freq * t) +
          0.22 * math.sin(2 * math.pi * (freq * 2.0) * t);
      final int sample = (wave * amp * 31000).round().clamp(-32767, 32767);
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  static double _envelope(double t, double start, double end) {
    final double local = t - start;
    final double len = end - start;
    if (local < 0.015) return local / 0.015;
    if (local > len - 0.04) return math.max(0.0, (len - local) / 0.04);
    return 1.0;
  }
}
