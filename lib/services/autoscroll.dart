class AutoScrollService {
  // Singleton pattern
  static final AutoScrollService _instance = AutoScrollService._internal();
  
  factory AutoScrollService() {
    return _instance;
  }
  
  AutoScrollService._internal();
  
  // Auto-scroll settings
  bool enabled = false;
  int intervalSeconds = 5;
  
  // Listeners to notify when settings change
  final List<Function()> _listeners = [];
  
  // Add a listener
  void addListener(Function() listener) {
    _listeners.add(listener);
  }
  
  // Remove a listener
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }
  
  // Notify all listeners
  void notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }
  
  // Update settings
  void updateSettings({bool? enabled, int? intervalSeconds}) {
    if (enabled != null) this.enabled = enabled;
    if (intervalSeconds != null) this.intervalSeconds = intervalSeconds;
    notifyListeners();
  }
}