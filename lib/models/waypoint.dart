import 'package:latlong2/latlong.dart';

/// Waypoint model for a single navigation point
class Waypoint {
  final String? id;
  final LatLng position;
  final double? altitude;
  final String? name;
  final String? description;
  final int? order;

  const Waypoint({
    this.id,
    required this.position,
    this.altitude,
    this.name,
    this.description,
    this.order,
  });

  Waypoint copyWith({
    String? id,
    LatLng? position,
    double? altitude,
    String? name,
    String? description,
    int? order,
  }) {
    return Waypoint(
      id: id ?? this.id,
      position: position ?? this.position,
      altitude: altitude ?? this.altitude,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': position.latitude,
        'lng': position.longitude,
        'altitude': altitude,
        'name': name,
        'description': description,
        'order': order,
      };

  /// Create from map
  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
        id: json['id'] as String?,
        position: LatLng(json['lat'] as double, json['lng'] as double),
        altitude: json['altitude'] as double?,
        name: json['name'] as String?,
        description: json['description'] as String?,
        order: json['order'] as int?,
      );

  @override
  String toString() => 'Waypoint(name: $name, lat: ${position.latitude}, lon: ${position.longitude})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Waypoint &&
        other.id == id &&
        other.position == position &&
        other.altitude == altitude &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, position, altitude, name);
}