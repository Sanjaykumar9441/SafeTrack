import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/route_model.dart';
import 'bus_detail_screen.dart';

class SearchResultsScreen extends StatelessWidget {
  final List<BusRoute> routes;
  final String from;
  final String to;

  const SearchResultsScreen({
    super.key,
    required this.routes,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Results'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.trip_origin,
                    color: AppTheme.safeColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    from,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward,
                      size: 16, color: AppTheme.textLight),
                ),
                const Icon(Icons.location_on,
                    color: AppTheme.dangerColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    to,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${routes.length} bus${routes.length == 1 ? '' : 'es'} found',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          Expanded(
            child: routes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_bus_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No buses found for this route',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$from → $to',
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BusDetailScreen(busId: route.busId),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Bus number + service
                                      Row(
                                        children: [
                                          Text(
                                            route.busNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (route.serviceNumber != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                route.serviceNumber!,
                                                style: const TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),

                                      // Bus name
                                      Text(
                                        route.busName,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Route path
                                      Row(
                                        children: [
                                          const Icon(Icons.trip_origin,
                                              size: 10,
                                              color: AppTheme.safeColor),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${route.source} → ${route.destination}',
                                              style: const TextStyle(
                                                color: AppTheme.textLight,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Timings
                                      if (route.departureTime != null ||
                                          route.arrivalTime != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule,
                                                size: 10,
                                                color: AppTheme.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              [
                                                if (route.departureTime != null)
                                                  'Dep: ${route.departureTime}',
                                                if (route.arrivalTime != null)
                                                  'Arr: ${route.arrivalTime}',
                                              ].join('  •  '),
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: AppTheme.textLight,
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
}
