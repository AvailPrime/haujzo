import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:truck_booking/utils/constants/api_constants.dart';
import 'offline_road_corridors.dart';

/// Enum representing the origin/tier of the calculated route
enum RouteSource {
  googleDirections,
  osrmRoads,
  offlineCache,
  offlineSimulated,
}

/// A structured turn-by-turn guidance step along the route
class RouteStepModel {
  final String instruction;
  final double distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final String maneuver;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStepModel({
    required this.instruction,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.maneuver,
    required this.startLocation,
    required this.endLocation,
  });

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'distanceMeters': distanceMeters,
    'distanceText': distanceText,
    'durationSeconds': durationSeconds,
    'durationText': durationText,
    'maneuver': maneuver,
    'startLat': startLocation.latitude,
    'startLng': startLocation.longitude,
    'endLat': endLocation.latitude,
    'endLng': endLocation.longitude,
  };

  factory RouteStepModel.fromJson(Map<String, dynamic> json) => RouteStepModel(
    instruction: json['instruction'] ?? '',
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
    distanceText: json['distanceText'] ?? '',
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    durationText: json['durationText'] ?? '',
    maneuver: json['maneuver'] ?? 'straight',
    startLocation: LatLng(
      (json['startLat'] as num?)?.toDouble() ?? 0.0,
      (json['startLng'] as num?)?.toDouble() ?? 0.0,
    ),
    endLocation: LatLng(
      (json['endLat'] as num?)?.toDouble() ?? 0.0,
      (json['endLng'] as num?)?.toDouble() ?? 0.0,
    ),
  );
}

/// Traffic congestion severity level
enum TrafficSeverity {
  low,      // Emerald Green / Blue (Normal free flow)
  moderate, // Amber / Orange (Moderate delays)
  heavy,    // Crimson Red (Severe bottleneck / congestion)
}

/// A piece/segment of the road route color-coded by real-time traffic conditions
class RouteTrafficSegment {
  final List<LatLng> points;
  final Color color;
  final TrafficSeverity severity;
  final int delaySeconds;

  RouteTrafficSegment({
    required this.points,
    required this.color,
    required this.severity,
    this.delaySeconds = 0,
  });

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'color': color.toARGB32(),
    'severity': severity.name,
    'delaySeconds': delaySeconds,
  };

  factory RouteTrafficSegment.fromJson(Map<String, dynamic> json) {
    final rawPts = (json['points'] as List?) ?? [];
    final pts = rawPts.map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();
    final colVal = json['color'] as int? ?? 0xFF10B981;
    final sevName = json['severity'] as String? ?? 'low';
    final sev = TrafficSeverity.values.firstWhere(
      (e) => e.name == sevName,
      orElse: () => TrafficSeverity.low,
    );
    return RouteTrafficSegment(
      points: pts,
      color: Color(colVal),
      severity: sev,
      delaySeconds: json['delaySeconds'] as int? ?? 0,
    );
  }
}

/// Comprehensive model for calculated road routes, live traffic, and metadata
class RouteDataModel {
  final List<LatLng> points;
  final double distanceKm;
  final String distanceText;
  final int durationMinutes;
  final String durationText;
  final RouteSource source;
  final String summary;
  final List<RouteStepModel> steps;
  final LatLngBounds? bounds;
  final LatLng origin;
  final LatLng destination;
  final List<LatLng> waypoints;
  final DateTime timestamp;

  // Real-Time Google Maps Live Traffic & Congestion Metrics
  final List<RouteTrafficSegment> trafficSegments;
  final String durationInTrafficText;
  final int trafficDelaySeconds;
  final String trafficStatus;
  final Color trafficStatusColor;

  // Suggested Alternative Routes & Shortest Route Designation
  final bool isShortest;
  final String relativeDistanceText;
  final List<RouteDataModel> suggestedAlternatives;

  RouteDataModel({
    required this.points,
    required this.distanceKm,
    required this.distanceText,
    required this.durationMinutes,
    required this.durationText,
    required this.source,
    required this.summary,
    required this.steps,
    this.bounds,
    required this.origin,
    required this.destination,
    this.waypoints = const [],
    this.trafficSegments = const [],
    String? durationInTrafficText,
    this.trafficDelaySeconds = 0,
    String? trafficStatus,
    Color? trafficStatusColor,
    this.isShortest = false,
    this.relativeDistanceText = '',
    this.suggestedAlternatives = const [],
    DateTime? timestamp,
  }) : durationInTrafficText = durationInTrafficText ?? durationText,
       trafficStatus = trafficStatus ?? 'Smooth Traffic Flow',
       trafficStatusColor = trafficStatusColor ?? const Color(0xFF10B981),
       timestamp = timestamp ?? DateTime.now();

  /// Center point of the route for callout badges & midpoint overlays
  LatLng get midpoint => points.isNotEmpty ? points[points.length ~/ 2] : destination;

  bool get isOffline => source == RouteSource.offlineCache || source == RouteSource.offlineSimulated;

  String get sourceBadgeText {
    switch (source) {
      case RouteSource.googleDirections:
        return '⚡ Live Road Route (Google)';
      case RouteSource.osrmRoads:
        return '🛰️ Road Network (OSRM)';
      case RouteSource.offlineCache:
        return '📦 Offline Cached Route';
      case RouteSource.offlineSimulated:
        return '📡 Offline Geodesic Trajectory';
    }
  }

  Color get sourceBadgeColor {
    switch (source) {
      case RouteSource.googleDirections:
        return const Color(0xFF10B981); // Emerald
      case RouteSource.osrmRoads:
        return const Color(0xFF00B0FF); // Light Blue
      case RouteSource.offlineCache:
        return const Color(0xFF8B5CF6); // Purple
      case RouteSource.offlineSimulated:
        return const Color(0xFFF59E0B); // Amber Warning
    }
  }

  /// The exact first vertex on the drivable road network (where vehicle pulls up)
  LatLng get roadOrigin => points.isNotEmpty ? points.first : origin;

  /// The exact final vertex on the drivable road network (where vehicle unloads)
  LatLng get roadDestination => points.isNotEmpty ? points.last : destination;

  RouteDataModel copyWith({
    List<LatLng>? points,
    double? distanceKm,
    String? distanceText,
    int? durationMinutes,
    String? durationText,
    RouteSource? source,
    String? summary,
    List<RouteStepModel>? steps,
    LatLngBounds? bounds,
    LatLng? origin,
    LatLng? destination,
    List<LatLng>? waypoints,
    List<RouteTrafficSegment>? trafficSegments,
    String? durationInTrafficText,
    int? trafficDelaySeconds,
    String? trafficStatus,
    Color? trafficStatusColor,
    bool? isShortest,
    String? relativeDistanceText,
    List<RouteDataModel>? suggestedAlternatives,
    DateTime? timestamp,
  }) {
    return RouteDataModel(
      points: points ?? this.points,
      distanceKm: distanceKm ?? this.distanceKm,
      distanceText: distanceText ?? this.distanceText,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationText: durationText ?? this.durationText,
      source: source ?? this.source,
      summary: summary ?? this.summary,
      steps: steps ?? this.steps,
      bounds: bounds ?? this.bounds,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      waypoints: waypoints ?? this.waypoints,
      trafficSegments: trafficSegments ?? this.trafficSegments,
      durationInTrafficText: durationInTrafficText ?? this.durationInTrafficText,
      trafficDelaySeconds: trafficDelaySeconds ?? this.trafficDelaySeconds,
      trafficStatus: trafficStatus ?? this.trafficStatus,
      trafficStatusColor: trafficStatusColor ?? this.trafficStatusColor,
      isShortest: isShortest ?? this.isShortest,
      relativeDistanceText: relativeDistanceText ?? this.relativeDistanceText,
      suggestedAlternatives: suggestedAlternatives ?? this.suggestedAlternatives,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson({bool includeAlternatives = true}) => {
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'distanceKm': distanceKm,
    'distanceText': distanceText,
    'durationMinutes': durationMinutes,
    'durationText': durationText,
    'source': source.name,
    'summary': summary,
    'steps': steps.map((s) => s.toJson()).toList(),
    'origin': [origin.latitude, origin.longitude],
    'destination': [destination.latitude, destination.longitude],
    'waypoints': waypoints.map((w) => [w.latitude, w.longitude]).toList(),
    'timestamp': timestamp.toIso8601String(),
    'trafficSegments': trafficSegments.map((s) => s.toJson()).toList(),
    'durationInTrafficText': durationInTrafficText,
    'trafficDelaySeconds': trafficDelaySeconds,
    'trafficStatus': trafficStatus,
    'trafficStatusColor': trafficStatusColor.toARGB32(),
    'isShortest': isShortest,
    'relativeDistanceText': relativeDistanceText,
    if (includeAlternatives && suggestedAlternatives.isNotEmpty)
      'suggestedAlternatives': suggestedAlternatives
          .map((a) => a.toJson(includeAlternatives: false))
          .toList(),
    if (bounds != null)
      'bounds': {
        'swLat': bounds!.southwest.latitude,
        'swLng': bounds!.southwest.longitude,
        'neLat': bounds!.northeast.latitude,
        'neLng': bounds!.northeast.longitude,
      },
  };

  factory RouteDataModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List?) ?? [];
    final points = rawPoints.map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();

    final rawOrigin = (json['origin'] as List?) ?? [0.0, 0.0];
    final origin = LatLng((rawOrigin[0] as num).toDouble(), (rawOrigin[1] as num).toDouble());

    final rawDest = (json['destination'] as List?) ?? [0.0, 0.0];
    final destination = LatLng((rawDest[0] as num).toDouble(), (rawDest[1] as num).toDouble());

    final rawWaypoints = (json['waypoints'] as List?) ?? [];
    final waypoints = rawWaypoints.map((w) => LatLng((w[0] as num).toDouble(), (w[1] as num).toDouble())).toList();

    final rawSteps = (json['steps'] as List?) ?? [];
    final steps = rawSteps.map((s) => RouteStepModel.fromJson(Map<String, dynamic>.from(s))).toList();

    final rawTraffic = (json['trafficSegments'] as List?) ?? [];
    final trafficSegments = rawTraffic.map((t) => RouteTrafficSegment.fromJson(Map<String, dynamic>.from(t))).toList();
    final durInTraffic = json['durationInTrafficText'] as String?;
    final trafficDelay = (json['trafficDelaySeconds'] as num?)?.toInt() ?? 0;
    final trafficStatus = json['trafficStatus'] as String?;
    final trafficColorVal = json['trafficStatusColor'] as int?;
    final trafficColor = trafficColorVal != null ? Color(trafficColorVal) : null;

    final bool isShortest = json['isShortest'] as bool? ?? false;
    final String relativeDistText = json['relativeDistanceText'] as String? ?? '';
    final rawAlts = (json['suggestedAlternatives'] as List?) ?? [];
    final List<RouteDataModel> alts = rawAlts
        .map((a) => RouteDataModel.fromJson(Map<String, dynamic>.from(a)))
        .toList();

    LatLngBounds? bounds;
    if (json['bounds'] != null) {
      final b = json['bounds'];
      bounds = LatLngBounds(
        southwest: LatLng((b['swLat'] as num).toDouble(), (b['swLng'] as num).toDouble()),
        northeast: LatLng((b['neLat'] as num).toDouble(), (b['neLng'] as num).toDouble()),
      );
    }

    RouteSource source = RouteSource.offlineCache;
    final srcName = json['source'] as String?;
    if (srcName != null) {
      source = RouteSource.values.firstWhere(
        (e) => e.name == srcName,
        orElse: () => RouteSource.offlineCache,
      );
    }

    return RouteDataModel(
      points: points,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      distanceText: json['distanceText'] ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      durationText: json['durationText'] ?? '',
      source: source,
      summary: json['summary'] ?? '',
      steps: steps,
      bounds: bounds,
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      trafficSegments: trafficSegments,
      durationInTrafficText: durInTraffic,
      trafficDelaySeconds: trafficDelay,
      trafficStatus: trafficStatus,
      trafficStatusColor: trafficColor,
      isShortest: isShortest,
      relativeDistanceText: relativeDistText,
      suggestedAlternatives: alts,
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
    );
  }
}

/// Advanced multi-tier routing engine featuring:
/// - Tier 1: High-Speed Persistent Offline Cache (GetStorage)
/// - Tier 2: Google Directions Online API with road overview & steps
/// - Tier 3: OSRM Driving Road Network API (free open fallback)
/// - Tier 4: Offline Geodesic & Catmull-Rom Curve Synthesizer
/// - Triple-Layer High-Definition Neon Glowing Polylines
class SmartRoutingEngine {
  static final SmartRoutingEngine instance = SmartRoutingEngine._internal();
  SmartRoutingEngine._internal();

  final GetStorage _storage = GetStorage('SmartRouteCache');
  final Map<String, RouteDataModel> _memoryCache = {};

  /// Generate a cache key with 4 decimals precision (~11m spatial tolerance)
  String generateCacheKey(LatLng origin, LatLng destination, [List<LatLng> waypoints = const []]) {
    final sb = StringBuffer();
    sb.write('${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}->');
    for (final w in waypoints) {
      sb.write('${w.latitude.toStringAsFixed(4)},${w.longitude.toStringAsFixed(4)}|');
    }
    sb.write('${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}');
    return sb.toString();
  }

  /// Check connectivity status
  Future<bool> isNetworkAvailable() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Verifies that a given candidate route physically passes within [thresholdMeters] of every intermediate waypoint
  bool routeTraversesAllWaypoints(List<LatLng> points, List<LatLng> waypoints, {double thresholdMeters = 1500.0}) {
    if (waypoints.isEmpty) return true;
    if (points.isEmpty) return false;

    for (final wp in waypoints) {
      bool passedNear = false;
      for (final pt in points) {
        final dist = Geolocator.distanceBetween(wp.latitude, wp.longitude, pt.latitude, pt.longitude);
        if (dist <= thresholdMeters) {
          passedNear = true;
          break;
        }
      }
      if (!passedNear) return false;
    }
    return true;
  }

  /// Retrieves the optimal route with guaranteed multi-tier fallback
  /// Online queries prioritize Google Directions with live traffic & alternatives,
  /// falling back to OSRM or disk cache when network is unavailable.
  Future<RouteDataModel> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool forceRefresh = false,
  }) async {
    final cacheKey = generateCacheKey(origin, destination, waypoints);

    // Check internet connection
    final online = await isNetworkAvailable();

    // 1. Check in-memory cache ONLY if not forceRefresh and has alternatives or offline
    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final memRoute = _memoryCache[cacheKey]!;
      if (memRoute.suggestedAlternatives.isNotEmpty || !online) {
        return memRoute;
      }
    }

    // 2. TIER 1: When online, ALWAYS query Google Directions first for real-time live traffic & alternatives!
    if (online) {
      try {
        final googleRoute = await _fetchFromGoogle(origin, destination, waypoints);
        if (googleRoute != null && googleRoute.points.isNotEmpty) {
          var finalRoute = googleRoute;

          // If Google returned only 1 route option, also query OSRM to find a secondary highway alternative!
          if (finalRoute.suggestedAlternatives.isEmpty) {
            try {
              final osrmRoute = await _fetchFromOsrm(origin, destination, waypoints);
              if (osrmRoute != null && osrmRoute.points.isNotEmpty) {
                final diffKm = (osrmRoute.distanceKm - googleRoute.distanceKm).abs();
                final diffMid = Geolocator.distanceBetween(
                  osrmRoute.points[osrmRoute.points.length ~/ 2].latitude,
                  osrmRoute.points[osrmRoute.points.length ~/ 2].longitude,
                  googleRoute.points[googleRoute.points.length ~/ 2].latitude,
                  googleRoute.points[googleRoute.points.length ~/ 2].longitude,
                );
                // Verify OSRM route physically traverses all waypoints
                final passesWaypoints = waypoints.isEmpty || routeTraversesAllWaypoints(osrmRoute.points, waypoints);
                // If the routes differ by > 0.5 km or diverge by > 800m at midpoint
                if (passesWaypoints && (diffKm > 0.5 || diffMid > 800)) {
                  final all = [googleRoute, osrmRoute];
                  all.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
                  final shortest = all[0];
                  final second = all[1];
                  final diff = (second.distanceKm - shortest.distanceKm).abs();
                  finalRoute = shortest.copyWith(
                    isShortest: true,
                    relativeDistanceText: 'Shortest',
                    suggestedAlternatives: [
                      second.copyWith(
                        isShortest: false,
                        relativeDistanceText: diff > 0.05 ? '+${diff.toStringAsFixed(1)} km' : 'Alternative',
                      ),
                    ],
                  );
                }
              }
            } catch (_) {}
          }

          if (waypoints.isNotEmpty) {
            final validAlts = finalRoute.suggestedAlternatives
                .where((alt) => routeTraversesAllWaypoints(alt.points, waypoints, thresholdMeters: 1500.0))
                .toList();
            finalRoute = finalRoute.copyWith(suggestedAlternatives: validAlts);
          }

          _persistRoute(cacheKey, finalRoute);
          _memoryCache[cacheKey] = finalRoute;
          return finalRoute;
        }
      } catch (e) {
        debugPrint('Google Directions API notice: $e. Falling back to OSRM...');
      }

      // TIER 2: Try OSRM Road Engine fallback
      try {
        var osrmRoute = await _fetchFromOsrm(origin, destination, waypoints);
        if (osrmRoute != null && osrmRoute.points.isNotEmpty) {
          if (waypoints.isNotEmpty) {
            final validAlts = osrmRoute.suggestedAlternatives
                .where((alt) => routeTraversesAllWaypoints(alt.points, waypoints, thresholdMeters: 1500.0))
                .toList();
            osrmRoute = osrmRoute.copyWith(suggestedAlternatives: validAlts);
          }
          _persistRoute(cacheKey, osrmRoute);
          _memoryCache[cacheKey] = osrmRoute;
          return osrmRoute;
        }
      } catch (e) {
        debugPrint('OSRM Road Engine notice: $e. Falling back to offline cache...');
      }
    }

    // 3. TIER 3: Check persistent disk cache (GetStorage) if offline or online APIs failed
    final cachedJson = _storage.read<String>(cacheKey);
    if (cachedJson != null) {
      try {
        final decoded = jsonDecode(cachedJson);
        final cachedRoute = RouteDataModel.fromJson(Map<String, dynamic>.from(decoded));
        final routeWithSource = cachedRoute.copyWith(
          source: RouteSource.offlineCache,
          summary: cachedRoute.summary.isNotEmpty ? cachedRoute.summary : 'Cached Route',
          bounds: cachedRoute.bounds ?? _calculateBounds(cachedRoute.points),
          origin: origin,
          destination: destination,
          waypoints: waypoints,
        );
        _memoryCache[cacheKey] = routeWithSource;
        return routeWithSource;
      } catch (e) {
        debugPrint('Error reading route cache: $e');
      }
    }

    // 4. TIER 4: Generate intelligent curved geodesic offline route
    final simulatedRoute = _generateCurvedGeodesicRoute(origin, destination, waypoints);
    _memoryCache[cacheKey] = simulatedRoute;
    return simulatedRoute;
  }

  /// Fetches driving routes from Google Directions API with Live Traffic Analysis & Alternatives
  /// Automatically parses suggested routes and prioritizes the SHORTEST route by default.
  Future<RouteDataModel?> _fetchFromGoogle(
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) async {
    final sb = StringBuffer('https://maps.googleapis.com/maps/api/directions/json?');
    sb.write('origin=${origin.latitude},${origin.longitude}');
    sb.write('&destination=${destination.latitude},${destination.longitude}');
    sb.write('&mode=driving&departure_time=now&traffic_model=best_guess');
    sb.write('&alternatives=true');

    if (waypoints.isNotEmpty) {
      // Use optimize:false so intermediate stops are visited strictly in defined sequence
      sb.write('&waypoints=optimize:false|');
      for (int i = 0; i < waypoints.length; i++) {
        sb.write('${waypoints[i].latitude},${waypoints[i].longitude}');
        if (i < waypoints.length - 1) sb.write('|');
      }
    }
    sb.write('&key=${APIConstants.googleMapsAPIKey}');

    final response = await http.get(Uri.parse(sb.toString())).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    if (data['status'] != 'OK' || data['routes'] == null || (data['routes'] as List).isEmpty) {
      return null;
    }

    final PolylinePoints polylineDecoder = PolylinePoints();
    final List<RouteDataModel> parsedRoutes = [];

    for (final rawRoute in (data['routes'] as List)) {
      try {
        final parsed = _parseGoogleRoute(
          Map<String, dynamic>.from(rawRoute),
          origin,
          destination,
          waypoints,
          polylineDecoder,
        );
        if (parsed != null && parsed.points.isNotEmpty) {
          // Strictly verify that candidate route passes through all intermediate stops
          if (waypoints.isEmpty || routeTraversesAllWaypoints(parsed.points, waypoints)) {
            parsedRoutes.add(parsed);
          }
        }
      } catch (e) {
        debugPrint('Google alternative route parse error: $e');
      }
    }

    if (parsedRoutes.isEmpty) return null;

    // Google Directions returns routes in order of recommendation (fastest/optimal in current traffic first).
    // Preserve Google's recommended route as primary (index 0), and populate suggestedAlternatives.
    final recommended = parsedRoutes.first;
    final List<RouteDataModel> alternatives = [];

    for (int i = 1; i < parsedRoutes.length; i++) {
      final alt = parsedRoutes[i];
      final diffKm = alt.distanceKm - recommended.distanceKm;
      final diffMins = alt.durationMinutes - recommended.durationMinutes;

      String tagText;
      if (diffKm < -0.15) {
        tagText = 'Shortest (${diffKm.abs().toStringAsFixed(1)} km shorter)';
      } else if (diffMins > 0) {
        tagText = '+$diffMins m';
      } else if (diffKm > 0.05) {
        tagText = '+${diffKm.toStringAsFixed(1)} km';
      } else {
        tagText = alt.summary;
      }

      alternatives.add(alt.copyWith(
        isShortest: diffKm < -0.15,
        relativeDistanceText: tagText,
      ));
    }

    final finalRoute = recommended.copyWith(
      isShortest: !alternatives.any((a) => a.distanceKm < recommended.distanceKm),
      relativeDistanceText: 'Fastest',
      suggestedAlternatives: alternatives,
    );

    // Cache this verified real road path into the offline road corridor graph
    OfflineRoadCorridors.instance.recordRoadRoute(finalRoute.points, finalRoute.summary);

    return finalRoute;
  }

  /// Parses an individual Google Directions route object with Live Traffic segmentation
  RouteDataModel? _parseGoogleRoute(
    Map<String, dynamic> route,
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
    PolylinePoints polylineDecoder,
  ) {
    final legs = (route['legs'] as List?) ?? [];

    // Extract 100% exact high-definition road coordinates and live traffic segments
    final List<LatLng> points = [];
    final List<RouteTrafficSegment> trafficSegments = [];

    double totalDistanceMeters = 0;
    int totalNormalDurationSeconds = 0;
    int totalTrafficDurationSeconds = 0;
    int legDelaySeconds = 0;
    final List<RouteStepModel> steps = [];

    for (final leg in legs) {
      totalDistanceMeters += (leg['distance']?['value'] as num?)?.toDouble() ?? 0.0;
      final legNormalDur = (leg['duration']?['value'] as num?)?.toInt() ?? 0;
      totalNormalDurationSeconds += legNormalDur;

      int legTrafficDur = legNormalDur;
      if (leg['duration_in_traffic'] != null) {
        legTrafficDur = (leg['duration_in_traffic']?['value'] as num?)?.toInt() ?? legNormalDur;
      }
      totalTrafficDurationSeconds += legTrafficDur;
      legDelaySeconds += (legTrafficDur - legNormalDur).clamp(0, 7200);

      final rawSteps = (leg['steps'] as List?) ?? [];
      for (final s in rawSteps) {
        final stepPolyString = s['polyline']?['points'] as String?;
        final List<LatLng> stepPoints = [];

        if (stepPolyString != null && stepPolyString.isNotEmpty) {
          final decodedStep = polylineDecoder.decodePolyline(stepPolyString);
          for (final pt in decodedStep) {
            final latLng = LatLng(pt.latitude, pt.longitude);
            stepPoints.add(latLng);
            if (points.isEmpty ||
                (points.last.latitude - latLng.latitude).abs() > 0.000001 ||
                (points.last.longitude - latLng.longitude).abs() > 0.000001) {
              points.add(latLng);
            }
          }
        }

        final cleanInstruction = _cleanHtmlTags(s['html_instructions'] ?? '');
        final distMeters = (s['distance']?['value'] as num?)?.toDouble() ?? 0.0;
        final durSec = (s['duration']?['value'] as num?)?.toInt() ?? 1;
        int stepTrafficDur = durSec;
        if (s['duration_in_traffic'] != null) {
          stepTrafficDur = (s['duration_in_traffic']?['value'] as num?)?.toInt() ?? durSec;
        }

        final int stepDelay = (stepTrafficDur - durSec).clamp(0, 3600);
        final double speedKmh = durSec > 0 ? (distMeters / durSec) * 3.6 : 50.0;
        final double speedRatio = durSec > 0 ? (stepTrafficDur / durSec) : 1.0;

        Color segmentColor = const Color(0xFF10B981); // Emerald Green (Smooth free flow)
        TrafficSeverity severity = TrafficSeverity.low;

        // Realistic live traffic segmentation matching Google Maps & Driver App
        if ((speedRatio >= 1.7 || (speedKmh < 18 && distMeters > 60)) && legDelaySeconds > 120) {
          segmentColor = const Color(0xFFEF4444); // Crimson Red (Heavy traffic bottleneck)
          severity = TrafficSeverity.heavy;
        } else if ((speedRatio >= 1.3 || (speedKmh < 30 && distMeters > 60)) && legDelaySeconds > 60) {
          segmentColor = const Color(0xFFF5AB02); // Amber Yellow (Moderate traffic slowdown)
          severity = TrafficSeverity.moderate;
        }

        if (stepPoints.length >= 2) {
          trafficSegments.add(
            RouteTrafficSegment(
              points: stepPoints,
              color: segmentColor,
              severity: severity,
              delaySeconds: stepDelay,
            ),
          );
        }

        final start = LatLng(
          (s['start_location']?['lat'] as num?)?.toDouble() ?? 0.0,
          (s['start_location']?['lng'] as num?)?.toDouble() ?? 0.0,
        );
        final end = LatLng(
          (s['end_location']?['lat'] as num?)?.toDouble() ?? 0.0,
          (s['end_location']?['lng'] as num?)?.toDouble() ?? 0.0,
        );
        steps.add(RouteStepModel(
          instruction: cleanInstruction,
          distanceMeters: distMeters,
          distanceText: s['distance']?['text'] ?? '${(distMeters / 1000).toStringAsFixed(1)} km',
          durationSeconds: stepTrafficDur,
          durationText: s['duration_in_traffic']?['text'] ?? s['duration']?['text'] ?? '${(stepTrafficDur / 60).round()} mins',
          maneuver: s['maneuver'] ?? _inferManeuver(cleanInstruction),
          startLocation: start,
          endLocation: end,
        ));
      }
    }

    // Fallback to overview_polyline only if steps gave no points
    if (points.isEmpty && route['overview_polyline'] != null) {
      final overviewPoly = route['overview_polyline']['points'] as String;
      final decoded = polylineDecoder.decodePolyline(overviewPoly);
      points.addAll(decoded.map((p) => LatLng(p.latitude, p.longitude)));
    }

    // Professional Paved-Road Adherence:
    // Road polyline remains 100% on the drivable road network without artificial diagonal lines
    // cutting through buildings, compounds, or fences. Markers sit flush on roadOrigin / roadDestination.

    // Fallback single segment if steps gave no segmented traffic
    final int totalTrafficDelay = legDelaySeconds > 0
        ? legDelaySeconds
        : (totalTrafficDurationSeconds - totalNormalDurationSeconds).clamp(0, 14400);

    if (trafficSegments.isEmpty && points.length >= 2) {
      trafficSegments.add(
        RouteTrafficSegment(
          points: points,
          color: const Color(0xFF10B981),
          severity: TrafficSeverity.low,
          delaySeconds: totalTrafficDelay,
        ),
      );
    }

    final distanceKm = totalDistanceMeters / 1000.0;
    final int finalDurationSec = totalTrafficDurationSeconds > 0 ? totalTrafficDurationSeconds : totalNormalDurationSeconds;
    final durationMinutes = (finalDurationSec / 60).round();

    String trafficStatus;
    Color trafficStatusColor;

    if (totalTrafficDelay < 60) {
      trafficStatus = 'Smooth Traffic Flow';
      trafficStatusColor = const Color(0xFF10B981);
    } else if (totalTrafficDelay <= 300) {
      final mins = (totalTrafficDelay / 60).round();
      trafficStatus = 'Low Traffic (+$mins min delay)';
      trafficStatusColor = const Color(0xFFF5AB02);
    } else {
      final mins = (totalTrafficDelay / 60).round();
      trafficStatus = 'Heavy Traffic (+$mins min delay)';
      trafficStatusColor = const Color(0xFFEF4444);
    }

    final rawSummary = route['summary'] as String? ?? '';
    final summary = rawSummary.isNotEmpty ? 'via $rawSummary' : 'Direct Route';

    return RouteDataModel(
      points: points,
      distanceKm: distanceKm,
      distanceText: '${distanceKm.toStringAsFixed(1)} km',
      durationMinutes: durationMinutes,
      durationText: _formatDuration(durationMinutes),
      durationInTrafficText: _formatDuration(durationMinutes),
      trafficDelaySeconds: totalTrafficDelay,
      trafficStatus: trafficStatus,
      trafficStatusColor: trafficStatusColor,
      trafficSegments: trafficSegments,
      source: RouteSource.googleDirections,
      summary: summary,
      steps: steps,
      bounds: _calculateBounds(points),
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );
  }

  /// Fetches driving routes from OSRM (Open Source Routing Machine) with Alternatives
  Future<RouteDataModel?> _fetchFromOsrm(
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) async {
    // Note: OSRM expects coordinates as {lng},{lat}
    final sb = StringBuffer('https://router.project-osrm.org/route/v1/driving/');
    sb.write('${origin.longitude},${origin.latitude};');
    for (final w in waypoints) {
      sb.write('${w.longitude},${w.latitude};');
    }
    sb.write('${destination.longitude},${destination.latitude}');
    sb.write('?overview=full&geometries=geojson&steps=true&alternatives=true');

    final response = await http.get(
      Uri.parse(sb.toString()),
      headers: {
        'User-Agent': 'TruckBookingFreightApp/1.0 (Android; Linux; Flutter)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
      return null;
    }

    final List<RouteDataModel> parsedRoutes = [];

    for (final rawRoute in (data['routes'] as List)) {
      try {
        final parsed = _parseOsrmRoute(
          Map<String, dynamic>.from(rawRoute),
          origin,
          destination,
          waypoints,
        );
        if (parsed != null && parsed.points.isNotEmpty) {
          // Strictly verify that alternative route traverses all intermediate stops
          if (waypoints.isEmpty || routeTraversesAllWaypoints(parsed.points, waypoints, thresholdMeters: 1500.0)) {
            parsedRoutes.add(parsed);
          }
        }
      } catch (e) {
        debugPrint('OSRM alternative route parse error: $e');
      }
    }

    if (parsedRoutes.isEmpty) return null;

    // Prioritize by Shortest Road Distance
    parsedRoutes.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final shortest = parsedRoutes.first;
    final List<RouteDataModel> alternatives = [];

    for (int i = 1; i < parsedRoutes.length; i++) {
      final alt = parsedRoutes[i];
      final diffKm = alt.distanceKm - shortest.distanceKm;
      final diffText = diffKm > 0.05
          ? '+${diffKm.toStringAsFixed(1)} km'
          : 'Same distance';
      alternatives.add(alt.copyWith(
        isShortest: false,
        relativeDistanceText: diffText,
      ));
    }

    final finalShortestRoute = shortest.copyWith(
      isShortest: true,
      relativeDistanceText: 'Shortest',
      suggestedAlternatives: alternatives,
    );

    // Cache this verified real road path into offline road corridor graph
    OfflineRoadCorridors.instance.recordRoadRoute(finalShortestRoute.points, finalShortestRoute.summary);

    return finalShortestRoute;
  }

  /// Parses an individual OSRM route object
  RouteDataModel? _parseOsrmRoute(
    Map<String, dynamic> route,
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) {
    final geometry = route['geometry'];
    final rawCoords = (geometry['coordinates'] as List?) ?? [];

    final points = rawCoords.map((c) {
      final lng = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();

    // Professional Paved-Road Adherence: OSRM route points strictly follow genuine street geometry
    final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

    final distanceKm = distanceMeters / 1000.0;
    // For heavy haulage in African/urban settings, apply a 1.25x truck speed factor
    final durationMinutes = ((durationSeconds * 1.25) / 60).round();

    final List<RouteStepModel> steps = [];
    final legs = (route['legs'] as List?) ?? [];
    for (final leg in legs) {
      final legSteps = (leg['steps'] as List?) ?? [];
      for (final s in legSteps) {
        final maneuverObj = s['maneuver'] ?? {};
        final maneuverType = maneuverObj['type'] ?? 'straight';
        final maneuverModifier = maneuverObj['modifier'] ?? '';
        final streetName = (s['name'] as String?)?.trim();
        final nameDisplay = (streetName != null && streetName.isNotEmpty) ? streetName : 'Freight Highway';

        String instruction = 'Continue on $nameDisplay';
        if (maneuverType == 'depart') {
          instruction = 'Depart towards $nameDisplay';
        } else if (maneuverType == 'arrive') {
          instruction = 'Arrive at destination';
        } else if (maneuverType == 'turn') {
          instruction = 'Turn $maneuverModifier onto $nameDisplay';
        } else if (maneuverType == 'roundabout') {
          instruction = 'Enter roundabout and take exit onto $nameDisplay';
        } else if (maneuverType == 'fork') {
          instruction = 'Keep $maneuverModifier at fork onto $nameDisplay';
        }

        final stepDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
        final stepDur = ((s['duration'] as num?)?.toDouble() ?? 0.0).round();

        final stepLocations = (s['geometry']?['coordinates'] as List?) ?? [];
        LatLng startLoc = origin;
        LatLng endLoc = destination;
        if (stepLocations.isNotEmpty) {
          startLoc = LatLng((stepLocations.first[1] as num).toDouble(), (stepLocations.first[0] as num).toDouble());
          endLoc = LatLng((stepLocations.last[1] as num).toDouble(), (stepLocations.last[0] as num).toDouble());
        }

        steps.add(RouteStepModel(
          instruction: instruction,
          distanceMeters: stepDist,
          distanceText: '${(stepDist / 1000).toStringAsFixed(1)} km',
          durationSeconds: stepDur,
          durationText: '${(stepDur / 60).round()} mins',
          maneuver: maneuverType == 'turn' ? 'turn-$maneuverModifier' : maneuverType,
          startLocation: startLoc,
          endLocation: endLoc,
        ));
      }
    }

    return RouteDataModel(
      points: points,
      distanceKm: distanceKm,
      distanceText: '${distanceKm.toStringAsFixed(1)} km',
      durationMinutes: durationMinutes,
      durationText: _formatDuration(durationMinutes),
      source: RouteSource.osrmRoads,
      summary: (legs.isNotEmpty && legs[0]['summary'] != null && legs[0]['summary'].toString().isNotEmpty)
          ? legs[0]['summary'].toString()
          : 'High-Capacity Freight Arterial',
      steps: steps,
      bounds: _calculateBounds(points),
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );
  }

  /// Synthesizes an intelligent offline route snapped to real road corridors and street grids
  RouteDataModel _generateCurvedGeodesicRoute(
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) {
    // 1. First attempt to snap directly to offline learned road corridors
    if (waypoints.isEmpty) {
      final snappedCorridor = OfflineRoadCorridors.instance.snapRouteToOfflineRoads(origin, destination);
      if (snappedCorridor != null && snappedCorridor.length >= 2) {
        double distMeters = 0;
        for (int i = 0; i < snappedCorridor.length - 1; i++) {
          distMeters += Geolocator.distanceBetween(
            snappedCorridor[i].latitude,
            snappedCorridor[i].longitude,
            snappedCorridor[i + 1].latitude,
            snappedCorridor[i + 1].longitude,
          );
        }
        final distanceKm = distMeters / 1000.0;
        final int durationMinutes = ((distanceKm / 42.0) * 60).round().clamp(5, 1440);

        final steps = [
          RouteStepModel(
            instruction: 'Depart from origin via local access road',
            distanceMeters: 400,
            distanceText: '400 m',
            durationSeconds: 90,
            durationText: '1 min',
            maneuver: 'depart',
            startLocation: origin,
            endLocation: snappedCorridor[1],
          ),
          RouteStepModel(
            instruction: 'Follow offline freight corridor pavement',
            distanceMeters: (distMeters - 800).clamp(100.0, double.infinity),
            distanceText: '${(distanceKm - 0.8).clamp(0.1, 9999.0).toStringAsFixed(1)} km',
            durationSeconds: (durationMinutes * 60) - 180,
            durationText: '${durationMinutes - 3} mins',
            maneuver: 'straight',
            startLocation: snappedCorridor[1],
            endLocation: snappedCorridor[snappedCorridor.length - 2],
          ),
          RouteStepModel(
            instruction: 'Arrive at delivery terminal destination',
            distanceMeters: 400,
            distanceText: '400 m',
            durationSeconds: 90,
            durationText: '1 min',
            maneuver: 'arrive',
            startLocation: snappedCorridor[snappedCorridor.length - 2],
            endLocation: destination,
          ),
        ];

        return RouteDataModel(
          points: snappedCorridor,
          distanceKm: distanceKm,
          distanceText: '${distanceKm.toStringAsFixed(1)} km',
          durationMinutes: durationMinutes,
          durationText: _formatDuration(durationMinutes),
          source: RouteSource.offlineSimulated,
          summary: 'Offline Road Corridor (Snapped to Pavement)',
          steps: steps,
          bounds: _calculateBounds(snappedCorridor),
          origin: origin,
          destination: destination,
          waypoints: waypoints,
        );
      }
    }

    // 2. Multi-segment snapping or orthogonal street grid fallback
    final List<LatLng> anchorPoints = [origin, ...waypoints, destination];
    final List<LatLng> routePoints = [];
    double totalDistanceMeters = 0;

    for (int i = 0; i < anchorPoints.length - 1; i++) {
      final start = anchorPoints[i];
      final end = anchorPoints[i + 1];

      // Try snapping this segment to a known road corridor
      final segmentCorridor = OfflineRoadCorridors.instance.snapRouteToOfflineRoads(start, end);
      final List<LatLng> segmentPoints = segmentCorridor ?? OfflineRoadCorridors.instance.generateOrthogonalRoadPath(start, end);

      for (int j = 0; j < segmentPoints.length - 1; j++) {
        totalDistanceMeters += Geolocator.distanceBetween(
          segmentPoints[j].latitude,
          segmentPoints[j].longitude,
          segmentPoints[j + 1].latitude,
          segmentPoints[j + 1].longitude,
        );
      }

      if (routePoints.isNotEmpty && segmentPoints.isNotEmpty) {
        routePoints.addAll(segmentPoints.skip(1));
      } else {
        routePoints.addAll(segmentPoints);
      }
    }

    final double distanceKm = totalDistanceMeters / 1000.0;
    final int durationMinutes = ((distanceKm / 40.0) * 60).round().clamp(5, 1440);

    final List<RouteStepModel> steps = [
      RouteStepModel(
        instruction: 'Depart from Origin Terminal',
        distanceMeters: 500,
        distanceText: '500 m',
        durationSeconds: 120,
        durationText: '2 mins',
        maneuver: 'depart',
        startLocation: origin,
        endLocation: routePoints.length > 3 ? routePoints[3] : destination,
      ),
      RouteStepModel(
        instruction: 'Transit via Freight Arterials (Offline Road Grid)',
        distanceMeters: (totalDistanceMeters - 1000).clamp(100.0, double.infinity),
        distanceText: '${(distanceKm - 1.0).clamp(0.1, 9999.0).toStringAsFixed(1)} km',
        durationSeconds: (durationMinutes * 60) - 240,
        durationText: '${durationMinutes - 4} mins',
        maneuver: 'straight',
        startLocation: routePoints.length > 3 ? routePoints[3] : origin,
        endLocation: routePoints.length > 4 ? routePoints[routePoints.length - 3] : destination,
      ),
      RouteStepModel(
        instruction: 'Approach and Arrive at Delivery Zone',
        distanceMeters: 500,
        distanceText: '500 m',
        durationSeconds: 120,
        durationText: '2 mins',
        maneuver: 'arrive',
        startLocation: routePoints.length > 4 ? routePoints[routePoints.length - 3] : origin,
        endLocation: destination,
      ),
    ];

    return RouteDataModel(
      points: routePoints,
      distanceKm: distanceKm,
      distanceText: '${distanceKm.toStringAsFixed(1)} km',
      durationMinutes: durationMinutes,
      durationText: _formatDuration(durationMinutes),
      source: RouteSource.offlineSimulated,
      summary: 'Offline Street Grid Corridor',
      steps: steps,
      bounds: _calculateBounds(routePoints),
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );
  }

  /// Google Roads API: Snaps raw GPS or tracking coordinates to the nearest road center-line.
  /// Uses interpolate=true to reconstruct smooth, continuous road curvature.
  Future<List<LatLng>> snapPointsToRoads(List<LatLng> rawPoints) async {
    if (rawPoints.isEmpty) return rawPoints;
    final pointsToProcess = rawPoints.length > 100
        ? rawPoints.sublist(0, 100)
        : rawPoints;

    final pathParam = pointsToProcess
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final url = Uri.parse(
      'https://roads.googleapis.com/v1/snapToRoads'
      '?path=$pathParam'
      '&interpolate=true'
      '&key=${APIConstants.googleMapsAPIKey}',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final snappedPoints = (data['snappedPoints'] as List?) ?? [];
        if (snappedPoints.isNotEmpty) {
          final List<LatLng> result = [];
          for (final sp in snappedPoints) {
            final loc = sp['location'];
            if (loc != null) {
              result.add(LatLng(
                (loc['latitude'] as num).toDouble(),
                (loc['longitude'] as num).toDouble(),
              ));
            }
          }
          if (result.isNotEmpty) return result;
        }
      }
    } catch (e) {
      debugPrint('Roads API snap notice: $e');
    }
    return rawPoints;
  }

  /// Saves route to GetStorage
  void _persistRoute(String key, RouteDataModel route) {
    try {
      _storage.write(key, jsonEncode(route.toJson()));
    } catch (e) {
      debugPrint('Could not persist route: $e');
    }
  }

  /// Calculates boundary to smoothly fit all route points in map viewport
  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(5.6037, -0.1870),
        northeast: const LatLng(5.6037, -0.1870),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Add 12% safety margin for comfortable padding
    final latPadding = (maxLat - minLat) * 0.12;
    final lngPadding = (maxLng - minLng) * 0.12;

    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// High-Tech Multi-Layered Neon & Live Traffic Polylines
  /// Stacks: Dark Contrast Casing Border + Real-Time Live Traffic Colored Segments
  /// geodesic: false is strictly enforced so planar road segment lines match vector/raster street geometry
  Set<Polyline> buildMultiLayeredPolylines({
    required String baseId,
    required List<LatLng> points,
    required RouteSource source,
    List<RouteTrafficSegment> trafficSegments = const [],
    Color? primaryColor,
    Color? glowColor,
    double coreWidth = 3.8, // Decreased to 3.8 for sleek, road-exact, professional styling
    int baseZIndex = 10,
  }) {
    if (points.isEmpty) return {};

    final Set<Polyline> polylines = {};

    // Determine colors based on route source or explicit overrides
    Color core = primaryColor ?? const Color(0xFF10B981); // Emerald Green core
    Color casing = const Color(0xFF0F172A); // Ultra-deep slate contrast border

    final int casingWidth = (coreWidth + 2.0).round().clamp(5, 7);
    final int coreLineWidth = coreWidth.round().clamp(3, 5);

    if (source == RouteSource.osrmRoads) {
      core = primaryColor ?? const Color(0xFF00E5FF); // Electric Cyan
    } else if (source == RouteSource.offlineCache) {
      core = primaryColor ?? const Color(0xFF8B5CF6); // Cyber Violet
    } else if (source == RouteSource.offlineSimulated) {
      core = primaryColor ?? const Color(0xFFF59E0B); // Amber / Gold

      // Distinct dashing for direct offline simulation
      polylines.add(
        Polyline(
          polylineId: PolylineId('${baseId}_offline_casing'),
          points: points,
          width: casingWidth,
          color: casing,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          zIndex: baseZIndex + 1,
        ),
      );

      polylines.add(
        Polyline(
          polylineId: PolylineId('${baseId}_offline_core'),
          points: points,
          width: coreLineWidth,
          color: core,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: false,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: baseZIndex + 2,
        ),
      );

      return polylines;
    }

    // 1. High-Contrast Dark Casing Border Outline (Underneath)
    polylines.add(
      Polyline(
        polylineId: PolylineId('${baseId}_casing'),
        points: points,
        width: casingWidth,
        color: casing,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: false,
        zIndex: baseZIndex + 1,
      ),
    );

    // 2. Live Google Maps Traffic Segments (or Single Vibrant Core Line)
    if (trafficSegments.isNotEmpty &&
        (source == RouteSource.googleDirections || source == RouteSource.osrmRoads)) {
      for (int i = 0; i < trafficSegments.length; i++) {
        final seg = trafficSegments[i];
        if (seg.points.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('${baseId}_traffic_$i'),
              points: seg.points,
              width: coreLineWidth,
              color: seg.color,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              geodesic: false,
              zIndex: baseZIndex + 2 + i,
            ),
          );
        }
      }
    } else {
      // Vibrant High-Intensity Core Line
      polylines.add(
        Polyline(
          polylineId: PolylineId('${baseId}_core'),
          points: points,
          width: coreLineWidth,
          color: core,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          zIndex: baseZIndex + 2,
        ),
      );
    }

    return polylines;
  }

  /// Builds clean, subtle dashed access connector lines for off-road facilities / compounds (Uber style)
  Set<Polyline> buildAccessConnectors({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> roadPoints,
    Color pickupColor = const Color(0xFF10B981),
    Color dropoffColor = const Color(0xFFEF4444),
    double width = 2.4,
  }) {
    final Set<Polyline> connectors = {};
    if (roadPoints.isEmpty) return connectors;

    final roadStart = roadPoints.first;
    final roadEnd = roadPoints.last;

    // Only add connector if physical location is distinct from road (> 15m and < 1500m)
    final distOrigin = Geolocator.distanceBetween(
      origin.latitude, origin.longitude,
      roadStart.latitude, roadStart.longitude,
    );
    if (distOrigin > 15.0 && distOrigin < 1500.0) {
      connectors.add(
        Polyline(
          polylineId: const PolylineId('pickup_access_connector'),
          points: [origin, roadStart],
          width: width.round().clamp(2, 3),
          color: pickupColor.withValues(alpha: 0.70),
          patterns: [PatternItem.dash(10), PatternItem.gap(6)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          zIndex: 8,
        ),
      );
    }

    final distDest = Geolocator.distanceBetween(
      destination.latitude, destination.longitude,
      roadEnd.latitude, roadEnd.longitude,
    );
    if (distDest > 15.0 && distDest < 1500.0) {
      connectors.add(
        Polyline(
          polylineId: const PolylineId('dropoff_access_connector'),
          points: [roadEnd, destination],
          width: width.round().clamp(2, 3),
          color: dropoffColor.withValues(alpha: 0.70),
          patterns: [PatternItem.dash(10), PatternItem.gap(6)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          zIndex: 8,
        ),
      );
    }

    return connectors;
  }

  /// High-Definition Multi-Route Polylines with Interactive Alternatives
  /// - Non-selected alternative routes are drawn with a sleek muted slate casing and core,
  ///   with `consumeTapEvents: true` and `onTap: () => onSelectRoute(i)` so the user can tap them
  ///   directly on the map to switch to that route!
  /// - The selected active route (default: shortest route) is rendered on top (zIndex 20+)
  ///   with full live traffic coloring and deep contrast casing.
  Set<Polyline> buildMultiRoutePolylines({
    required List<RouteDataModel> routes,
    required int selectedIndex,
    required void Function(int index) onSelectRoute,
    double coreWidth = 3.8,
  }) {
    final Set<Polyline> polylines = {};
    if (routes.isEmpty) return polylines;

    final safeIndex = selectedIndex.clamp(0, routes.length - 1);

    // 1. Render all unselected alternative routes in the background
    for (int i = 0; i < routes.length; i++) {
      if (i == safeIndex) continue;
      final alt = routes[i];
      if (alt.points.isEmpty) continue;

      final int casingWidth = (coreWidth + 2.0).round().clamp(5, 7);
      final int coreLineWidth = coreWidth.round().clamp(3, 5);

      // Alternative route casing
      polylines.add(
        Polyline(
          polylineId: PolylineId('route_alt_${i}_casing'),
          points: alt.points,
          width: casingWidth,
          color: const Color(0x770F172A),
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          zIndex: 8,
          consumeTapEvents: true,
          onTap: () => onSelectRoute(i),
        ),
      );

      // Alternative route core line (Muted slate with tap detection)
      polylines.add(
        Polyline(
          polylineId: PolylineId('route_alt_${i}_core'),
          points: alt.points,
          width: coreLineWidth,
          color: const Color(0xFF64748B).withValues(alpha: 0.75),
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          zIndex: 9,
          consumeTapEvents: true,
          onTap: () => onSelectRoute(i),
        ),
      );
    }

    // 2. Render the active selected route on top with full live traffic / primary styling
    final activeRoute = routes[safeIndex];
    final activePolylines = buildMultiLayeredPolylines(
      baseId: 'route_active_$safeIndex',
      points: activeRoute.points,
      source: activeRoute.source,
      trafficSegments: activeRoute.trafficSegments,
      coreWidth: coreWidth,
      baseZIndex: 20,
    );
    polylines.addAll(activePolylines);

    return polylines;
  }

  /// Formats duration string
  static String _formatDuration(int totalMinutes) {
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '$totalMinutes mins';
  }

  /// Removes HTML tags from instruction strings
  static String _cleanHtmlTags(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Infers maneuver type from instruction text
  static String _inferManeuver(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('left')) return 'turn-left';
    if (lower.contains('right')) return 'turn-right';
    if (lower.contains('roundabout')) return 'roundabout';
    if (lower.contains('merge')) return 'merge';
    if (lower.contains('destination') || lower.contains('arrive')) return 'arrive';
    if (lower.contains('depart') || lower.contains('head')) return 'depart';
    if (lower.contains('u-turn')) return 'u-turn';
    return 'straight';
  }
}
