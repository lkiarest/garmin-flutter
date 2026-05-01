import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/waypoint.dart';
import '../services/bluetooth_service.dart';
import '../services/garmin_protocol.dart';
import 'route_page.dart';

class MapPage extends StatefulWidget {
  final GarminBleService bluetoothService;

  const MapPage({super.key, required this.bluetoothService});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  // Default to Beijing
  static const _defaultCenter = LatLng(39.9042, 116.4074);
  static const _defaultZoom = 12.0;

  NavRoute _route = NavRoute(name: 'My Route');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map - Tap to Add Waypoint'),
        leading: IconButton(
          icon: const Icon(Icons.bluetooth_disabled),
          onPressed: () {
            widget.bluetoothService.disconnect();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        actions: [
          if (_route.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => _showRoutePreview(),
              tooltip: 'View Route',
            ),
          if (_route.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() => _route = _route.clear()),
              tooltip: 'Clear Route',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              onTap: (tapPos, latlng) => _addWaypoint(latlng),
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.garmin.garmin_flutter',
              ),

              // Route polyline
              if (_route.waypoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route.waypoints.map((w) => w.position).toList(),
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),

              // Waypoint markers
              MarkerLayer(
                markers: _route.waypoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final wp = entry.value;
                  return Marker(
                    point: wp.position,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showWaypointInfo(index),
                      child: _buildWaypointMarker(index + 1),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Info panel at bottom
          if (_route.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Route: ${_route.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_route.waypointCount} waypoints',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      if (_route.totalDistance > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Distance: ${(_route.totalDistance / 1000).toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showRoutePreview(),
                              icon: const Icon(Icons.preview),
                              label: const Text('Preview'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _syncToDevice,
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Center on route button
          if (_route.isNotEmpty && _route.center != null)
            Positioned(
              right: 16,
              top: 16,
              child: FloatingActionButton.small(
                heroTag: 'center',
                onPressed: () {
                  _mapController.move(_route.center!, _defaultZoom);
                },
                child: const Icon(Icons.center_focus_strong),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaypointMarker(int number) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _addWaypoint(LatLng position) {
    final waypoint = Waypoint(
      position: position,
      name: 'WP${_route.waypointCount + 1}',
      order: _route.waypointCount,
    );

    setState(() {
      _route = _route.addWaypoint(waypoint);
    });
  }

  void _showWaypointInfo(int index) {
    final wp = _route.waypoints[index];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wp.name ?? 'Waypoint ${index + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Latitude: ${wp.position.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${wp.position.longitude.toStringAsFixed(6)}'),
            if (wp.altitude != null)
              Text('Altitude: ${wp.altitude!.toStringAsFixed(1)} m'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _route = _route.removeWaypoint(index));
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Remove Waypoint', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoutePreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutePage(route: _route),
      ),
    );
  }

  Future<void> _syncToDevice() async {
    if (_route.isEmpty) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Syncing to device...'),
          ],
        ),
      ),
    );

    try {
      // Convert route to Garmin protocol format
      final garminRoute = GpsRoute(
        name: _route.name,
        waypoints: _route.waypoints
            .map((w) => GpsWaypoint(
                  latitude: w.position.latitude,
                  longitude: w.position.longitude,
                  altitude: w.altitude,
                  name: w.name,
                ))
            .toList(),
      );

      final data = GarminProtocol.encodeRoute(garminRoute);

      // Write to device
      final success = await widget.bluetoothService.writeRouteData(data.toList());

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Route synced successfully! (${data.length} bytes)'
                : 'Sync failed - check device connection'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
