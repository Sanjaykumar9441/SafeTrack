import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus.dart';
import '../models/route_model.dart';

/// Service class handling all Firestore communications.
/// Replaces REST API calls with direct Firestore SDK access.
class ApiService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches all active buses from Firestore.
  static Future<List<Bus>> getAllBuses() async {
    try {
      final snapshot = await _db.collection('buses').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Bus.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load buses: $e');
    }
  }

  /// Returns a real-time stream of all buses.
  static Stream<List<Bus>> busesStream() {
    return _db.collection('buses').snapshots().asyncMap(
      (snapshot) async {
        List<Bus> buses = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;

          // Get route data for this bus
          final routeSnapshot = await _db
              .collection('routes')
              .where('busId', isEqualTo: doc.id)
              .limit(1)
              .get();

          if (routeSnapshot.docs.isNotEmpty) {
            final routeData = routeSnapshot.docs.first.data();

            data['source'] = routeData['source'];

            data['destination'] = routeData['destination'];

            data['intermediateStops'] = routeData['intermediateStops'];
          }

          buses.add(Bus.fromJson(data));
        }

        return buses;
      },
    );
  }

  /// Searches buses by query string (client-side filtering).
  static Future<List<Bus>> searchBuses(String query) async {
    try {
      final allBuses = await getAllBuses();
      final lower = query.toLowerCase();
      return allBuses.where((bus) {
        return bus.busNumber.toLowerCase().contains(lower) ||
            bus.busName.toLowerCase().contains(lower);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search buses: $e');
    }
  }

  /// Gets bus by its vehicle number.
  static Future<Bus> getBusByNumber(String number) async {
    try {
      final snapshot = await _db
          .collection('buses')
          .where('busNumber', isEqualTo: number)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        throw Exception('Bus not found');
      }
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return Bus.fromJson(data);
    } catch (e) {
      throw Exception('Failed to find bus: $e');
    }
  }

  /// Gets detailed bus information including route and alerts.
  static Future<Map<String, dynamic>> getBusDetail(String busId) async {
    try {
      // Get bus document
      final busDoc = await _db.collection('buses').doc(busId).get();
      if (!busDoc.exists) throw Exception('Bus not found');

      final busData = busDoc.data()!;
      busData['id'] = busDoc.id;

      // Get route for this bus
      final routeSnapshot = await _db
          .collection('routes')
          .where('busId', isEqualTo: busId)
          .limit(1)
          .get();

      if (routeSnapshot.docs.isNotEmpty) {
        final routeData = routeSnapshot.docs.first.data();
        busData['source'] = routeData['source'];
        busData['destination'] = routeData['destination'];
        busData['departureTime'] = routeData['departureTime'];
        busData['arrivalTime'] = routeData['arrivalTime'];
        busData['serviceNumber'] = routeData['serviceNumber'];
        busData['intermediateStops'] = routeData['intermediateStops'];
      }

      // Get alerts for this bus
      final alertSnapshot = await _db
          .collection('alerts')
          .where('busId', isEqualTo: busId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      busData['totalAlertCount'] = alertSnapshot.docs.length;
      busData['recentAlerts'] = alertSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Convert Firestore Timestamp to string for display
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] =
              (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();

      return busData;
    } catch (e) {
      throw Exception('Failed to get bus details: $e');
    }
  }

  /// Searches routes from source to destination.
  static Future<List<BusRoute>> searchRoutes(String from, String to) async {
    try {
      // Get all active routes and filter client-side
      // (Firestore doesn't support substring queries natively)
      final snapshot = await _db
          .collection('routes')
          .where('isActive', isEqualTo: true)
          .get();

      final fromLower = from.toLowerCase();
      final toLower = to.toLowerCase();

      final routes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BusRoute.fromJson(data);
      }).where((route) {
        return route.source.toLowerCase().contains(fromLower) &&
            route.destination.toLowerCase().contains(toLower);
      }).toList();
      return routes;
    } catch (e) {
      throw Exception('Failed to search routes: $e');
    }
  }

  /// Gets all active routes.
  static Future<List<BusRoute>> getAllRoutes() async {
    try {
      final snapshot = await _db.collection('routes').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BusRoute.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get routes: $e');
    }
  }

  /// Gets route by service number.
  static Future<BusRoute> getRouteByServiceNumber(String serviceNumber) async {
    try {
      final snapshot = await _db
          .collection('routes')
          .where('serviceNumber', isEqualTo: serviceNumber)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        throw Exception('Route not found');
      }
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return BusRoute.fromJson(data);
    } catch (e) {
      throw Exception('Failed to find route: $e');
    }
  }

  /// Gets dashboard stats (active buses count, alert count).
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final busSnapshot = await _db
          .collection('buses')
          .where('isActive', isEqualTo: true)
          .get();

      final alertSnapshot = await _db
          .collection('alerts')
          .where('isResolved', isEqualTo: false)
          .get();

      return {
        'activeBuses': busSnapshot.docs.length,
        'unresolvedAlerts': alertSnapshot.docs.length,
      };
    } catch (e) {
      return {'activeBuses': 0, 'unresolvedAlerts': 0};
    }
  }

  /// Returns a real-time stream of stats.
  static Stream<Map<String, dynamic>> statsStream() {
    return _db.collection('buses').snapshots().asyncMap((busSnapshot) async {
      final activeBuses =
          busSnapshot.docs.where((d) => d.data()['isActive'] == true).length;

      final alertSnapshot = await _db
          .collection('alerts')
          .where('isResolved', isEqualTo: false)
          .get();

      return {
        'activeBuses': activeBuses,
        'unresolvedAlerts': alertSnapshot.docs.length,
      };
    });
  }

  /// Creates a live data stream from the device's subcollection.
  /// Firestore path: devices/{deviceId}/readings (MAC-address-based).
  static Stream<Map<String, dynamic>?> liveDataStream(String deviceId) {
    return _db
        .collection('devices')
        .doc(deviceId)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      Map<String, dynamic>? validData;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final hasLocation =
            data['latitude'] != null && data['longitude'] != null;

        final hasSpeed = data['speed'] != null;

        if (hasLocation || hasSpeed) {
          validData = data;

          break;
        }
      }

      validData ??= snapshot.docs.first.data();

      return _normalizeLiveData(validData);
    });
  }

  /// Creates a live data stream filtering by busId (fallback when deviceId
  /// is not present on the bus document). Uses collectionGroup to query
  /// across all devices/{x}/readings subcollections.
  static Stream<Map<String, dynamic>?> liveDataStreamByBusId(String busId) {
    return _db
        .collectionGroup('readings')
        .where('busId', isEqualTo: busId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();

      return _normalizeLiveData(data);
    });
  }

  /// Normalizes raw Firestore live_data document into the format the UI expects.
  /// Handles both ESP32 string values ("SAFE"/"UNSAFE"/"DANGER") and boolean values
  /// from the simulator.
  static Map<String, dynamic> _normalizeLiveData(Map<String, dynamic> data) {
    // Convert Timestamp to string
    if (data['timestamp'] is Timestamp) {
      data['timestamp'] =
          (data['timestamp'] as Timestamp).toDate().toIso8601String();
    }

    // Normalize latitude/longitude
    data['lat'] = data['latitude'] ?? data['lat'] ?? 0;
    data['lng'] = data['longitude'] ?? data['lng'] ?? 0;

    // smoke — ESP32 sends "SAFE"/"UNSAFE" string, simulator sends bool
    final smokeRaw = data['smoke'] ?? data['smokeDetected'];
    data['smokeDetected'] =
        (smokeRaw is bool) ? smokeRaw : _isDangerString(smokeRaw);

    // flame
    final flameRaw = data['flame'] ?? data['flameDetected'];
    data['flameDetected'] =
        (flameRaw is bool) ? flameRaw : _isDangerString(flameRaw);

    // tiltAngle — ESP32 sends "SAFE"/"UNSAFE" string
    final tiltRaw = data['tiltAngle'];
    data['tiltAngle'] = (tiltRaw is num)
        ? tiltRaw.toDouble()
        : (_isDangerString(tiltRaw) ? 40.0 : 0.0);

    // temperature and speed
    data['temperature'] = data['temperature'] ?? 0;
    data['speed'] = data['speed'] ?? 0;

    // isEmergency
    data['isEmergency'] = data['isEmergency'] ?? false;

    return data;
  }

  /// Returns true if the value represents a danger/unsafe state.
  /// Handles "DANGER", "UNSAFE", true, and any non-"SAFE" string.
  static bool _isDangerString(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final text = value.toString().toUpperCase().trim();
    return text == 'DANGER' || text == 'UNSAFE';
  }
}
