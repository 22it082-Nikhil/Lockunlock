import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/app_usage.dart';

class AppUsageService {
  static const platform = MethodChannel('com.example.lockunlock/admin');
  
  // Check if usage stats permission is granted
  static Future<bool> hasUsageStatsPermission() async {
    try {
      return await platform.invokeMethod('hasUsageStatsPermission');
    } on PlatformException catch (e) {
      print("Failed to check usage stats permission: ${e.message}");
      return false;
    }
  }
  
  // Request usage stats permission
  static Future<void> requestUsageStatsPermission() async {
    try {
      await platform.invokeMethod('requestUsageStatsPermission');
    } on PlatformException catch (e) {
      print("Failed to request usage stats permission: ${e.message}");
    }
  }
  
  // Get app usage statistics
  static Future<List<AppUsageInfo>> getAppUsageStats({int timeRangeHours = 24}) async {
    try {
      final String result = await platform.invokeMethod('getAppUsageStats', {'timeRangeHours': timeRangeHours});
      
      // Check if there was an error
      if (result.contains('error')) {
        print("Error getting app usage stats: $result");
        return [];
      }
      
      // Parse JSON
      List<dynamic> jsonList = jsonDecode(result);
      return jsonList.map((json) => AppUsageInfo.fromJson(json)).toList();
    } on PlatformException catch (e) {
      print("Failed to get app usage stats: ${e.message}");
      return [];
    } catch (e) {
      print("Error parsing app usage stats: $e");
      return [];
    }
  }
  
  // Get app usage history (open/close events)
  static Future<List<AppUsageEvent>> getAppUsageHistory() async {
    try {
      final String result = await platform.invokeMethod('getAppUsageHistory');
      
      if (result.isEmpty) {
        return [];
      }
      
      // Parse the log lines
      final List<String> lines = result.split('\n');
      return lines
          .where((line) => line.isNotEmpty)
          .map((line) => AppUsageEvent.fromLogLine(line))
          .toList();
    } on PlatformException catch (e) {
      print("Failed to get app usage history: ${e.message}");
      return [];
    } catch (e) {
      print("Error parsing app usage history: $e");
      return [];
    }
  }
  
  // Clear app usage history
  static Future<void> clearAppUsageHistory() async {
    try {
      await platform.invokeMethod('clearAppUsageHistory');
    } on PlatformException catch (e) {
      print("Failed to clear app usage history: ${e.message}");
    }
  }
  
  // Generate test app usage data (for development and testing)
  static Future<List<AppUsageEvent>> generateTestData(int count) async {
    final random = Random();
    final now = DateTime.now();
    
    final testApps = [
      {'name': 'YouTube', 'package': 'com.google.android.youtube'},
      {'name': 'Chrome', 'package': 'com.android.chrome'},
      {'name': 'WhatsApp', 'package': 'com.whatsapp'},
      {'name': 'Instagram', 'package': 'com.instagram.android'},
      {'name': 'Facebook', 'package': 'com.facebook.katana'},
      {'name': 'Spotify', 'package': 'com.spotify.music'},
      {'name': 'Gmail', 'package': 'com.google.android.gm'},
      {'name': 'Maps', 'package': 'com.google.android.maps'},
    ];
    
    final events = <AppUsageEvent>[];
    
    for (int i = 0; i < count; i++) {
      final app = testApps[random.nextInt(testApps.length)];
      final isOpened = random.nextBool();
      final minutesAgo = random.nextInt(240); // Within last 4 hours
      
      events.add(AppUsageEvent(
        timestamp: now.subtract(Duration(minutes: minutesAgo)),
        appName: app['name']!,
        packageName: app['package']!,
        isOpened: isOpened,
      ));
    }
    
    // Sort by timestamp (newest first)
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return events;
  }
  
  // Add test app usage events to the stored history
  static Future<void> addTestEvents(int count) async {
    try {
      final events = await generateTestData(count);
      final existingEvents = await getAppUsageHistory();
      
      // If we have existing events, clear them first
      if (existingEvents.isNotEmpty) {
        await clearAppUsageHistory();
      }
      
      // Create formatted log lines and combine them
      final formattedEvents = events.map((event) {
        final timestamp = event.timestamp.toString().replaceAll('T', ' ').substring(0, 19);
        final action = event.isOpened ? 'opened' : 'closed';
        return '$timestamp - App $action: ${event.appName} (${event.packageName})';
      }).join('\n');
      
      // Store the formatted events
      await platform.invokeMethod('addTestAppUsageEvents', {'events': formattedEvents});
      
    } on PlatformException catch (e) {
      print("Failed to add test app usage events: ${e.message}");
    }
  }
} 