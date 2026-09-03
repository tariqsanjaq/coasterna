import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether a route runs on a fixed timetable or leaves once full.
/// Matches the `departureType` field documented in Ch.4.2.4.
enum DepartureType {
  scheduled,
  whenFull;

  static DepartureType fromFirestore(String value) {
    switch (value) {
      case 'SCHEDULED':
        return DepartureType.scheduled;
      case 'WHEN_FULL':
        return DepartureType.whenFull;
      default:
        throw ArgumentError('Unknown departureType value: $value');
    }
  }

  String toFirestore() {
    switch (this) {
      case DepartureType.scheduled:
        return 'SCHEDULED';
      case DepartureType.whenFull:
        return 'WHEN_FULL';
    }
  }
}

/// Whether this document is the outbound trip (towards AAU) or the
/// return trip (away from AAU). Each direction is a separate document —
/// this is not a toggle on a single shared route.
enum RouteDirection {
  outbound,
  returnTrip;

  static RouteDirection fromFirestore(String value) {
    switch (value) {
      case 'OUTBOUND':
        return RouteDirection.outbound;
      case 'RETURN':
        return RouteDirection.returnTrip;
      default:
        throw ArgumentError('Unknown direction value: $value');
    }
  }

  String toFirestore() {
    switch (this) {
      case RouteDirection.outbound:
        return 'OUTBOUND';
      case RouteDirection.returnTrip:
        return 'RETURN';
    }
  }
}

/// One intermediate stop inside a route's ordered stop list.
/// This is NOT a separate Firestore document — it is a map embedded
/// directly inside the route document's `stops` array.
class RouteStop {
  final String stopId;
  final String stopName;
  final int order;

  const RouteStop({
    required this.stopId,
    required this.stopName,
    required this.order,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopId: json['stopId'] as String,
      stopName: json['stopName'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopId': stopId,
      'stopName': stopName,
      'order': order,
    };
  }
}

/// One point along a route's recorded path. Used only to steer the
/// "Open in Google Maps" link onto the bus's real road (decision D51)
/// — these are sampled mid-road points from a GPX track, never a stop
/// location. See `pathPoints` on [RouteModel] for the full rationale.
class LatLngPoint {
  final double lat;
  final double lng;

  const LatLngPoint(this.lat, this.lng);
}

/// One coaster line, in one direction. Matches the `routes` collection
/// documented in Chapter 4.2.4 of the report.
class RouteModel {
  final String id;
  final String routeName;
  final String operatorName;
  final RouteDirection direction;
  final String originStopId;
  final String originStopName;
  final String destinationStopId;
  final String destinationStopName;
  final double priceJD;
  final int durationMinutes;
  final DepartureType departureType;
  final String firstDeparture;
  final String lastDeparture;
  final int? frequencyMinutes;
  final List<String> operatingDays;
  final List<RouteStop> stops;
  final bool isActive;
  final String collectedBy;
  final DateTime collectedOn;

  /// Points sampled from the route's recorded GPX track, in order,
  /// passed to Google Maps as directions waypoints so the "Open in
  /// Google Maps" link traces the bus's actual road — not a straight
  /// line and not the stops themselves. Stop coordinates were tried
  /// and rejected for this: they sit at the roadside, so Google
  /// detours to reach them (field-measured 21.9 km vs 11.2 km real),
  /// while GPX-sampled mid-road points hold Google to the real path
  /// (field-measured 7.2 km vs 7.32 km real). Null when no track has
  /// been recorded for this route yet — the maps button then falls
  /// back to the single-pin origin link, unchanged from before D51.
  final List<LatLngPoint>? pathPoints;

  const RouteModel({
    required this.id,
    required this.routeName,
    required this.operatorName,
    required this.direction,
    required this.originStopId,
    required this.originStopName,
    required this.destinationStopId,
    required this.destinationStopName,
    required this.priceJD,
    required this.durationMinutes,
    required this.departureType,
    required this.firstDeparture,
    required this.lastDeparture,
    this.frequencyMinutes,
    required this.operatingDays,
    required this.stops,
    required this.isActive,
    required this.collectedBy,
    required this.collectedOn,
    this.pathPoints,
  });

  /// Parses the Firestore `pathPoints` string ("lat,lng;lat,lng;...")
  /// into points. Never throws: missing, empty, or malformed input all
  /// return null so a bad string can never stop a route from loading —
  /// the maps button just falls back to the single-pin link.
  ///
  /// Public (unlike the rest of this class's Firestore plumbing) so
  /// the admin route form can reuse it to parse the path points field
  /// on save, instead of duplicating the "lat,lng;..." grammar.
  static List<LatLngPoint>? parsePathPoints(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final points = raw.split(';').map((pair) {
        final parts = pair.split(',');
        if (parts.length != 2) {
          throw const FormatException('Expected "lat,lng"');
        }
        return LatLngPoint(
          double.parse(parts[0].trim()),
          double.parse(parts[1].trim()),
        );
      }).toList();
      return points.isEmpty ? null : points;
    } catch (_) {
      return null;
    }
  }

  /// Inverse of [parsePathPoints]. Null or empty points serialize to
  /// null so `toFirestore()` writes the field as unset rather than an
  /// empty string. Also reused by the admin route form to pre-fill the
  /// path points field in edit mode.
  static String? pathPointsToFirestore(List<LatLngPoint>? points) {
    if (points == null || points.isEmpty) return null;
    return points.map((p) => '${p.lat},${p.lng}').join(';');
  }

  /// Builds a RouteModel from a Firestore document snapshot.
  /// Call this when reading data that came directly from Firestore
  /// (for example, inside the repository layer's search query).
  factory RouteModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Route document ${doc.id} has no data.');
    }

    final rawStops = data['stops'] as List<dynamic>? ?? [];

    return RouteModel(
      id: doc.id,
      routeName: data['routeName'] as String,
      operatorName: data['operatorName'] as String,
      direction: RouteDirection.fromFirestore(data['direction'] as String),
      originStopId: data['originStopId'] as String,
      originStopName: data['originStopName'] as String,
      destinationStopId: data['destinationStopId'] as String,
      destinationStopName: data['destinationStopName'] as String,
      priceJD: (data['priceJD'] as num).toDouble(),
      durationMinutes: data['durationMinutes'] as int,
      departureType:
          DepartureType.fromFirestore(data['departureType'] as String),
      firstDeparture: data['firstDeparture'] as String,
      lastDeparture: data['lastDeparture'] as String,
      frequencyMinutes: data['frequencyMinutes'] as int?,
      operatingDays: List<String>.from(data['operatingDays'] as List<dynamic>),
      stops: rawStops
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      isActive: data['isActive'] as bool,
      collectedBy: data['collectedBy'] as String,
      collectedOn: (data['collectedOn'] as Timestamp).toDate(),
      pathPoints: parsePathPoints(
        data['pathPoints'] is String ? data['pathPoints'] as String : null,
      ),
    );
  }

  /// Converts this route into a Map ready to write to Firestore.
  /// Does not include `id` (Firestore assigns that) and does not
  /// include `createdAt`/`updatedAt` — the repository layer should
  /// set those with FieldValue.serverTimestamp() at write time,
  /// not here, so the server clock is always the source of truth.
  Map<String, dynamic> toFirestore() {
    return {
      'routeName': routeName,
      'operatorName': operatorName,
      'direction': direction.toFirestore(),
      'originStopId': originStopId,
      'originStopName': originStopName,
      'destinationStopId': destinationStopId,
      'destinationStopName': destinationStopName,
      'priceJD': priceJD,
      'durationMinutes': durationMinutes,
      'departureType': departureType.toFirestore(),
      'firstDeparture': firstDeparture,
      'lastDeparture': lastDeparture,
      'frequencyMinutes': frequencyMinutes,
      'operatingDays': operatingDays,
      'stops': stops.map((s) => s.toJson()).toList(),
      'isActive': isActive,
      'collectedBy': collectedBy,
      'collectedOn': Timestamp.fromDate(collectedOn),
      'pathPoints': pathPointsToFirestore(pathPoints),
    };
  }
}
