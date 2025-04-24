class AppUsageInfo {
  final String packageName;
  final String appName;
  final DateTime firstTimeUsed;
  final DateTime lastTimeUsed;
  final int launchCount;
  final int totalTimeInForegroundMs;
  final double totalTimeInForegroundMin;

  const AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.firstTimeUsed,
    required this.lastTimeUsed,
    required this.launchCount,
    required this.totalTimeInForegroundMs,
    required this.totalTimeInForegroundMin,
  });

  factory AppUsageInfo.fromJson(Map<String, dynamic> json) {
    return AppUsageInfo(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      firstTimeUsed: DateTime.fromMillisecondsSinceEpoch(json['firstTimeUsed'] as int),
      lastTimeUsed: DateTime.fromMillisecondsSinceEpoch(json['lastTimeUsed'] as int),
      launchCount: json['launchCount'] as int,
      totalTimeInForegroundMs: json['totalTimeInForegroundMs'] as int,
      totalTimeInForegroundMin: json['totalTimeInForegroundMin'] as double,
    );
  }

  String get formattedUsageTime {
    final hours = (totalTimeInForegroundMin / 60).floor();
    final minutes = (totalTimeInForegroundMin % 60).floor();
    final seconds = ((totalTimeInForegroundMin * 60) % 60).floor();

    if (totalTimeInForegroundMs < 1000) {
      return '<1s'; // Less than 1 second
    } else if (totalTimeInForegroundMs < 60000) {
      // For durations less than a minute, show only seconds
      return '${seconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

class AppUsageEvent {
  final DateTime timestamp;
  final String appName;
  final String packageName;
  final bool isOpened;

  const AppUsageEvent({
    required this.timestamp,
    required this.appName,
    required this.packageName,
    required this.isOpened,
  });

  factory AppUsageEvent.fromLogLine(String logLine) {
    try {
      final parts = logLine.split(' - ');
      if (parts.length < 2) return _createDefaultEvent(logLine);
      
      final timestamp = DateTime.parse(parts[0].replaceAll(' ', 'T'));
      final message = parts[1];
      
      // Handle app usage logs format "App opened/closed: AppName (package.name)"
      if (message.startsWith('App opened:') || message.startsWith('App closed:')) {
        final isOpened = message.startsWith('App opened:');
        
        // Extract app details from the message
        final appDetails = message.substring(message.indexOf(':') + 1).trim();
        
        // Extract package name within parentheses
        final packageNameRegex = RegExp(r'\(([^)]+)\)');
        final match = packageNameRegex.firstMatch(appDetails);
        final packageName = match?.group(1) ?? '';
        
        // Extract app name (everything before the package name in parentheses)
        String appName = appDetails;
        if (packageName.isNotEmpty) {
          appName = appDetails.substring(0, appDetails.indexOf('(')).trim();
        }
        
        return AppUsageEvent(
          timestamp: timestamp,
          appName: appName,
          packageName: packageName,
          isOpened: isOpened,
        );
      }
      
      // If it's not a proper app usage log, return a default event
      return _createDefaultEvent(logLine);
    } catch (e) {
      print('Error parsing app usage log: $e, log: $logLine');
      return _createDefaultEvent(logLine);
    }
  }
  
  static AppUsageEvent _createDefaultEvent(String logLine) {
    // Create a fallback event when parsing fails
    final now = DateTime.now();
    return AppUsageEvent(
      timestamp: now,
      appName: 'Unknown App',
      packageName: 'unknown.package',
      isOpened: false,
    );
  }
} 