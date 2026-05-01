import 'package:latlong2/latlong.dart';
import 'waypoint.dart';

/// Navigation route model containing a list of waypoints
class NavRoute {
  final String? id;
  final String name;
  final String? description;
  final List<Waypoint> waypoints;
  final DateTime createdAt;
  final DateTime? updatedAt;

  NavRoute({
    this.id,
    required this.name,
    this.description,
    List<Waypoint>? waypoints,
    DateTime? createdAt,
    this.updatedAt,
  })  : waypoints = waypoints ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isEmpty => waypoints.isEmpty;
  bool get isNotEmpty => waypoints.isNotEmpty;
  int get waypointCount => waypoints.length;

  /// Get center point of the route
  LatLng? get center {
    if (waypoints.isEmpty) return null;

    double sumLat = 0, sumLng = 0;
    for (final wp in waypoints) {
      sumLat += wp.position.latitude;
      sumLng += wp.position.longitude;
    }
    return LatLng(sumLat / waypoints.length, sumLng / waypoints.length);
  }

  /// Get total distance in meters (approximate)
  double get totalDistance {
    if (waypoints.length < 2) return 0;

    const distance = Distance();
    double total = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += distance.as(
        LengthUnit.Meter,
        waypoints[i].position,
        waypoints[i + 1].position,
      );
    }
    return total;
  }

  NavRoute copyWith({
    String? id,
    String? name,
    String? description,
    List<Waypoint>? waypoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NavRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      waypoints: waypoints ?? this.waypoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Add a waypoint to the route
  NavRoute addWaypoint(Waypoint waypoint) {
    final newWaypoints = List<Waypoint>.from(waypoints);
    newWaypoints.add(waypoint.copyWith(order: newWaypoints.length));
    return copyWith(
      waypoints: newWaypoints,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a waypoint by index
  NavRoute removeWaypoint(int index) {
    if (index < 0 || index >= waypoints.length) return this;

    final newWaypoints = List<Waypoint>.from(waypoints);
    newWaypoints.removeAt(index);
    // Re-order remaining waypoints
    for (int i = 0; i < newWaypoints.length; i++) {
      newWaypoints[i] = newWaypoints[i].copyWith(order: i);
    }
    return copyWith(
      waypoints: newWaypoints,
      updatedAt: DateTime.now(),
    );
  }

  /// Clear all waypoints
  NavRoute clear() => copyWith(waypoints: [], updatedAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory NavRoute.fromJson(Map<String, dynamic> json) => NavRoute(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        waypoints: (json['waypoints'] as List?)
                ?.map((w) => Waypoint.fromJson(w as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );

  @override
  String toString() => 'NavRoute(name: $name, waypoints: $waypointCount)';
}