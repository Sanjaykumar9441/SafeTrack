import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../services/api_service.dart';

class BusProvider extends ChangeNotifier {
  List<Bus> _buses = [];
  StreamSubscription? _sub;

  List<Bus> get buses => _buses;

  void startListening() {
    _sub = ApiService.busesStream().listen((buses) {
      _buses = buses;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
