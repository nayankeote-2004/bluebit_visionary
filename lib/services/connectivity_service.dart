import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Key for storing connectivity status
  final String _isOfflineKey = 'is_offline';

  // Status
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // Stream controller for broadcasting connectivity changes
  final StreamController<bool> _connectivityStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityStreamController.stream;

  // Initialize connectivity checking
  Future<void> initialize() async {
    // Load last known status from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _isOffline = prefs.getBool(_isOfflineKey) ?? false;

    // Broadcast initial state
    _connectivityStreamController.add(_isOffline);

    // Set up listener for connectivity changes
    Connectivity().onConnectivityChanged.listen(_handleConnectivityChanges);

    // Check current status to ensure we're up-to-date
    await checkConnectivity();
  }

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      // Handle the list of connectivity results by using the first one
      final result = connectivityResults.isNotEmpty 
          ? connectivityResults.first 
          : ConnectivityResult.none;
      await _updateConnectivityStatus(result);
      return !_isOffline;
    } catch (e) {
      print('Error checking connectivity: $e');
      await _setOfflineStatus(true);
      return false;
    }
  }

  // Update connectivity status
  Future<void> _updateConnectivityStatus(ConnectivityResult result) async {
    final isConnected = result != ConnectivityResult.none;
    final newOfflineStatus = !isConnected;

    // Only update if status changed
    if (_isOffline != newOfflineStatus) {
      await _setOfflineStatus(newOfflineStatus);
    }
  }

  // Set offline status and persist it
  Future<void> _setOfflineStatus(bool isOffline) async {
    _isOffline = isOffline;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isOfflineKey, isOffline);

    // Notify listeners
    _connectivityStreamController.add(isOffline);

    print('Connectivity status updated: ${isOffline ? "Offline" : "Online"}');
  }

  // Dispose resources
  void dispose() {
    _connectivityStreamController.close();
  }
  
  // Handle the list of connectivity results from the stream
  void _handleConnectivityChanges(List<ConnectivityResult> results) {
    final result = results.isNotEmpty 
        ? results.first 
        : ConnectivityResult.none;
    _updateConnectivityStatus(result);
  }
}
