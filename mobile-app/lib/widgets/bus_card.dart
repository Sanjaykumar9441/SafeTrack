import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/bus.dart';
import '../screens/bus_detail_screen.dart';
import '../services/api_service.dart';
import '../screens/live_tracking_screen.dart';

class BusCardWidget extends StatefulWidget {
  final Bus bus;

  const BusCardWidget({
    super.key,
    required this.bus,
  });

  @override
  State<BusCardWidget> createState() => _BusCardWidgetState();
}

class _BusCardWidgetState extends State<BusCardWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _chevronController;
  Map<String, dynamic>? _routeData;
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronController.forward();
      // Load route data the first time we expand
      if (_routeData == null && !_loadingRoute) {
        _loadRoute();
      }
    } else {
      _chevronController.reverse();
    }
  }

  Future<void> _loadRoute() async {
    setState(() => _loadingRoute = true);
    try {
      final detail = await ApiService.getBusDetail(widget.bus.id);
      if (mounted) setState(() => _routeData = detail);
    } catch (e) {
      debugPrint('Route loading error: $e');
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Color _statusColor() {
    switch (widget.bus.status) {
      case 'RUNNING':
        return AppTheme.safeColor;
      case 'MAINTENANCE':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  Color _safetyColor() {
    switch (widget.bus.safetyStatus) {
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
    final isDanger = widget.bus.safetyStatus == 'DANGER';

    return StreamBuilder<Map<String, dynamic>?>(
      stream: ApiService.liveDataStream(widget.bus.deviceId ?? ''),
      builder: (context, snapshot) {
        final liveData = snapshot.data;

        final speed = (liveData?['speed'] ?? 0).toDouble();

        final isMoving = speed > 5;

        final liveStatus = isMoving ? 'RUNNING' : 'STOPPED';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isDanger
                ? const BorderSide(
                    color: AppTheme.dangerColor,
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          child: Column(
            children: [
              if (isDanger)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.dangerColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'EMERGENCY ALERT — This bus has an active alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.vertical(
                  top: isDanger
                      ? Radius.zero
                      : const Radius.circular(
                          16,
                        ),
                  bottom: _expanded
                      ? Radius.zero
                      : const Radius.circular(
                          16,
                        ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.directions_bus_rounded,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bus.busNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              widget.bus.busName,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _chip(
                                  liveStatus,
                                  isMoving ? AppTheme.safeColor : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                _chip(
                                  widget.bus.safetyStatus,
                                  _safetyColor(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      RotationTransition(
                        turns: Tween(
                          begin: 0.0,
                          end: 0.5,
                        ).animate(_chevronController),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: _buildDetailPanel(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingRoute)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_routeData != null &&
                    _routeData!['source'] != null) ...[
                  _detailRow(
                    Icons.trip_origin,
                    Colors.green,
                    'From',
                    _routeData!['source'] ?? '—',
                  ),
                  const SizedBox(height: 6),
                  _detailRow(
                    Icons.location_on,
                    Colors.red,
                    'To',
                    _routeData!['destination'] ?? '—',
                  ),
                  const SizedBox(height: 6),
                  _detailRow(
                    Icons.confirmation_number_outlined,
                    AppTheme.primaryColor,
                    'Service',
                    _routeData!['serviceNumber'] ?? '—',
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _detailRow(
                          Icons.schedule,
                          AppTheme.textSecondary,
                          'Dep',
                          _routeData!['departureTime'] ?? '—',
                        ),
                      ),
                      Expanded(
                        child: _detailRow(
                          Icons.schedule_outlined,
                          AppTheme.textSecondary,
                          'Arr',
                          _routeData!['arrivalTime'] ?? '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.route,
                          size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 6),
                      const Text(
                        'No route assigned',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Seats Available',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      '${widget.bus.availableSeats} / ${widget.bus.seatCapacity}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.bus.seatCapacity > 0
                        ? (widget.bus.seatCapacity -
                                widget.bus.availableSeats) /
                            widget.bus.seatCapacity
                        : 0,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    color: _occupancyColor(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Helpline: ${widget.bus.helpline}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BusDetailScreen(
                                busId: widget.bus.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.info_outline,
                          size: 16,
                        ),
                        label: const Text('Full Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveTrackingScreen(
                                busId: widget.bus.id,
                                busName: widget.bus.busName,
                                busNumber: widget.bus.busNumber,
                                deviceId: widget.bus.deviceId,
                                initialLat: widget.bus.currentLatitude,
                                initialLng: widget.bus.currentLongitude,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.gps_fixed_rounded,
                          size: 16,
                        ),
                        label: const Text('Track Live'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _occupancyColor() {
    if (widget.bus.seatCapacity == 0) return AppTheme.safeColor;
    final pct = (widget.bus.seatCapacity - widget.bus.availableSeats) /
        widget.bus.seatCapacity;
    if (pct >= 0.9) return AppTheme.dangerColor;
    if (pct >= 0.75) return AppTheme.warningColor;
    return AppTheme.safeColor;
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _detailRow(
      IconData icon, Color iconColor, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
