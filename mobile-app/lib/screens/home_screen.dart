import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/feature_card.dart';
import '../widgets/live_stats_card.dart';
import 'bus_detail_screen.dart';
import 'search_results_screen.dart';
import 'nearby_stops_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controllers
  final _vehicleNumberController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _serviceNumberController = TextEditingController();

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _serviceNumberController.dispose();
    super.dispose();
  }


  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }


  void _trackByVehicleNumber() async {
    final number = _vehicleNumberController.text.trim();
    if (number.isEmpty) {
      _showSnackBar('Please enter a vehicle number');
      return;
    }

    Navigator.pop(context); // close bottom sheet
    _showLoading();

    try {
      final bus = await ApiService.getBusByNumber(number);
      if (!mounted) return;

      Navigator.of(context).pop(); // close loading
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BusDetailScreen(busId: bus.id)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Bus not found. Please check the number.');
    }
  }

  void _searchRoutes() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) {
      _showSnackBar('Please enter both source and destination');
      return;
    }

    Navigator.pop(context);
    _showLoading();

    try {
      final routes = await ApiService.searchRoutes(from, to);
      if (!mounted) return;

      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SearchResultsScreen(routes: routes, from: from, to: to),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('No routes found for this search');
    }
  }

  void _trackByServiceNumber() async {
    final number = _serviceNumberController.text.trim();
    if (number.isEmpty) {
      _showSnackBar('Please enter a service number');
      return;
    }

    Navigator.pop(context);
    _showLoading();

    try {
      final route = await ApiService.getRouteByServiceNumber(number);
      if (!mounted) return;

      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BusDetailScreen(busId: route.busId)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Service number not found');
    }
  }


  void _openTrackVehicleSheet() {
    _vehicleNumberController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
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
            const Text(
              'Track by Vehicle Number',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter the bus registration number',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _vehicleNumberController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _trackByVehicleNumber(),
              decoration: const InputDecoration(
                hintText: 'e.g. KA-01-AB-1234',
                prefixIcon: Icon(Icons.directions_bus_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _trackByVehicleNumber,
                icon: const Icon(Icons.gps_fixed, size: 18),
                label: const Text('Track Bus'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNearbyStopsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
            const Text(
              'Find Nearby Bus Stops',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'We\'ll use your current location to find stops near you',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NearbyStopsScreen()),
                  );
                },
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Use My Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openSearchRoutesSheet() {
    _fromController.clear();
    _toController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
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
            const Text(
              'Search Routes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Find buses between two locations',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _fromController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'From (Source)',
                prefixIcon: Icon(Icons.trip_origin, color: Colors.green),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchRoutes(),
              decoration: const InputDecoration(
                hintText: 'To (Destination)',
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _searchRoutes,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search Buses'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTrackServiceSheet() {
    _serviceNumberController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
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
            const Text(
              'Track by Service Number',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter the route service number',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _serviceNumberController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _trackByServiceNumber(),
              decoration: const InputDecoration(
                hintText: 'e.g. R-101',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _trackByServiceNumber,
                icon: const Icon(Icons.gps_fixed, size: 18),
                label: const Text('Track'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SvgPicture.asset(
                              'assets/images/logo.svg',
                              width: 36,
                              height: 36,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SafeTrack',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Smart Bus Tracking & Safety System',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Live stats
                      StreamBuilder<Map<String, dynamic>>(
                        stream: ApiService.statsStream(),
                        builder: (context, snapshot) {
                          final stats = snapshot.data ??
                              {'activeBuses': 0, 'unresolvedAlerts': 0};
                          final isBusy = snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData;
                          final busCount = stats['activeBuses'] ?? 0;
                          final alerts = stats['unresolvedAlerts'] ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: LiveStatsCard(
                                  icon: Icons.directions_bus,
                                  label: 'Active Buses',
                                  value: isBusy ? '...' : '$busCount',
                                  color: AppTheme.safeColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LiveStatsCard(
                                  icon: Icons.warning_amber_rounded,
                                  label: 'Alerts',
                                  value: isBusy ? '...' : '$alerts',
                                  color: alerts > 0
                                      ? AppTheme.dangerColor
                                      : AppTheme.safeColor,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2×2 grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          FeatureCard(
                            icon: Icons.search,
                            title: 'Track by Vehicle',
                            subtitle: 'Enter bus registration no.',
                            color: const Color(0xFF3B82F6),
                            onTap: _openTrackVehicleSheet,
                          ),
                          FeatureCard(
                            icon: Icons.location_on,
                            title: 'Nearby Stops',
                            subtitle: 'Find stops near you',
                            color: const Color(0xFF10B981),
                            onTap: _openNearbyStopsSheet,
                          ),
                          FeatureCard(
                            icon: Icons.route,
                            title: 'Search Routes',
                            subtitle: 'Source to destination',
                            color: const Color(0xFF8B5CF6),
                            onTap: _openSearchRoutesSheet,
                          ),
                          FeatureCard(
                            icon: Icons.confirmation_number,
                            title: 'Track by Service',
                            subtitle: 'Enter service number',
                            color: const Color(0xFFF59E0B),
                            onTap: _openTrackServiceSheet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
