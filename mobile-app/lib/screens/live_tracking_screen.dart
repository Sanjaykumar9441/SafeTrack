import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String busId;
  final String busName;
  final String busNumber;
  final String? deviceId;
  final double? initialLat;
  final double? initialLng;

  const LiveTrackingScreen({
    super.key,
    required this.busId,
    required this.busName,
    required this.busNumber,
    this.deviceId,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription? _liveSubscription;

  // Live data state
  LatLng? _busPosition;
  double _speed = 0;
  double _temperature = 0;
  bool _isEmergency = false;
  bool _smokeDetected = false;
  bool _flameDetected = false;
  double _tiltAngle = 0;
  String _lastUpdated = '';
  bool _hasData = false;
  bool _cameraFollowing = true;

  @override
  void initState() {
    super.initState();

    // Set initial position if provided
    if (widget.initialLat != null && widget.initialLng != null) {
      if (widget.initialLat != 0 && widget.initialLng != 0) {
        _busPosition = LatLng(widget.initialLat!, widget.initialLng!);
      }
    }

    _startListening();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Start live stream ─────────────────────────────────────

  void _startListening() {
    Stream<Map<String, dynamic>?> stream;

    // Use deviceId stream if available, fallback to busId stream
    if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
      stream = ApiService.liveDataStream(widget.deviceId!);
    } else {
      stream = ApiService.liveDataStreamByBusId(widget.busId);
    }

    _liveSubscription = stream.listen((data) {
      if (data == null || !mounted) return;
      _updateFromLiveData(data);
    });
  }

  void _updateFromLiveData(Map<String, dynamic> data) {
    final lat = _toDouble(data['lat'] ?? data['latitude']);
    final lng = _toDouble(data['lng'] ?? data['longitude']);

    final newPosition =
        (lat != 0 && lng != 0) ? LatLng(lat, lng) : _busPosition;

    setState(() {
      _hasData = true;
      _busPosition = newPosition;
      _speed = _toDouble(data['speed']);
      _temperature = _toDouble(data['temperature']);
      _isEmergency = data['isEmergency'] == true;
      _smokeDetected = data['smokeDetected'] == true;
      _flameDetected = data['flameDetected'] == true;
      _tiltAngle = _toDouble(data['tiltAngle']);
      _lastUpdated = _formatTimestamp(data['timestamp']);
    });

    // Animate camera to new position
    if (newPosition != null && _cameraFollowing && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Just now';
    }
  }

  // ── Safety helpers ────────────────────────────────────────

  String get _safetyStatus {
    if (_flameDetected || _isEmergency) return 'DANGER';
    if (_smokeDetected || _tiltAngle > 35 || _temperature > 60)
      return 'WARNING';
    return 'SAFE';
  }

  Color get _safetyColor {
    switch (_safetyStatus) {
      case 'DANGER':
        return AppTheme.dangerColor;
      case 'WARNING':
        return AppTheme.warningColor;
      default:
        return AppTheme.safeColor;
    }
  }

  String get _safetyMessage {
    if (_flameDetected) return '🔥 Flame detected — Emergency!';
    if (_isEmergency) return '🚨 Emergency alert active';
    if (_smokeDetected) return '💨 Smoke detected on bus';
    if (_tiltAngle > 35) return '⚠ Unusual tilt detected';
    if (_temperature > 60)
      return '🌡 High temperature: ${_temperature.toStringAsFixed(1)}°C';
    return '';
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final defaultPosition = _busPosition ?? const LatLng(17.5937, 82.2600);

    return Scaffold(
      body: Stack(
        children: [
          // ── Full screen map ──
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_busPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _busPosition!, zoom: 15),
                  ),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: defaultPosition,
              zoom: 15,
            ),
            markers: _busPosition == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('bus'),
                      position: _busPosition!,
                      infoWindow: InfoWindow(
                        title: widget.busNumber,
                        snippet: widget.busName,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        _safetyStatus == 'DANGER'
                            ? BitmapDescriptor.hueRed
                            : _safetyStatus == 'WARNING'
                                ? BitmapDescriptor.hueOrange
                                : BitmapDescriptor.hueAzure,
                      ),
                    ),
                  },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onCameraMove: (_) {
              // User moved camera — stop following
              if (_cameraFollowing) {
                setState(() => _cameraFollowing = false);
              }
            },
          ),

          // ── Top AppBar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Back bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child:
                                const Icon(Icons.arrow_back_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_bus_rounded,
                                    size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.busNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        widget.busName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Live badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.safeColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: AppTheme.safeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.safeColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Safety alert banner
                  if (_safetyStatus != 'SAFE' && _safetyMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _safetyColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _safetyColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          _safetyMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Re-center button ──
          if (!_cameraFollowing)
            Positioned(
              right: 16,
              bottom: 220,
              child: GestureDetector(
                onTap: () {
                  setState(() => _cameraFollowing = true);
                  if (_busPosition != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLng(_busPosition!),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: AppTheme.primaryColor, size: 22),
                ),
              ),
            ),

          // ── Bottom info panel ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_hasData)
                    // Loading state
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Waiting for live data...',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Stats row
                        Row(
                          children: [
                            _statCard(
                              Icons.speed_rounded,
                              '${_speed.toStringAsFixed(1)}',
                              'km/h',
                              AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            _statCard(
                              Icons.thermostat_rounded,
                              '${_temperature.toStringAsFixed(1)}°',
                              'Temp',
                              _temperature > 60
                                  ? AppTheme.dangerColor
                                  : AppTheme.safeColor,
                            ),
                            const SizedBox(width: 10),
                            _statCard(
                              Icons.security_rounded,
                              _safetyStatus,
                              'Safety',
                              _safetyColor,
                              small: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Location row
                        if (_busPosition != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '${_busPosition!.latitude.toStringAsFixed(5)}, '
                                '${_busPosition!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Updated $_lastUpdated',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    IconData icon,
    String value,
    String label,
    Color color, {
    bool small = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: small ? 11 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
