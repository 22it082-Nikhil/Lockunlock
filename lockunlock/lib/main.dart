import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'models/app_usage.dart';
import 'services/app_usage_service.dart';
import 'screens/app_usage_screen.dart';
import 'screens/app_events_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LockUnlockScreen(),
    );
  }
}

class LockUnlockScreen extends StatefulWidget {
  const LockUnlockScreen({Key? key}) : super(key: key);

  @override
  State<LockUnlockScreen> createState() => _LockUnlockScreenState();
}

class _LockUnlockScreenState extends State<LockUnlockScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.lockunlock/admin');

  bool _isDeviceAdmin = false;
  bool _isServiceRunning = false;
  bool _hasUsagePermission = false;
  List<LogEntry> _allLogs = [];
  Timer? _refreshTimer;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    
    // Set up timer to refresh logs every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshLogs();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLogs();
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    await _checkDeviceAdmin();
    await _checkUsageStatsPermission();
  }

  Future<void> _checkDeviceAdmin() async {
    try {
      final bool isActive = await platform.invokeMethod('isDeviceAdminActive');
      setState(() {
        _isDeviceAdmin = isActive;
      });
      
      if (isActive && !_isServiceRunning) {
        _startMonitoring();
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to check device admin status: ${e.message}");
    }
  }

  Future<void> _checkUsageStatsPermission() async {
    final hasPermission = await AppUsageService.hasUsageStatsPermission();
    setState(() {
      _hasUsagePermission = hasPermission;
    });
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      await platform.invokeMethod('requestDeviceAdmin');
      await _checkDeviceAdmin();
    } on PlatformException catch (e) {
      debugPrint("Failed to request device admin: ${e.message}");
    }
  }

  Future<void> _requestUsageStatsPermission() async {
    await AppUsageService.requestUsageStatsPermission();
    await _checkUsageStatsPermission();
  }

  Future<void> _startMonitoring() async {
    if (_isDeviceAdmin) {
      try {
        await platform.invokeMethod('startService');
        setState(() {
          _isServiceRunning = true;
        });
        await _refreshLogs();
      } on PlatformException catch (e) {
        debugPrint("Failed to start monitoring: ${e.message}");
      }
    }
  }

  Future<void> _refreshLogs() async {
    try {
      final String lockLogs = await platform.invokeMethod('getLockHistory');
      final String unlockLogs = await platform.invokeMethod('getUnlockHistory');
      
      List<LogEntry> allLogs = [];
      
      // Process lock logs - include screen off and test lock events
      if (lockLogs.isNotEmpty) {
        final List<String> locks = lockLogs.split('\n');
        for (String log in locks) {
          if (log.isNotEmpty) {
            final String message = _extractMessage(log);
            if (message.contains("Screen OFF") || 
                message.contains("Screen turned OFF") || 
                message.contains("TEST LOCK EVENT")) {
              allLogs.add(LogEntry(
                timestamp: _parseTimestamp(log),
                isLock: true,
                message: message.contains("TEST") ? "Test Lock Event" : "Screen OFF",
              ));
            }
          }
        }
      }
      
      // Process unlock logs - include screen on and test unlock events
      if (unlockLogs.isNotEmpty) {
        final List<String> unlocks = unlockLogs.split('\n');
        for (String log in unlocks) {
          if (log.isNotEmpty) {
            final String message = _extractMessage(log);
            if (message.contains("Screen ON") || 
                message.contains("Screen unlocked") || 
                message.contains("TEST UNLOCK EVENT")) {
              allLogs.add(LogEntry(
                timestamp: _parseTimestamp(log),
                isLock: false,
                message: message.contains("TEST") ? "Test Unlock Event" : "Screen ON",
              ));
            }
          }
        }
      }
      
      // Sort all logs by timestamp (newest first)
      allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      setState(() {
        _allLogs = allLogs;
      });

      // Debug log to console
      debugPrint("Found ${allLogs.length} logs after filtering");
      
    } on PlatformException catch (e) {
      debugPrint("Failed to refresh logs: ${e.message}");
    }
  }

  DateTime _parseTimestamp(String log) {
    try {
      final String timeStr = log.contains(" - ") 
          ? log.split(" - ")[0].trim()
          : log.trim();
      return DateTime.parse(timeStr.replaceAll(' ', 'T'));
    } catch (e) {
      return DateTime.now(); // Fallback for parsing errors
    }
  }

  String _extractMessage(String log) {
    if (log.contains(" - ")) {
      return log.split(" - ")[1].trim();
    }
    return "Event recorded";
  }

  Future<void> _clearLogs() async {
    try {
      await platform.invokeMethod('clearHistory');
      if (_hasUsagePermission) {
        await AppUsageService.clearAppUsageHistory();
      }
      await _refreshLogs();
    } on PlatformException catch (e) {
      debugPrint("Failed to clear logs: ${e.message}");
    }
  }
  
  Future<void> _addTestEvent(bool isLock) async {
    try {
      await platform.invokeMethod('testAddEvent', {'isLock': isLock});
      await _refreshLogs();
    } on PlatformException catch (e) {
      debugPrint("Failed to add test event: ${e.message}");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Row(
          children: [
            Icon(Icons.phonelink_lock, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Device Monitor',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: (_isDeviceAdmin)
        ? _buildScreenContent()
        : _buildPermissionRequestScreen(),
      bottomNavigationBar: _isDeviceAdmin ? BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lock),
            label: 'Lock Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: 'App Usage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'App Events',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ) : null,
    );
  }

  Widget _buildScreenContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildLockScreen();
      case 1:
        return _hasUsagePermission 
            ? const AppUsageScreen()  
            : _buildUsagePermissionRequest();
      case 2:
        return _hasUsagePermission 
            ? const AppEventsScreen() 
            : _buildUsagePermissionRequest();
      default:
        return _buildLockScreen();
    }
  }

  Widget _buildLockScreen() {
    return Column(
      children: [
        // Testing buttons container
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Status text
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isDeviceAdmin ? Icons.check_circle : Icons.error,
                      color: _isDeviceAdmin ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Admin: ${_isDeviceAdmin ? 'Active' : 'Inactive'} | Service: ${_isServiceRunning ? 'Running' : 'Stopped'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Test buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _addTestEvent(true),
                        icon: const Icon(Icons.lock, size: 18),
                        label: const Text('Test Lock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _addTestEvent(false),
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: const Text('Test Unlock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: OutlinedButton.icon(
                        onPressed: _refreshLogs,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Count badge
        if (_allLogs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_allLogs.length} Screen Events',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Log listing
        Expanded(
          child: _buildLogsList(),
        ),
      ],
    );
  }

  Widget _buildPermissionRequestScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Device Admin permission is required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'To monitor screen lock events, this app needs admin access',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestDeviceAdmin,
              icon: const Icon(Icons.security),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsagePermissionRequest() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.data_usage,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Usage Stats Permission Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'To track app usage and screen time, please grant usage access permission',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestUsageStatsPermission,
              icon: const Icon(Icons.app_settings_alt),
              label: const Text('Grant Usage Permission'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    if (_allLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off, 
              size: 64, 
              color: Colors.grey.withOpacity(0.5)
            ),
            const SizedBox(height: 16),
            Text(
              'No screen events recorded',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lock and unlock events will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _allLogs.length,
      itemBuilder: (context, index) {
        final LogEntry log = _allLogs[index];
        final bool isToday = log.timestamp.day == DateTime.now().day;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: log.isLock 
                    ? [Colors.red.shade50, Colors.red.shade100]
                    : [Colors.green.shade50, Colors.green.shade100],
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: log.isLock ? Colors.red.shade200 : Colors.green.shade200,
                ),
                child: Icon(
                  log.isLock ? Icons.screen_lock_portrait : Icons.screen_lock_rotation,
                  color: log.isLock ? Colors.red.shade800 : Colors.green.shade800,
                  size: 24,
                ),
              ),
              title: Text(
                log.message,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: log.isLock ? Colors.red.shade900 : Colors.green.shade900,
                ),
              ),
              subtitle: Text(
                isToday 
                  ? 'Today at ${DateFormat('h:mm:ss a').format(log.timestamp)}'
                  : DateFormat('MMM d, h:mm:ss a').format(log.timestamp),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: log.isLock 
                      ? Colors.red.shade200.withOpacity(0.5)
                      : Colors.green.shade200.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  index == 0 ? 'Latest' : '#${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: log.isLock ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LogEntry {
  final DateTime timestamp;
  final bool isLock;
  final String message;
  
  LogEntry({
    required this.timestamp,
    required this.isLock,
    required this.message,
  });
}
