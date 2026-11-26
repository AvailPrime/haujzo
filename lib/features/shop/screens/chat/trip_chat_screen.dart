import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/customer/customer_home_controller.dart';
import '../../models/booking_model.dart';

/// Streamed Unread Chat Counter Badge for Shipper Booking Cards & Headers
class ShipperUnreadChatBadge extends StatelessWidget {
  const ShipperUnreadChatBadge({
    super.key,
    required this.booking,
    this.compact = false,
  });

  final BookingModel booking;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final activeDriverId =
        booking.driverId?.isNotEmpty == true ? booking.driverId! : '';
    final sessionId = (booking.chatSessionId?.isNotEmpty == true)
        ? booking.chatSessionId!
        : (activeDriverId.isNotEmpty
            ? '${activeDriverId}_session'
            : 'default_session');

    if (booking.id.isEmpty ||
        (booking.driverId == null || booking.driverId!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .collection('chats')
          .doc(sessionId)
          .collection('messages')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final unreadCount = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final isMe = (data['senderId'] == currentUserId) ||
              (data['senderRole'] == 'shipper');
          final isSeen = data['isSeen'] == true ||
              data['status']?.toString().toLowerCase() == 'seen';
          return !isMe && !isSeen;
        }).length;

        if (unreadCount <= 0) return const SizedBox.shrink();

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 6.5,
            vertical: compact ? 1.5 : 2,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            unreadCount > 9 ? '9+' : '$unreadCount',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}

/// Interactive Waveform Voice Note Audio Player Widget for Shipper with Speed Control & Base64 Fallback
class ShipperVoiceMessageBubble extends StatefulWidget {
  const ShipperVoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.durationStr,
    required this.isMe,
    this.audioBase64,
    this.messageId,
  });

  final String audioUrl;
  final String durationStr;
  final bool isMe;
  final String? audioBase64;
  final String? messageId;

  @override
  State<ShipperVoiceMessageBubble> createState() =>
      _ShipperVoiceMessageBubbleState();
}

class _ShipperVoiceMessageBubbleState extends State<ShipperVoiceMessageBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  double _playbackRate = 1.0;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  static const List<double> _wavePattern = [
    0.32, 0.55, 0.78, 0.45, 0.92, 0.64, 0.38, 0.85, 1.0, 0.58, 0.74,
    0.42, 0.88, 0.62, 0.95, 0.50, 0.70, 0.84, 0.46, 0.68, 0.52, 0.36,
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _parseInitialDuration();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = (state == PlayerState.playing);
          if (_isPlaying) _isLoadingAudio = false;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted && dur.inMilliseconds > 0) {
        setState(() => _totalDuration = dur);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  void _parseInitialDuration() {
    final parts = widget.durationStr.split(':');
    if (parts.length == 2) {
      final mins = int.tryParse(parts[0]) ?? 0;
      final secs = int.tryParse(parts[1]) ?? 0;
      final parsed = Duration(minutes: mins, seconds: secs);
      _totalDuration = parsed.inSeconds > 0 ? parsed : const Duration(seconds: 5);
    } else {
      _totalDuration = const Duration(seconds: 5);
    }
  }

  @override
  void dispose() {
    try {
      _audioPlayer.stop();
    } catch (_) {}
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isLoadingAudio) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      setState(() => _isLoadingAudio = true);
      await _audioPlayer.setPlaybackRate(_playbackRate);

      final url = widget.audioUrl.trim();
      bool started = false;

      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _audioPlayer.play(UrlSource(url));
        started = true;
      } else if (!kIsWeb && url.isNotEmpty && File(url).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(url));
        started = true;
      }

      if (!started &&
          !kIsWeb &&
          widget.audioBase64 != null &&
          widget.audioBase64!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final safeId =
            widget.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
        final tempFile = File('${tempDir.path}/vn_cache_$safeId.m4a');
        if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
          final bytes = base64Decode(widget.audioBase64!);
          await tempFile.writeAsBytes(bytes, flush: true);
        }
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        started = true;
      }

      if (!started && mounted) {
        setState(() {
          _isLoadingAudio = false;
          _isPlaying = false;
        });
        Get.snackbar(
          'Voice Note',
          'Voice note is still syncing. Please try again in a moment.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF122F51),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (kDebugMode) print('AudioPlayer toggle error: $e');
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _isPlaying = false;
        });
      }
    } finally {
      if (mounted && _isLoadingAudio) {
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  Future<void> _cycleSpeed() async {
    HapticFeedback.selectionClick();
    double nextRate = 1.0;
    if (_playbackRate == 1.0) {
      nextRate = 1.5;
    } else if (_playbackRate == 1.5) {
      nextRate = 2.0;
    } else {
      nextRate = 1.0;
    }
    setState(() => _playbackRate = nextRate);
    try {
      await _audioPlayer.setPlaybackRate(nextRate);
    } catch (_) {}
  }

  Future<void> _seekToRatio(double ratio) async {
    final clamped = ratio.clamp(0.0, 1.0);
    final totalMs = _totalDuration.inMilliseconds > 0
        ? _totalDuration.inMilliseconds
        : 5000;
    final targetMs = (totalMs * clamped).round();
    final targetDuration = Duration(milliseconds: targetMs);
    setState(() => _position = targetDuration);
    try {
      await _audioPlayer.seek(targetDuration);
    } catch (_) {}
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final mins = duration.inMinutes.remainder(60);
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AvailHelperFunctions.isDarkMode(context);
    final fgColor = widget.isMe
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF0F172A));
    final activeWaveColor =
        widget.isMe ? Colors.white : const Color(0xFF10B981);
    final inactiveWaveColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.30)
        : (isDark
            ? Colors.white.withValues(alpha: 0.22)
            : const Color(0xFFCBD5E1));

    final totalMs = _totalDuration.inMilliseconds > 0
        ? _totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final progress =
        (_position.inMilliseconds.toDouble() / totalMs).clamp(0.0, 1.0);

    return Container(
      width: 242,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.black.withValues(alpha: 0.14)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.16)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: activeWaveColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeWaveColor.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: _isLoadingAudio
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              widget.isMe ? AvailColors.primary : Colors.white,
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color:
                            widget.isMe ? AvailColors.primary : Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final maxW = constraints.maxWidth > 0
                        ? constraints.maxWidth
                        : 140.0;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _seekToRatio(details.localPosition.dx / maxW),
                      onHorizontalDragUpdate: (details) =>
                          _seekToRatio(details.localPosition.dx / maxW),
                      child: SizedBox(
                        height: 26,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_wavePattern.length, (i) {
                            final barThreshold = i / _wavePattern.length;
                            final isPlayed = progress >= barThreshold &&
                                (_isPlaying || _position.inMilliseconds > 0);
                            final barHeight =
                                (6.0 + (_wavePattern[i] * 18.0)).clamp(6.0, 24.0);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 3.0,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: isPlayed
                                    ? activeWaveColor
                                    : inactiveWaveColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.microphone_2,
                          size: 10.5,
                          color: fgColor.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isPlaying || _position.inSeconds > 0
                              ? '${_formatDuration(_position)} / ${widget.durationStr}'
                              : widget.durationStr,
                          style: TextStyle(
                            color: fgColor.withValues(alpha: 0.88),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: activeWaveColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_playbackRate == 1.0 ? "1" : (_playbackRate == 2.0 ? "2" : "1.5")}x',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: fgColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TripChatScreen extends StatefulWidget {
  final BookingModel booking;

  const TripChatScreen({super.key, required this.booking});

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? replyingToMessage;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedDocs = [];

  bool isRecording = false;
  bool isRecordingPaused = false;
  bool isPlayingPreview = false;
  bool isUploadingMedia = false;

  int recordSeconds = 0;
  Timer? recordTimer;
  Timer? _typingDebounce;
  bool _isCurrentlyTyping = false;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  double _currentAmplitude = 0.18;
  String? _currentRecordingPath;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _bookingStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _chatSessionDocStream;
  String? _currentStreamSessionId;

  final List<Map<String, dynamic>> quickTemplates = const [
    {'icon': Iconsax.location, 'text': 'Cargo is ready for loading at pickup'},
    {'icon': Iconsax.clock, 'text': 'What is your current ETA to pickup?'},
    {'icon': Iconsax.shield_tick, 'text': 'Please handle fragile items with care'},
    {'icon': Iconsax.call_calling, 'text': 'Call receiver upon arrival at gate'},
    {'icon': Iconsax.verify, 'text': 'Thank you for the update!'},
  ];

  @override
  void initState() {
    super.initState();
    _bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.booking.id)
        .snapshots();
    _updateShipperPresence(true);
    _initPreviewPlayerListener();
  }

  void _initPreviewPlayerListener() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => isPlayingPreview = false);
      }
    });
  }

  @override
  void dispose() {
    _setTypingStatus(false);
    _typingDebounce?.cancel();
    _updateShipperPresence(false);
    recordTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    try {
      _audioPlayer.stop();
    } catch (_) {}
    _audioPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateShipperPresence(bool isOnline) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    }
  }

  void _onTextChanged(String val, String sessionId) {
    setState(() {});
    if (sessionId.isEmpty) return;

    if (val.trim().isNotEmpty && !_isCurrentlyTyping) {
      _setTypingStatus(true, sessionId: sessionId);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_isCurrentlyTyping) {
        _setTypingStatus(false, sessionId: sessionId);
      }
    });
  }

  void _setTypingStatus(bool typing, {String? sessionId}) {
    _isCurrentlyTyping = typing;
    final targetSession = sessionId ?? _currentStreamSessionId;
    if (targetSession == null || targetSession.isEmpty) return;

    FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.booking.id)
        .collection('chats')
        .doc(targetSession)
        .set({
      'shipperTyping': typing,
      'shipperTypingUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});
  }

  // --- REAL VOICE NOTE RECORDING LOGIC FOR SHIPPER ---

  Future<void> _startRecording() async {
    if (isRecording) return;

    if (kIsWeb) {
      Get.snackbar(
        'Voice Note Info',
        'Voice recording is supported on Android & iOS mobile devices.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF122F51),
        colorText: Colors.white,
      );
      return;
    }

    try {
      PermissionStatus micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
      }
      final hasPerm =
          micStatus.isGranted || await _audioRecorder.hasPermission();

      if (!hasPerm) {
        Get.snackbar(
          'Microphone Permission Needed',
          'Please enable microphone access to record voice notes.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Settings',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
        return;
      }

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath =
          '${appDocDir.path}/vn_shipper_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = filePath;

      HapticFeedback.mediumImpact();

      setState(() {
        isRecording = true;
        isRecordingPaused = false;
        isPlayingPreview = false;
        recordSeconds = 0;
        _currentAmplitude = 0.22;
      });

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      );
      await _audioRecorder.start(config, path: filePath);

      recordTimer?.cancel();
      recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && isRecording && !isRecordingPaused) {
          setState(() => recordSeconds++);
        }
      });

      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen((amp) {
        if (mounted && isRecording && !isRecordingPaused) {
          final db = amp.current;
          final normalized = ((db + 50) / 50).clamp(0.10, 1.0);
          setState(() => _currentAmplitude = normalized);
        }
      });
    } catch (e) {
      if (kDebugMode) print('Error starting shipper voice recording: $e');
      if (mounted) setState(() => isRecording = false);
      Get.snackbar(
        'Recorder Unavailable',
        'Could not start microphone recording on this device.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      HapticFeedback.selectionClick();
      setState(() => isRecordingPaused = true);
    } catch (_) {}
  }

  Future<void> _resumeRecording() async {
    try {
      if (isPlayingPreview) {
        await _audioPlayer.stop();
        setState(() => isPlayingPreview = false);
      }
      await _audioRecorder.resume();
      HapticFeedback.selectionClick();
      setState(() => isRecordingPaused = false);
    } catch (_) {}
  }

  Future<void> _toggleRecordedPreview() async {
    if (_currentRecordingPath == null) return;

    if (isPlayingPreview) {
      try {
        await _audioPlayer.pause();
      } catch (_) {}
      setState(() => isPlayingPreview = false);
    } else {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(_currentRecordingPath!));
        setState(() => isPlayingPreview = true);
      } catch (e) {
        if (kDebugMode) print('Preview error: $e');
      }
    }
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    try {
      if (isPlayingPreview) await _audioPlayer.stop();
      recordTimer?.cancel();
      _amplitudeSubscription?.cancel();
      await _audioRecorder.stop();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isRecording = false;
        isRecordingPaused = false;
        isPlayingPreview = false;
        recordSeconds = 0;
        _currentRecordingPath = null;
      });
    }
  }

  Future<void> _stopAndSendRecording(
      String targetSessionId, bool isLocked) async {
    if (isPlayingPreview) {
      try {
        await _audioPlayer.stop();
      } catch (_) {}
    }

    recordTimer?.cancel();
    _amplitudeSubscription?.cancel();

    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } catch (e) {
      if (kDebugMode) print('Error stopping recorder: $e');
    }

    final finalPath = recordedPath ?? _currentRecordingPath;
    final finalDurationSec = recordSeconds > 0 ? recordSeconds : 1;

    setState(() {
      isRecording = false;
      isRecordingPaused = false;
      isPlayingPreview = false;
      recordSeconds = 0;
      _currentRecordingPath = null;
    });

    if (finalPath != null && finalPath.isNotEmpty) {
      final file = File(finalPath);
      if (await file.exists() && await file.length() > 0) {
        await _uploadAndSendVoiceNote(
            file, finalDurationSec, targetSessionId, isLocked);
      }
    }
  }

  Future<void> _uploadAndSendVoiceNote(
    File audioFile,
    int durationSec,
    String targetSessionId,
    bool isLocked,
  ) async {
    if (isLocked) return;

    setState(() => isUploadingMedia = true);
    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'shipper';
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final durationStr = _formatDuration(durationSec);
    final shipperName = widget.booking.senderName.isNotEmpty
        ? widget.booking.senderName
        : 'Shipper';

    final chatDocRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.booking.id)
        .collection('chats')
        .doc(targetSessionId);

    try {
      String? audioBase64Fallback;
      try {
        final bytes = await audioFile.readAsBytes();
        if (bytes.length <= 550000) {
          audioBase64Fallback = base64Encode(bytes);
        }
      } catch (_) {}

      final Map<String, dynamic> messagePayload = {
        'senderId': senderId,
        'chatSessionId': targetSessionId,
        'senderName': shipperName,
        'senderRole': 'shipper',
        'type': 'audio',
        'text': '🎤 Voice Note ($durationStr)',
        'audioUrl': audioFile.path,
        if (audioBase64Fallback != null) 'audioBase64': audioBase64Fallback,
        'duration': durationStr.isNotEmpty ? durationStr : '0:01',
        'durationSeconds': durationSec,
        'status': 'sent',
        'isSeen': false,
        'isDelivered': true,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAtMs': timestampMs,
      };

      if (replyingToMessage != null) {
        messagePayload['replyToId'] = replyingToMessage!['id'];
        messagePayload['replyToText'] = replyingToMessage!['text'];
        messagePayload['replyToSenderName'] =
            replyingToMessage!['senderName'];
        setState(() => replyingToMessage = null);
      }

      final docRef =
          await chatDocRef.collection('messages').add(messagePayload);

      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .collection('messages')
            .doc(docRef.id)
            .set(messagePayload);
      } catch (_) {}

      await chatDocRef.set({
        'shipperId': senderId,
        'chatSessionId': targetSessionId,
        'shipperName': shipperName,
        'lastMessage': '🎤 Voice Note ($durationStr)',
        'lastSenderRole': 'shipper',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAtMs': timestampMs,
        'bookingId': widget.booking.id,
      }, SetOptions(merge: true));

      HapticFeedback.selectionClick();
      _scrollToBottom();

      // Upload to Firebase Storage
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('voice_notes/$targetSessionId/voice_$timestampMs.m4a');

        final uploadTask = await storageRef.putFile(
          audioFile,
          SettableMetadata(contentType: 'audio/mp4'),
        );
        final audioUrl = await uploadTask.ref.getDownloadURL();

        await docRef.update({'audioUrl': audioUrl});
        try {
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.booking.id)
              .collection('messages')
              .doc(docRef.id)
              .update({'audioUrl': audioUrl});
        } catch (_) {}
      } catch (storageErr) {
        if (kDebugMode) {
          print('Shipper voice note using audioBase64 fallback: $storageErr');
        }
      }

      final driverId = widget.booking.driverId;
      if (driverId != null && driverId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .collection('notifications')
              .add({
            'title': 'Voice Note from $shipperName 🎤',
            'message': '🎤 Voice Note ($durationStr)',
            'type': 'chat',
            'targetId': widget.booking.id,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('Error sending shipper voice note: $e');
    } finally {
      if (mounted) setState(() => isUploadingMedia = false);
    }
  }

  // --- ATTACHMENTS: CAMERA, GALLERY, LIVE GPS PIN, VOICE NOTE ---

  void _showAttachmentSheet(BuildContext context, BookingModel booking,
      String sessionId, bool isLocked) {
    if (isLocked) return;
    final isDark = AvailHelperFunctions.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF132238) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share Trip Attachment',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Send cargo photos, gate pin coordinates, or a voice note to your driver',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAttachmentOption(
                    icon: Iconsax.camera,
                    label: 'Camera',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(
                          ImageSource.camera, sessionId, isLocked);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Iconsax.gallery,
                    label: 'Gallery',
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(
                          ImageSource.gallery, sessionId, isLocked);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Iconsax.location,
                    label: 'Pickup GPS',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendCurrentLocationPin(booking, sessionId, isLocked);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Iconsax.microphone_2,
                    label: 'Voice Note',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startRecording();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCurrentLocationPin(
      BookingModel booking, String targetSessionId, bool isLocked) async {
    if (isLocked) return;

    double? lat;
    double? lng;

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    if (lat == null && booking.pickupLocation != null) {
      lat = booking.pickupLocation!.latitude;
      lng = booking.pickupLocation!.longitude;
    }

    if (lat == null || lng == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'shipper';
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final shipperName = widget.booking.senderName.isNotEmpty
        ? widget.booking.senderName
        : 'Shipper';

    final chatDocRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.booking.id)
        .collection('chats')
        .doc(targetSessionId);

    final Map<String, dynamic> messagePayload = {
      'senderId': senderId,
      'chatSessionId': targetSessionId,
      'senderName': shipperName,
      'senderRole': 'shipper',
      'type': 'location',
      'text': '📍 Shared Pickup / Gate GPS Pin',
      'lat': lat,
      'lng': lng,
      'status': 'sent',
      'isSeen': false,
      'isDelivered': true,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAtMs': timestampMs,
    };

    try {
      final docRef =
          await chatDocRef.collection('messages').add(messagePayload);
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .collection('messages')
            .doc(docRef.id)
            .set(messagePayload);
      } catch (_) {}

      await chatDocRef.set({
        'shipperId': senderId,
        'chatSessionId': targetSessionId,
        'shipperName': shipperName,
        'lastMessage': '📍 Shared Pickup GPS Location',
        'lastSenderRole': 'shipper',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAtMs': timestampMs,
        'bookingId': widget.booking.id,
      }, SetOptions(merge: true));

      HapticFeedback.selectionClick();
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) print('Error sending shipper location pin: $e');
    }
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(1, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _markIncomingMessagesAsRead(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String currentUserId) {
    for (var doc in docs) {
      final data = doc.data();
      final isMe = (data['senderId'] == currentUserId) ||
          (data['senderRole'] == 'shipper');
      if (!isMe && (data['isSeen'] != true || data['status'] != 'seen')) {
        doc.reference.update({
          'isSeen': true,
          'status': 'seen',
          'seenAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    }
  }

  Future<void> _sendMessage(
      String text, String targetSessionId, bool isLocked) async {
    if (isLocked) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _messageController.clear();
    _setTypingStatus(false, sessionId: targetSessionId);

    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'shipper';
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final shipperName = widget.booking.senderName.isNotEmpty
        ? widget.booking.senderName
        : 'Shipper';

    final chatDocRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.booking.id)
        .collection('chats')
        .doc(targetSessionId);

    final Map<String, dynamic> messagePayload = {
      'senderId': senderId,
      'chatSessionId': targetSessionId,
      'senderName': shipperName,
      'senderRole': 'shipper',
      'type': 'text',
      'text': cleanText,
      'status': 'sent',
      'isSeen': false,
      'isDelivered': true,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAtMs': timestampMs,
    };

    if (replyingToMessage != null) {
      messagePayload['replyToId'] = replyingToMessage!['id'];
      messagePayload['replyToText'] = replyingToMessage!['text'];
      messagePayload['replyToSenderName'] = replyingToMessage!['senderName'];
      setState(() => replyingToMessage = null);
    }

    try {
      final docRef =
          await chatDocRef.collection('messages').add(messagePayload);

      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .collection('messages')
            .doc(docRef.id)
            .set(messagePayload);
      } catch (_) {}

      await chatDocRef.set({
        'shipperId': senderId,
        'chatSessionId': targetSessionId,
        'shipperName': shipperName,
        'lastMessage': cleanText,
        'lastSenderRole': 'shipper',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAtMs': timestampMs,
        'bookingId': widget.booking.id,
      }, SetOptions(merge: true));

      final driverId = widget.booking.driverId;
      if (driverId != null && driverId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .collection('notifications')
              .add({
            'title': 'Message from $shipperName 💬',
            'message': cleanText,
            'type': 'chat',
            'targetId': widget.booking.id,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      HapticFeedback.selectionClick();
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) print('Error sending message: $e');
    }
  }

  Future<void> _pickAndSendImage(
      ImageSource source, String targetSessionId, bool isLocked) async {
    if (isLocked) return;
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1280,
      );
      if (picked == null) return;

      setState(() => isUploadingMedia = true);
      final user = FirebaseAuth.instance.currentUser;
      final senderId = user?.uid ?? 'shipper';
      final timestampMs = DateTime.now().millisecondsSinceEpoch;
      final shipperName = widget.booking.senderName.isNotEmpty
          ? widget.booking.senderName
          : 'Shipper';
      final bytes = await picked.readAsBytes();

      String imageUrl = '';
      String? imageBase64Fallback;
      if (bytes.length <= 550000) {
        imageBase64Fallback = base64Encode(bytes);
      }

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_images/${widget.booking.id}/img_$timestampMs.jpg');
        final uploadTask = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrl = await uploadTask.ref.getDownloadURL();
      } catch (storageErr) {
        if (kDebugMode) print('Using base64 image fallback: $storageErr');
        imageBase64Fallback ??= base64Encode(bytes);
      }

      final chatDocRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id)
          .collection('chats')
          .doc(targetSessionId);

      final Map<String, dynamic> messagePayload = {
        'senderId': senderId,
        'chatSessionId': targetSessionId,
        'senderName': shipperName,
        'senderRole': 'shipper',
        'type': 'image',
        'text': '📷 Cargo / Pickup Photo',
        'imageUrl': imageUrl,
        if (imageBase64Fallback != null) 'imageBase64': imageBase64Fallback,
        'status': 'sent',
        'isSeen': false,
        'isDelivered': true,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAtMs': timestampMs,
      };

      if (replyingToMessage != null) {
        messagePayload['replyToId'] = replyingToMessage!['id'];
        messagePayload['replyToText'] = replyingToMessage!['text'];
        messagePayload['replyToSenderName'] =
            replyingToMessage!['senderName'];
        setState(() => replyingToMessage = null);
      }

      final docRef =
          await chatDocRef.collection('messages').add(messagePayload);
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .collection('messages')
            .doc(docRef.id)
            .set(messagePayload);
      } catch (_) {}

      await chatDocRef.set({
        'shipperId': senderId,
        'chatSessionId': targetSessionId,
        'shipperName': shipperName,
        'lastMessage': '📷 Sent a photo',
        'lastSenderRole': 'shipper',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAtMs': timestampMs,
        'bookingId': widget.booking.id,
      }, SetOptions(merge: true));

      HapticFeedback.selectionClick();
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) print('Error sending image in shipper chat: $e');
    } finally {
      if (mounted) setState(() => isUploadingMedia = false);
    }
  }

  void _setReplyMessage(String docId, String text, String senderName) {
    HapticFeedback.lightImpact();
    setState(() {
      replyingToMessage = {
        'id': docId,
        'text': text,
        'senderName': senderName,
      };
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 180), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- EDIT & DELETE UNSEEN MESSAGES LOGIC FOR SHIPPER ---

  void _showOptionModal(String docId, Map<String, dynamic> data,
      String senderName, String targetSessionId, bool isMe) {
    final isDark = AvailHelperFunctions.isDarkMode(context);
    final status = data['status']?.toString().toLowerCase();
    final isSeen =
        data['isSeen'] == true || status == 'seen' || status == 'read';
    final msgType = data['type']?.toString() ?? 'text';
    final isText = msgType == 'text' &&
        !(data['text']?.toString().contains('Voice Note') ?? false);

    final canEdit = isMe && !isSeen && isText;
    final canDelete = isMe && !isSeen;
    final text = data['text']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF132238) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.reply_rounded, color: AvailColors.primary),
              title: Text('Reply to Message',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                _setReplyMessage(docId, text, senderName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.blue),
              title: Text('Copy Message Text',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: text));
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Iconsax.edit, color: Colors.orange),
                title: Text('Edit Message',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMessageDialog(docId, data, targetSessionId);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Iconsax.trash, color: Colors.red),
                title: const Text('Delete Message',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmationDialog(docId, targetSessionId);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditMessageDialog(
      String docId, Map<String, dynamic> data, String targetSessionId) {
    final currentText = data['text']?.toString() ?? '';
    final editController = TextEditingController(text: currentText);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AvailColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.edit5,
                        color: AvailColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Message',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Colors.grey),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: editController,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newText = editController.text.trim();
                        if (newText.isEmpty) return;
                        Get.back();
                        await _editMessage(docId, newText, targetSessionId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AvailColors.primary,
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editMessage(
      String docId, String newText, String targetSessionId) async {
    try {
      final chatDocRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id)
          .collection('chats')
          .doc(targetSessionId);

      await chatDocRef.collection('messages').doc(docId).update({
        'text': newText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .collection('messages')
            .doc(docId)
            .update({
          'text': newText,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _showDeleteConfirmationDialog(String docId, String targetSessionId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Message?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to delete this message for everyone?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _deleteMessage(docId, targetSessionId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String docId, String targetSessionId) async {
    try {
      final chatDocRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id)
          .collection('chats')
          .doc(targetSessionId);

      await chatDocRef.collection('messages').doc(docId).delete();
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.booking.id)
            .collection('messages')
            .doc(docId)
            .delete();
      } catch (_) {}
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  String _formatDateGroupingLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = AvailHelperFunctions.isDarkMode(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _bookingStream,
      builder: (context, bookingSnapshot) {
        BookingModel booking = widget.booking;
        if (bookingSnapshot.hasData &&
            bookingSnapshot.data != null &&
            bookingSnapshot.data!.exists) {
          booking = BookingModel.fromSnapshot(bookingSnapshot.data!);
        }

        final activeDriverId = booking.driverId?.isNotEmpty == true
            ? booking.driverId!
            : (widget.booking.driverId ?? '');

        final activeChatSessionId = (booking.chatSessionId?.isNotEmpty == true)
            ? booking.chatSessionId!
            : ((widget.booking.chatSessionId?.isNotEmpty == true)
                ? widget.booking.chatSessionId!
                : (activeDriverId.isNotEmpty
                    ? '${activeDriverId}_session'
                    : 'default_session'));

        final status = booking.status.toLowerCase().trim();
        final isCompleted = status == 'delivered' || status == 'completed';
        final isCancelled = status == 'cancelled' || status == 'canceled';
        final isChatLocked = isCompleted || isCancelled;

        if (_currentStreamSessionId != activeChatSessionId) {
          _currentStreamSessionId = activeChatSessionId;
          _chatSessionDocStream = FirebaseFirestore.instance
              .collection('bookings')
              .doc(booking.id)
              .collection('chats')
              .doc(activeChatSessionId)
              .snapshots();
          _messagesStream = FirebaseFirestore.instance
              .collection('bookings')
              .doc(booking.id)
              .collection('chats')
              .doc(activeChatSessionId)
              .collection('messages')
              .snapshots();
        }

        final driverName =
            (booking.driverName != null && booking.driverName!.isNotEmpty)
                ? booking.driverName!
                : 'Assigned Driver';
        final vehicleSubtitle =
            '${booking.vehiclePlate ?? "Fleet Unit"} • ${booking.vehicleModel ?? booking.truckType}';

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A192F) : const Color(0xFFF1F5F9),
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF122F51) : Colors.white,
            elevation: 0.5,
            iconTheme: IconThemeData(
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
            titleSpacing: 0,
            title: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AvailColors.primary, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: isDark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFF8FAFC),
                        child: Text(
                          driverName[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isDark
                                ? AvailColors.primary
                                : const Color(0xFF122F51),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF122F51)
                                : Colors.white,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: activeDriverId.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(activeDriverId)
                            .snapshots()
                        : null,
                    builder: (context, driverSnap) {
                      bool isDriverOnline = true;
                      if (driverSnap.hasData &&
                          driverSnap.data?.data() != null) {
                        final dData = driverSnap.data!.data()!;
                        isDriverOnline = dData['isOnline'] == true ||
                            dData['status']?.toString().toLowerCase() ==
                                'online';
                      }

                      return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _chatSessionDocStream,
                        builder: (context, chatDocSnap) {
                          final chatData = chatDocSnap.data?.data();
                          final isDriverTyping =
                              chatData?['driverTyping'] == true;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      driverName,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'DRIVER',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0284C7),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              if (isDriverTyping)
                                const Text(
                                  'Driver is typing...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF10B981),
                                  ),
                                )
                              else
                                Text(
                                  isDriverOnline
                                      ? 'Online • $vehicleSubtitle'
                                      : vehicleSubtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDriverOnline
                                        ? const Color(0xFF10B981)
                                        : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              if (booking.driverPhone != null &&
                  booking.driverPhone!.isNotEmpty)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.call5,
                        color: Color(0xFF10B981), size: 18),
                  ),
                  onPressed: () => CustomerHomeController.instance
                      .callDriver(booking.driverPhone),
                  tooltip: 'Call Driver',
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              // 1. Live Trip Context Ribbon
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF132238)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AvailColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${booking.bookingId.isNotEmpty ? booking.bookingId : booking.id.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AvailColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${booking.pickupAddress} ➔ ${booking.dropoffAddress}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isChatLocked)
                      InkWell(
                        onTap: () => _sendCurrentLocationPin(
                            booking, activeChatSessionId, isChatLocked),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.location5,
                                  size: 11, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Send GPS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (isUploadingMedia)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: AvailColors.primary,
                  backgroundColor: Colors.transparent,
                ),

              // 2. Messages Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      _cachedDocs = snapshot.data!.docs.toList();
                      _cachedDocs.sort((a, b) {
                        final dataA = a.data();
                        final dataB = b.data();
                        final tsA = dataA['timestamp'] as Timestamp?;
                        final tsB = dataB['timestamp'] as Timestamp?;
                        final msA = tsA?.millisecondsSinceEpoch ??
                            (dataA['createdAtMs'] as int? ?? 0);
                        final msB = tsB?.millisecondsSinceEpoch ??
                            (dataB['createdAtMs'] as int? ?? 0);
                        return msA.compareTo(msB);
                      });

                      if (_cachedDocs.isNotEmpty && currentUserId != null) {
                        _markIncomingMessagesAsRead(
                            _cachedDocs, currentUserId);
                      }
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _cachedDocs.isEmpty) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AvailColors.primary));
                    }

                    if (_cachedDocs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AvailColors.primary
                                      .withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Iconsax.messages_2,
                                    size: 36, color: AvailColors.primary),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Direct Driver Channel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Send pickup instructions, voice notes, photos, or GPS pins directly to $driverName.',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      itemCount: _cachedDocs.length,
                      itemBuilder: (context, index) {
                        final doc = _cachedDocs[index];
                        final data = doc.data();
                        final isMe = (data['senderId'] == currentUserId) ||
                            (data['senderRole'] == 'shipper');
                        final text = data['text'] ?? '';
                        final senderName =
                            data['senderName'] ?? (isMe ? 'You' : driverName);
                        final ts = data['timestamp'];

                        DateTime messageTime = DateTime.now();
                        if (ts is Timestamp) {
                          messageTime = ts.toDate();
                        } else if (data['createdAtMs'] is int) {
                          messageTime = DateTime.fromMillisecondsSinceEpoch(
                              data['createdAtMs']);
                        }

                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevData = _cachedDocs[index - 1].data();
                          final prevTs = prevData['timestamp'];
                          DateTime prevTime = DateTime.now();
                          if (prevTs is Timestamp) {
                            prevTime = prevTs.toDate();
                          } else if (prevData['createdAtMs'] is int) {
                            prevTime = DateTime.fromMillisecondsSinceEpoch(
                                prevData['createdAtMs']);
                          }
                          if (prevTime.year != messageTime.year ||
                              prevTime.month != messageTime.month ||
                              prevTime.day != messageTime.day) {
                            showDateHeader = true;
                          }
                        }

                        final timeStr =
                            DateFormat('HH:mm').format(messageTime);

                        return Column(
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF132238)
                                          : Colors.black
                                              .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatDateGroupingLabel(messageTime),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Dismissible(
                              key: Key(doc.id),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (dir) async {
                                _setReplyMessage(doc.id, text, senderName);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 16),
                                child: const Icon(Icons.reply_rounded,
                                    color: AvailColors.primary, size: 24),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onLongPress: () => _showOptionModal(
                                    doc.id,
                                    data,
                                    senderName,
                                    activeChatSessionId,
                                    isMe),
                                child: _buildMessageBubble(doc.id, data, text,
                                    senderName, timeStr, isMe, isDark),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // 3. Quoted Replying Banner
              if (replyingToMessage != null && !isChatLocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF132238)
                        : const Color(0xFFF1F5F9),
                    border: const Border(
                      left: BorderSide(color: AvailColors.primary, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded,
                          size: 16, color: AvailColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Replying to ${replyingToMessage!['senderName']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark
                                    ? AvailColors.primary
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              replyingToMessage!['text'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.grey),
                        onPressed: () =>
                            setState(() => replyingToMessage = null),
                      ),
                    ],
                  ),
                ),

              // 4. Quick Template Chips
              if (!isChatLocked && !isRecording)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E1D34) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickTemplates.length,
                    itemBuilder: (ctx, i) {
                      final item = quickTemplates[i];
                      return Padding(
                        padding: const EdgeInsets.only(
                            right: 6, top: 6, bottom: 6),
                        child: InkWell(
                          onTap: () => _sendMessage(item['text'] as String,
                              activeChatSessionId, isChatLocked),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF132238)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1E3A5F)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 12,
                                  color: AvailColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  item['text'] as String,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 5. Voice Recording Bar OR Chat Input Bar OR Locked Channel Banner
              if (isChatLocked)
                SafeArea(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    color: isDark
                        ? const Color(0xFF0E1D34)
                        : const Color(0xFFF1F5F9),
                    child: Text(
                      isCancelled
                          ? 'Trip was cancelled. Communication channel is closed.'
                          : 'Trip delivered & completed. Communication channel is archived.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (isRecording)
                _buildRecordingControllerBar(
                    activeChatSessionId, isChatLocked, isDark)
              else
                _buildChatInputBar(
                    booking, activeChatSessionId, isChatLocked, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingControllerBar(
      String activeChatSessionId, bool isChatLocked, bool isDark) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0E1D34) : Colors.white,
          border: Border(
            top: BorderSide(
                color: isDark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _cancelRecording,
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.trash, color: Colors.red, size: 18),
              ),
              tooltip: 'Discard Voice Note',
            ),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.3, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (c, val, _) => Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(
                              alpha: isRecordingPaused ? 0.35 : val),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _formatDuration(recordSeconds),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color:
                            isDark ? Colors.red.shade300 : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(14, (i) {
                          const multipliers = [
                            0.4, 0.75, 1.0, 0.6, 1.3, 0.85, 1.4,
                            0.9, 1.2, 0.7, 1.1, 0.65, 0.95, 0.5,
                          ];
                          final scale = multipliers[i % multipliers.length];
                          final barHeight = isRecordingPaused
                              ? 5.0
                              : (4.0 + (_currentAmplitude * 22.0 * scale))
                                  .clamp(4.0, 26.0);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 85),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 1.2),
                            width: 2.8,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color:
                                  isRecordingPaused ? Colors.grey : Colors.red,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isRecordingPaused)
              IconButton(
                onPressed: _toggleRecordedPreview,
                icon: Icon(
                  isPlayingPreview
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: const Color(0xFF10B981),
                  size: 28,
                ),
                tooltip:
                    isPlayingPreview ? 'Pause Preview' : 'Listen Preview',
              ),
            IconButton(
              onPressed:
                  isRecordingPaused ? _resumeRecording : _pauseRecording,
              icon: Icon(
                isRecordingPaused ? Icons.mic_rounded : Icons.pause_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 22,
              ),
              tooltip: isRecordingPaused
                  ? 'Resume Recording'
                  : 'Pause Recording',
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () =>
                  _stopAndSendRecording(activeChatSessionId, isChatLocked),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AvailColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AvailColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Iconsax.send_1,
                    color: Colors.white, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInputBar(BookingModel booking, String activeChatSessionId,
      bool isChatLocked, bool isDark) {
    final hasText = _messageController.text.trim().isNotEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0E1D34) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _showAttachmentSheet(
                  context, booking, activeChatSessionId, isChatLocked),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF132238)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.add,
                  size: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              tooltip: 'Attach Photo, Voice Note or Pickup Location',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                onChanged: (val) => _onTextChanged(val, activeChatSessionId),
                decoration: InputDecoration(
                  hintText: 'Message driver...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF132238)
                      : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (txt) =>
                    _sendMessage(txt, activeChatSessionId, isChatLocked),
              ),
            ),
            const SizedBox(width: 8),
            if (hasText)
              GestureDetector(
                onTap: () => _sendMessage(_messageController.text,
                    activeChatSessionId, isChatLocked),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AvailColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AvailColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Iconsax.send_1,
                      color: Colors.white, size: 19),
                ),
              )
            else
              GestureDetector(
                onTap: _startRecording,
                onLongPress: _startRecording,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.microphone_2,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final imageBase64 = data['imageBase64']?.toString() ?? '';

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, imageUrl, null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 225,
            height: 165,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 225,
              height: 165,
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) {
              if (imageBase64.isNotEmpty) {
                final bytes = base64Decode(imageBase64);
                return Image.memory(bytes,
                    width: 225, height: 165, fit: BoxFit.cover);
              }
              return Container(
                width: 225,
                height: 120,
                color: Colors.black12,
                child: const Icon(Iconsax.image, size: 32),
              );
            },
          ),
        ),
      );
    } else if (imageBase64.isNotEmpty) {
      final bytes = base64Decode(imageBase64);
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, null, bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 225,
            height: 165,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showFullScreenImage(
      BuildContext context, String? imageUrl, Uint8List? memoryBytes) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: memoryBytes != null
                  ? Image.memory(memoryBytes, fit: BoxFit.contain)
                  : CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fit: BoxFit.contain,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    String docId,
    Map<String, dynamic> data,
    String text,
    String senderName,
    String timeStr,
    bool isMe,
    bool isDark,
  ) {
    final replyToText = data['replyToText']?.toString();
    final replyToSenderName = data['replyToSenderName']?.toString();
    final msgType = data['type']?.toString() ?? 'text';
    final isAudio = msgType == 'audio' ||
        (data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty) ||
        (data['audioBase64'] != null &&
            data['audioBase64'].toString().isNotEmpty) ||
        text.contains('Voice Note');
    final isImage = msgType == 'image' &&
        ((data['imageUrl'] != null &&
                data['imageUrl'].toString().isNotEmpty) ||
            (data['imageBase64'] != null &&
                data['imageBase64'].toString().isNotEmpty));
    final isLocation =
        msgType == 'location' && data['lat'] != null && data['lng'] != null;

    final bubbleBg = isMe
        ? AvailColors.primary
        : (isDark ? const Color(0xFF132238) : Colors.white);
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    final status = data['status']?.toString().toLowerCase();
    final isSeen =
        data['isSeen'] == true || status == 'seen' || status == 'read';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe
              ? null
              : Border.all(
                  color: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE2E8F0),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AvailColors.primary
                        : const Color(0xFF0284C7),
                  ),
                ),
              ),
            if (replyToText != null && replyToText.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.black.withValues(alpha: 0.14)
                      : (isDark
                          ? const Color(0xFF0A192F)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? Colors.white : AvailColors.primary,
                      width: 3.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      replyToSenderName ?? 'Reply',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: isMe ? Colors.white : AvailColors.primary,
                      ),
                    ),
                    Text(
                      replyToText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white70
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            if (isImage) ...[
              _buildImagePreview(data),
              const SizedBox(height: 5),
            ] else if (isLocation) ...[
              InkWell(
                onTap: () async {
                  final lat = (data['lat'] as num).toDouble();
                  final lng = (data['lng'] as num).toDouble();
                  final uri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 225,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.black.withValues(alpha: 0.12)
                        : (isDark
                            ? const Color(0xFF0A192F)
                            : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMe
                          ? Colors.white24
                          : const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.location5,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe
                                  ? 'Pickup / Gate GPS Pin'
                                  : 'Driver Live GPS Pin',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Tap to view on Google Maps',
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ] else if (isAudio) ...[
              ShipperVoiceMessageBubble(
                audioUrl: data['audioUrl']?.toString() ?? '',
                audioBase64: data['audioBase64']?.toString(),
                messageId: docId,
                durationStr: data['duration']?.toString() ?? '0:05',
                isMe: isMe,
              ),
              const SizedBox(height: 4),
            ] else ...[
              Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (data['isEdited'] == true) ...[
                  Text(
                    'edited • ',
                    style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: isMe
                          ? Colors.white70
                          : (isDark ? Colors.grey.shade400 : Colors.grey[600]),
                    ),
                  ),
                ],
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isMe
                        ? Colors.white70
                        : (isDark ? Colors.grey.shade400 : Colors.grey[600]),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: isSeen ? const Color(0xFF38BDF8) : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
