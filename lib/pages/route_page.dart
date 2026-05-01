import 'package:flutter/material.dart';
import '../models/route.dart';

class RoutePage extends StatelessWidget {
  final NavRoute route;

  const RoutePage({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
      ),
      body: route.isEmpty
          ? const Center(child: Text('No waypoints'))
          : ListView.builder(
              itemCount: route.waypoints.length,
              itemBuilder: (context, index) {
                final wp = route.waypoints[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(wp.name ?? 'Waypoint ${index + 1}'),
                  subtitle: Text(
                    '${wp.position.latitude.toStringAsFixed(5)}, '
                    '${wp.position.longitude.toStringAsFixed(5)}',
                  ),
                  trailing: wp.altitude != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Icon(Icons.height, size: 16, color: Colors.grey),
                            Text(
                              '${wp.altitude!.toStringAsFixed(0)}m',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
      bottomNavigationBar: route.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ${route.waypointCount} waypoints'
                      '${route.totalDistance > 0 ? ' • ${(route.totalDistance / 1000).toStringAsFixed(2)} km' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
