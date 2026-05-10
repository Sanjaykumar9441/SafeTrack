import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_service.dart';
import 'ai_safety_chat_screen.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import 'live_tracking_screen.dart';

class BusDetailScreen extends StatefulWidget {
  final String busId;
  const BusDetailScreen({super.key, required this.busId});

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  Map<String, dynamic>? busDetail;
  bool loading = true;
  String error = '';

  // AI Prediction
  PredictiveResult? _aiPrediction;
  bool _loadingPrediction = false;

  // Favorite
  bool _isFavorite = false;

  // Map
  GoogleMapController? _mapController;
  LatLng? _busPosition;
  int _currentStopIndex = -1;
  int? _liveAvailableSeats;
  int _occupiedSeats = 0;
  String _seatStatus = 'EMPTY';
  final GlobalKey _mapRepaintKey = GlobalKey();

  // Live data stream
  Stream<Map<String, dynamic>?>? _liveStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBusDetail();
    });
    _loadFavorite();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Widget _buildAiPredictionBanner() {
    if (_loadingPrediction && _aiPrediction == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('AI analyzing sensor data...',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_aiPrediction == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiSafetyChatScreen(busContext: busDetail),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _aiPrediction!.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: _aiPrediction!.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: _aiPrediction!.color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AI Risk: ${_aiPrediction!.riskLevel}',
                        style: TextStyle(
                          color: _aiPrediction!.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text('Ask AI →',
                          style: TextStyle(
                              color: _aiPrediction!.color, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _aiPrediction!.prediction,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  Text(
                    '⚡ ${_aiPrediction!.action}',
                    style: TextStyle(fontSize: 11, color: _aiPrediction!.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorite_buses') ?? [];
    if (mounted) setState(() => _isFavorite = favs.contains(widget.busId));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorite_buses') ?? [];
    if (_isFavorite) {
      favs.remove(widget.busId);
    } else {
      favs.add(widget.busId);
    }
    await prefs.setStringList('favorite_buses', favs);
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _loadAiPrediction(Map<String, dynamic> liveData) async {
    if (_loadingPrediction) return;
    setState(() => _loadingPrediction = true);
    final result = await AiService.predictRisk(
      temperature: _toDouble(liveData['temperature']),
      flameDetected: liveData['flameDetected'] == true,
      smokeDetected: liveData['smokeDetected'] == true ||
          {'DANGER', 'UNSAFE'}
              .contains(liveData['smoke']?.toString().toUpperCase()),
      tiltAngle: _parseTiltAngle(liveData['tiltAngle']),
      speed: _toDouble(liveData['speed']),
      busNumber: busDetail?['busNumber'] ?? '',
    );
    if (mounted) {
      setState(() {
        _aiPrediction = result;
        _loadingPrediction = false;
      });
    }
  }

  double _parseTiltAngle(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final text = value.toString().toUpperCase();
    if (text == 'SAFE') return 0.0;
    if (text == 'UNSAFE' || text == 'DANGER') return 45.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> _loadBusDetail() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final data = await ApiService.getBusDetail(widget.busId);
      if (mounted) {
        final deviceId = data['deviceId'] as String?;

        setState(() {
          busDetail = data;
          loading = false;

          // Default position
          _busPosition = const LatLng(16.98, 82.23);

          // Start stream immediately
          _liveStream = (deviceId != null && deviceId.isNotEmpty)
              ? ApiService.liveDataStream(deviceId)
              : ApiService.liveDataStreamByBusId(widget.busId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load bus details';
          loading = false;
        });
      }
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double _distance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dx = lat1 - lat2;
    final dy = lon1 - lon2;

    return (dx * dx) + (dy * dy);
  }

  void _detectCurrentStop() {
    if (busDetail == null || _busPosition == null) {
      return;
    }

    final stops = busDetail!['intermediateStops'] as List<dynamic>;

    double minDistance = double.infinity;

    int nearestIndex = -1;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];

      final lat = (stop['latitude'] ?? 0).toDouble();

      final lng = (stop['longitude'] ?? 0).toDouble();

      final dist = _distance(
        _busPosition!.latitude,
        _busPosition!.longitude,
        lat,
        lng,
      );

      if (dist < minDistance) {
        minDistance = dist;

        nearestIndex = i;
      }
    }

    if (mounted) {
      setState(() {
        _currentStopIndex = nearestIndex;
      });
    }
  }

  String _buildSharePayload() {
    final busNumber = busDetail?['busNumber'] ?? '';
    final busName = busDetail?['busName'] ?? '';
    final service = busDetail?['serviceNumber'] ?? 'N/A';
    final from = busDetail?['source'] ?? '';
    final to = busDetail?['destination'] ?? '';
    final status = busDetail?['status'] ?? '';
    final safety = busDetail?['safetyStatus'] ?? '';
    final avail = busDetail?['availableSeats'] ?? 0;
    final total = busDetail?['seatCapacity'] ?? 0;

    return '''🚌 SafeTrack — Bus Update
Bus: $busName ($busNumber)
Route: $service | $from → $to
Status: $status • $safety
Seats: $avail available of $total
Helpline: ${busDetail?['helpline']?.isNotEmpty == true ? busDetail!['helpline'] : '1800-XXX-XXXX'}''';
  }

  void _openShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Share Bus Info',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _buildSharePayload(),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            _shareOption(
              icon: Icons.screenshot_monitor,
              label: 'Take Screenshot',
              onTap: () async {
                Navigator.pop(ctx);
                await _shareScreenshot();
              },
            ),
            _shareOption(
              icon: Icons.sms_outlined,
              label: 'Send via SMS',
              onTap: () async {
                Navigator.pop(ctx);
                final encoded = Uri.encodeComponent(_buildSharePayload());
                final uri = Uri.parse('sms:?body=$encoded');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            _shareOption(
              icon: Icons.chat_outlined,
              label: 'Send via WhatsApp',
              onTap: () async {
                Navigator.pop(ctx);
                final encoded = Uri.encodeComponent(_buildSharePayload());
                final uri = Uri.parse('https://wa.me/?text=$encoded');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _shareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }

  Future<void> _shareScreenshot() async {
    try {
      final boundary = _mapRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        await Share.share(_buildSharePayload(), subject: 'Bus Info');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bus_share.png')
        ..writeAsBytesSync(pngBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildSharePayload(),
      );
    } catch (_) {
      await Share.share(_buildSharePayload(), subject: 'Bus Info');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'RUNNING':
        return AppTheme.safeColor;
      case 'MAINTENANCE':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  Color _getSafetyColor(String safety) {
    switch (safety) {
      case 'WARNING':
        return AppTheme.warningColor;
      case 'DANGER':
        return AppTheme.dangerColor;
      default:
        return AppTheme.safeColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(loading
            ? 'Bus Details'
            : (busDetail?['busNumber'] ?? 'Bus Details')),
        actions: [
          if (!loading && busDetail != null)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              tooltip:
                  _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: _toggleFavorite,
            ),
          if (!loading && busDetail != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _openShareSheet,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(error,
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBusDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : busDetail == null
                  ? const Center(child: Text('No data available'))
                  : RepaintBoundary(
                      key: _mapRepaintKey,
                      child: RefreshIndicator(
                        color: AppTheme.primaryColor,
                        onRefresh: () async {
                          await _loadBusDetail();
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.primaryDark,
                                      AppTheme.primaryColor
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_bus,
                                            color: Colors.white, size: 32),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                busDetail!['busNumber'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                busDetail!['busName'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        _buildStatusChip(
                                          busDetail!['status'] ?? 'STOPPED',
                                          _getStatusColor(
                                              busDetail!['status'] ??
                                                  'STOPPED'),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusChip(
                                          busDetail!['safetyStatus'] ?? 'SAFE',
                                          _getSafetyColor(
                                              busDetail!['safetyStatus'] ??
                                                  'SAFE'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoCard(
                                      Icons.event_seat,
                                      'Seats',
                                      '${(busDetail!['seatCapacity'] ?? 0) - _occupiedSeats}/${busDetail!['seatCapacity'] ?? 0}',
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoCard(
                                      Icons.thermostat,
                                      'Temp',
                                      '${busDetail!['temperature'] ?? 0}°C',
                                      (busDetail!['temperature'] ?? 0) > 50
                                          ? AppTheme.dangerColor
                                          : AppTheme.safeColor,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionTitle('Live Location'),
                                  TextButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LiveTrackingScreen(
                                          busId: widget.busId,
                                          busName: busDetail?['busName'] ?? '',
                                          busNumber:
                                              busDetail?['busNumber'] ?? '',
                                          deviceId: busDetail?['deviceId'],
                                          initialLat: _toDouble(
                                              busDetail?['currentLatitude']),
                                          initialLng: _toDouble(
                                              busDetail?['currentLongitude']),
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.fullscreen_rounded,
                                        size: 16),
                                    label: const Text('Full Screen'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildAiPredictionBanner(),
                              if (busDetail!['source'] != null) ...[
                                _buildSectionTitle('Route Information'),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      if (busDetail!['serviceNumber'] != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Service: ${busDetail!['serviceNumber']}',
                                              style: const TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      _buildRouteStop(
                                        busDetail!['source'] ?? '',
                                        busDetail!['departureTime'] ?? '',
                                        isFirst: true,
                                      ),
                                      if (busDetail!['intermediateStops'] !=
                                          null)
                                        ...List.generate(
                                          (busDetail!['intermediateStops']
                                                  as List)
                                              .length,
                                          (i) {
                                            final stop =
                                                busDetail!['intermediateStops']
                                                    [i];
                                            return _buildRouteStop(
                                              stop['name'] ?? '',
                                              stop['arrivalTime'] ?? '',
                                              index: i,
                                            );
                                          },
                                        ),
                                      _buildRouteStop(
                                        busDetail!['destination'] ?? '',
                                        busDetail!['arrivalTime'] ?? '',
                                        isLast: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              _buildSectionTitle('Safety History'),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          busDetail!['totalAlertCount'] == 0
                                              ? Icons.check_circle
                                              : Icons.warning,
                                          color:
                                              busDetail!['totalAlertCount'] == 0
                                                  ? AppTheme.safeColor
                                                  : AppTheme.warningColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          busDetail!['totalAlertCount'] == 0
                                              ? 'No accident history - Safe'
                                              : '${busDetail!['totalAlertCount']} past alert(s) recorded',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color:
                                                busDetail!['totalAlertCount'] ==
                                                        0
                                                    ? AppTheme.safeColor
                                                    : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (busDetail!['recentAlerts'] != null &&
                                        (busDetail!['recentAlerts'] as List)
                                            .isNotEmpty) ...[
                                      const Divider(height: 20),
                                      ...List.generate(
                                        ((busDetail!['recentAlerts'] as List)
                                                    .length >
                                                5)
                                            ? 5
                                            : (busDetail!['recentAlerts']
                                                    as List)
                                                .length,
                                        (i) {
                                          final alert =
                                              busDetail!['recentAlerts'][i];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: alert['severity'] ==
                                                            'CRITICAL'
                                                        ? AppTheme.dangerColor
                                                        : AppTheme.warningColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${alert['alertType']} - ${alert['message']}',
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_busPosition != null) ...[
                                _buildMapCard(),
                                const SizedBox(height: 16),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildMapCard() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _liveStream != null
            ? StreamBuilder<Map<String, dynamic>?>(
                stream: _liveStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    if (snapshot.data!['seatStatus'] != null) {
                      _seatStatus = snapshot.data!['seatStatus'].toString();

                      _occupiedSeats = _seatStatus == 'OCCUPIED' ? 1 : 0;
                    }
                    final lat = _toDouble(snapshot.data!['latitude']);
                    final lng = _toDouble(snapshot.data!['longitude']);

                    // Trigger AI prediction when new live data arrives
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadAiPrediction(snapshot.data!);
                    });

                    // Update map position if coordinates are valid
                    if (lat != 0 && lng != 0) {
                      final newPos = LatLng(lat, lng);
                      if (newPos != _busPosition) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _busPosition = newPos);
                            _detectCurrentStop();
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(newPos),
                            );
                          }
                        });
                      }
                    }
                  }
                  return _googleMap();
                },
              )
            : _googleMap(),
      ),
    );
  }

  Widget _googleMap() {
    final position = _busPosition ?? const LatLng(17.5937, 82.2600);
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(target: position, zoom: 14),
      markers: {
        Marker(
          markerId: const MarkerId('bus'),
          position: position,
          infoWindow: InfoWindow(
            title: busDetail?['busNumber'] ?? 'Bus',
            snippet: busDetail?['busName'] ?? '',
          ),
        ),
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary)),
    );
  }

  Widget _buildRouteStop(
    String name,
    String time, {
    int index = -1,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentStopIndex
                    ? Colors.orange
                    : isFirst
                        ? AppTheme.safeColor
                        : isLast
                            ? AppTheme.dangerColor
                            : AppTheme.primaryColor,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: isFirst || isLast
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (index == _currentStopIndex)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
