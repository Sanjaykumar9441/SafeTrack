import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favIds = {};

  Set<String> get favIds => _favIds;

  bool isFavorite(String busId) => _favIds.contains(busId);

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_buses') ?? [];
    _favIds = list.toSet();
    notifyListeners();
  }

  Future<void> toggle(String busId) async {
    if (_favIds.contains(busId)) {
      _favIds.remove(busId);
    } else {
      _favIds.add(busId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_buses', _favIds.toList());
  }
}
