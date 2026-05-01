import 'dart:typed_data';

/// Waypoint model representing a single navigation point (for protocol encoding)
class GpsWaypoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final String? name;

  const GpsWaypoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.name,
  });

  /// Convert lat/lon to int32 representation (semicircles)
  /// Garmin uses semicircles where 2^31 = 180 degrees
  int get latitudeSemicircles => (latitude / 180.0 * 2147483648).round();
  int get longitudeSemicircles => (longitude / 180.0 * 2147483648).round();
  int get altitudeCm => ((altitude ?? 0) * 100).round();

  @override
  String toString() =>
      'GpsWaypoint(lat: $latitude, lon: $longitude, alt: $altitude, name: $name)';
}

/// Navigation route containing multiple waypoints (for protocol encoding)
class GpsRoute {
  final String name;
  final List<GpsWaypoint> waypoints;
  final DateTime createdAt;

  GpsRoute({
    required this.name,
    required this.waypoints,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isEmpty => waypoints.isEmpty;
  int get waypointCount => waypoints.length;

  @override
  String toString() =>
      'GpsRoute(name: $name, waypoints: $waypointCount)';
}

/// Garmin FIT protocol encoder for route data
/// Based on FIT SDK specification
class GarminProtocol {
  // FIT file types
  static const int _fitFileTypeCourse = 4;

  // FIT architecture: little-endian
  static const int _fitArchLittle = 0;

  // FIT base types
  static const int _fitBaseTypeEnum = 0;
  static const int _fitBaseTypeUint16 = 132;
  static const int _fitBaseTypeSint32 = 133;
  static const int _fitBaseTypeUint32 = 134;
  static const int _fitBaseTypeUint32z = 134;
  static const int _fitBaseTypeByte = 13;

  /// Encode a GpsRoute to FIT binary format
  static Uint8List encodeRoute(GpsRoute route) {
    final bytes = <int>[];

    // 1. File header (14 bytes)
    bytes.addAll(_encodeFileHeader(route));

    // 2. File ID message
    bytes.addAll(_encodeFileIdMessage(route));

    // 3. Course message
    bytes.addAll(_encodeCourseMessage(route));

    // 4. Record messages (track points)
    for (int i = 0; i < route.waypoints.length; i++) {
      bytes.addAll(_encodeRecordMessage(route.waypoints[i], i + 1));
    }

    // 5. Course point messages (navigation points)
    for (int i = 0; i < route.waypoints.length; i++) {
      final wp = route.waypoints[i];
      final pointType = _getCoursePointType(i, route.waypoints.length);
      bytes.addAll(_encodeCoursePointMessage(wp, i + 1, pointType));
    }

    // 6. Data CRC (2 bytes)
    final dataBytes = Uint8List.fromList(bytes);
    bytes.addAll(_calculateCRC(dataBytes));

    // 7. File CRC (2 bytes) - optional, placeholder
    bytes.addAll([0x00, 0x00]);

    return Uint8List.fromList(bytes);
  }

  static List<int> _encodeFileHeader(GpsRoute route) {
    const headerSize = 14;
    final dataSize = _calculateDataSize(route);

    return [
      headerSize,
      0x10,                 // protocol version 2.0
      0x06, 0x00,          // profile minor version
      dataSize & 0xFF,
      (dataSize >> 8) & 0xFF,
      (dataSize >> 16) & 0xFF,
      (dataSize >> 24) & 0xFF,
      0x2E, 0x46, 0x49, 0x54, // ".FIT"
      0x00, 0x00,           // header CRC placeholder
    ];
  }

  static int _calculateDataSize(GpsRoute route) {
    int size = 3 + 3 + (route.waypoints.length * 16) + (route.waypoints.length * 25) + 2;
    return size;
  }

  static List<int> _encodeFileIdMessage(GpsRoute route) {
    final msg = <int>[];
    // Definition message header (0x40 = local message def)
    msg.add(0x40);
    msg.add(0x00); // local message type 0

    // Field definitions for file_id
    msg.addAll([0x00, 0x01, _fitBaseTypeEnum]); // type
    msg.addAll([0x01, 0x02, _fitBaseTypeUint16]); // manufacturer
    msg.addAll([0x02, 0x02, _fitBaseTypeUint16]); // product
    msg.addAll([0x03, 0x04, _fitBaseTypeUint32z]); // serial
    msg.addAll([0x04, 0x04, _fitBaseTypeUint32]); // time_created
    msg.add(0x00); // end of field defs

    // Data message header (0x00 = definition message 0)
    msg.add(0x00);

    // Data: type=course (4), manufacturer=Garmin (1), product=0, serial=0, time=0
    msg.addAll([_fitFileTypeCourse, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

    return msg;
  }

  static List<int> _encodeCourseMessage(GpsRoute route) {
    final msg = <int>[];
    // Definition for course message
    msg.add(0x41); // 0x40 | local_msg_type(1)
    msg.add(0x01); // local message type 1

    // sport (enum, 1 byte), name (string, variable)
    msg.addAll([0x00, 0x01, _fitBaseTypeEnum]); // sport
    msg.addAll([0x01, 0x02, _fitBaseTypeUint16]); // sub-sport
    msg.add(0x09); // name field
    msg.add(0x84); // string, 1 byte
    msg.add(0x00);

    // Data
    msg.add(0x02); // sport = running
    msg.addAll([0x00, 0x00]); // sub-sport
    // name: "Route\0"
    msg.addAll([0x52, 0x6F, 0x75, 0x74, 0x65, 0x00]); // "Route\0"

    return msg;
  }

  static List<int> _encodeRecordMessage(GpsWaypoint wp, int index) {
    final msg = <int>[];
    // Definition
    msg.add(0x42); // 0x40 | local_msg_type(2)
    msg.add(0x02); // local message type 2

    // position_lat (sint32), position_long (sint32), altitude (uint16), time (uint32)
    msg.addAll([0x00, 0x04, _fitBaseTypeSint32]); // lat
    msg.addAll([0x01, 0x04, _fitBaseTypeSint32]); // long
    msg.addAll([0x02, 0x02, _fitBaseTypeUint16]); // altitude
    msg.addAll([0xFD, 0x04, _fitBaseTypeUint32]); // timestamp
    msg.add(0x00);

    // Data
    final latBytes = _int32ToLE(wp.latitudeSemicircles);
    final lonBytes = _int32ToLE(wp.longitudeSemicircles);
    final altBytes = _uint16ToLE((wp.altitude ?? 0) ~/ 0.2);
    final timeBytes = _uint32ToLE(index * 60); // 60 seconds per waypoint

    msg.addAll(latBytes);
    msg.addAll(lonBytes);
    msg.addAll(altBytes);
    msg.addAll(timeBytes);

    return msg;
  }

  static List<int> _encodeCoursePointMessage(GpsWaypoint wp, int index, int pointType) {
    final msg = <int>[];
    // Definition
    msg.add(0x43); // 0x40 | local_msg_type(3)
    msg.add(0x03); // local message type 3

    // timestamp, position_lat, position_long, distance, type, name
    msg.addAll([0xFD, 0x04, _fitBaseTypeUint32]); // timestamp
    msg.addAll([0x00, 0x04, _fitBaseTypeSint32]); // lat
    msg.addAll([0x01, 0x04, _fitBaseTypeSint32]); // long
    msg.addAll([0x02, 0x04, _fitBaseTypeUint32]); // distance
    msg.addAll([0x03, 0x01, _fitBaseTypeEnum]); // type
    msg.add(0x06); // name field
    msg.add(0x84); // string, 1 byte
    msg.add(0x00);

    // Data
    final timestamp = _uint32ToLE(index * 60);
    final latBytes = _int32ToLE(wp.latitudeSemicircles);
    final lonBytes = _int32ToLE(wp.longitudeSemicircles);
    final distBytes = _uint32ToLE(index * 100); // 100m between points
    final typeByte = [pointType];

    msg.addAll(timestamp);
    msg.addAll(latBytes);
    msg.addAll(lonBytes);
    msg.addAll(distBytes);
    msg.addAll(typeByte);

    // Name: "WP$index\0"
    final name = 'WP$index';
    for (int i = 0; i < name.length + 1 && i < 5; i++) {
      msg.add(i < name.length ? name.codeUnitAt(i) : 0);
    }

    return msg;
  }

  static int _getCoursePointType(int index, int total) {
    if (index == 0) return 7; // generic start
    if (index == total - 1) return 12; // finish
    if (index % 5 == 0) return 8; // straight
    return 0; // generic
  }

  static List<int> _int32ToLE(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  static List<int> _uint16ToLE(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }

  static List<int> _uint32ToLE(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  static List<int> _calculateCRC(Uint8List data) {
    const polynomial = 0x1021;
    int crc = 0;

    for (final byte in data) {
      crc ^= byte << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ polynomial;
        } else {
          crc = crc << 1;
        }
        crc &= 0xFFFF;
      }
    }

    return [crc & 0xFF, (crc >> 8) & 0xFF];
  }
}