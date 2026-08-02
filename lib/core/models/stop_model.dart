import 'package:cloud_firestore/cloud_firestore.dart';

/// One physical bus stop or terminal. Matches the `stops` collection
/// documented in Chapter 4.2.4 of the report.
class StopModel {
  final String id;
  final String name;
  final String area;
  final double latitude;
  final double longitude;
  final bool isActive;

  const StopModel({
    required this.id,
    required this.name,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  /// Builds a StopModel from a Firestore document snapshot.
  factory StopModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Stop document ${doc.id} has no data.');
    }

    return StopModel(
      id: doc.id,
      name: data['name'] as String,
      area: data['area'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      isActive: data['isActive'] as bool,
    );
  }

  /// Converts this stop into a Map ready to write to Firestore.
  /// Does not include `id` — Firestore assigns that separately.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
    };
  }
}
