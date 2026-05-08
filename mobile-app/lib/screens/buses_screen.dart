import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../models/bus.dart';
import '../widgets/bus_card.dart';

class BusesScreen extends StatefulWidget {
  const BusesScreen({super.key});

  @override
  State<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends State<BusesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Bus> _applyFilter(List<Bus> buses) {
    if (_searchQuery.isEmpty) return buses;
    final q = _searchQuery.toLowerCase();
    return buses.where((b) {
      return b.busNumber.toLowerCase().contains(q) ||
          b.busName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Buses'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by bus number or name...',
                hintStyle: const TextStyle(color: AppTheme.textLight),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textLight),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Bus>>(
        stream: ApiService.busesStream(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load buses.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          final filtered = _applyFilter(snapshot.data ?? []);

          // Empty
          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No buses found',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              if (mounted) setState(() {});
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return BusCardWidget(bus: filtered[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
