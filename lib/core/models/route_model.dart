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
  });

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
    };
  }
}
