import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/theme.dart';
import '../models/route_model.dart';
import '../services/api_service.dart';
import 'bus_detail_screen.dart';

class NearbyStopsScreen extends StatefulWidget {
  const NearbyStopsScreen({super.key});

  @override
  State<NearbyStopsScreen> createState() => _NearbyStopsScreenState();
}

class _NearbyStopsScreenState extends State<NearbyStopsScreen> {
  bool _loading = true;
  String _error = '';
  Position? _userPosition;
  List<_NearbyStop> _nearbyStops = [];

  @override
  void initState() {
    super.initState();
    _load();
  }


  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final position = await _getUserLocation();
      final routes = await ApiService.getAllRoutes();
      final stops = _buildNearbyStops(position, routes);
      if (mounted) {
        setState(() {
          _userPosition = position;
          _nearbyStops = stops;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<Position> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Enable it in app settings.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  List<_NearbyStop> _buildNearbyStops(Position userPos, List<BusRoute> routes) {
    // Collect all unique stops (by name) with their serving routes
    final Map<String, _NearbyStop> stopMap = {};

    for (final route in routes) {
      // Source stop
      if (route.source.isNotEmpty) {
        final key = route.source.toLowerCase().trim();
        stopMap.putIfAbsent(
          key,
          () => _NearbyStop(
            name: route.source,
            latitude: 0,
            longitude: 0,
            routes: [],
          ),
        );
        stopMap[key]!.routes.add(route);
      }

      // Intermediate stops (these have lat/lng)
      for (final stop in route.intermediateStops) {
        if (stop.latitude == 0 && stop.longitude == 0) continue;
        final key = stop.name.toLowerCase().trim();
        stopMap.putIfAbsent(
          key,
          () => _NearbyStop(
            name: stop.name,
            latitude: stop.latitude,
            longitude: stop.longitude,
            routes: [],
          ),
        );
        stopMap[key]!.routes.add(route);
        // Update coords if not set yet
        if (stopMap[key]!.latitude == 0) {
          stopMap[key]!.latitude = stop.latitude;
          stopMap[key]!.longitude = stop.longitude;
        }
      }
    }

    // Calculate distance for stops that have coordinates
    final result = stopMap.values
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .toList();

    for (final stop in result) {
      stop.distanceMeters = _haversineDistance(
        userPos.latitude,
        userPos.longitude,
        stop.latitude,
        stop.longitude,
      );
    }

    result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return result;
  }

  /// Haversine formula — distance in metres between two lat/lng points
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in metres
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Bus Stops'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Finding your location...'),
                ],
              ),
            )
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _nearbyStops.isEmpty
                  ? const Center(
                      child: Text(
                        'No stops with GPS data found nearby.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : Column(
                      children: [
                        // Location info banner
                        if (_userPosition != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.05),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location,
                                    size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Your location found • ${_nearbyStops.length} stops nearby',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Stops list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _nearbyStops.length,
                            itemBuilder: (context, index) {
                              final stop = _nearbyStops[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () => _showStopDetail(context, stop),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        // Stop icon
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.location_on_outlined,
                                            color: AppTheme.primaryColor,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Stop name + routes count
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stop.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${stop.routes.length} bus${stop.routes.length == 1 ? '' : 'es'} serve this stop',
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Distance badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: stop.distanceMeters < 500
                                                ? AppTheme.safeColor
                                                    .withValues(alpha: 0.12)
                                                : Colors.grey
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _formatDistance(
                                                stop.distanceMeters),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: stop.distanceMeters < 500
                                                  ? AppTheme.safeColor
                                                  : AppTheme.textSecondary,
                                            ),
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
                      ],
                    ),
    );
  }


  void _showStopDetail(BuildContext context, _NearbyStop stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stop header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatDistance(stop.distanceMeters) + ' from you',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              const Text(
                'Buses at this stop',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),

              // Bus list
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: stop.routes.length,
                  itemBuilder: (_, i) {
                    final route = stop.routes[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.directions_bus,
                            color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(
                        route.busNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${route.source} → ${route.destination}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BusDetailScreen(busId: route.busId),
                            ),
                          );
                        },
                        child: const Text('Track'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _NearbyStop {
  final String name;
  double latitude;
  double longitude;
  double distanceMeters;
  final List<BusRoute> routes;

  _NearbyStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.routes,
    this.distanceMeters = 0,
  });
}
