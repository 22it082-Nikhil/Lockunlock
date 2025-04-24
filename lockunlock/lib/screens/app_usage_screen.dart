import 'package:flutter/material.dart';
import '../models/app_usage.dart';
import '../services/app_usage_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({Key? key}) : super(key: key);

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> {
  List<AppUsageInfo> _appUsageStats = [];
  List<AppUsageInfo> _filteredStats = [];
  bool _isLoading = true;
  int _selectedTimeRange = 24; // Hours
  final List<int> _timeRanges = [6, 12, 24, 48, 72];
  String _filterType = 'all'; // 'all', 'short', 'medium', 'long'

  @override
  void initState() {
    super.initState();
    _loadAppUsageStats();
  }

  Future<void> _loadAppUsageStats() async {
    setState(() {
      _isLoading = true;
    });

    final stats = await AppUsageService.getAppUsageStats(
      timeRangeHours: _selectedTimeRange,
    );

    setState(() {
      _appUsageStats = stats;
      _applyFilter();
      _isLoading = false;
    });
    
    // If no stats are available, show a snackbar with option to generate test data
    if (stats.isEmpty && mounted) {
      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No app usage data available'),
            action: SnackBarAction(
              label: 'Generate Test Data',
              onPressed: _generateTestData,
            ),
          ),
        );
      });
    }
  }

  Future<void> _generateTestData() async {
    setState(() {
      _isLoading = true;
    });
    
    // First, create test app events
    await AppUsageService.addTestEvents(15);
    
    // Then create some mock app usage stats
    final testStats = _createMockAppUsageStats();
    
    setState(() {
      _appUsageStats = testStats;
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test data generated successfully'),
      ),
    );
  }

  List<AppUsageInfo> _createMockAppUsageStats() {
    final now = DateTime.now();
    final random = Random();
    
    final apps = [
      {
        'packageName': 'com.google.android.youtube',
        'appName': 'YouTube',
        'launchCount': 8 + random.nextInt(15),
        'minutes': 45 + random.nextInt(90),
      },
      {
        'packageName': 'com.whatsapp',
        'appName': 'WhatsApp',
        'launchCount': 10 + random.nextInt(20),
        'minutes': 30 + random.nextInt(60),
      },
      {
        'packageName': 'com.instagram.android',
        'appName': 'Instagram',
        'launchCount': 6 + random.nextInt(12),
        'minutes': 25 + random.nextInt(50),
      },
      {
        'packageName': 'com.android.chrome',
        'appName': 'Chrome',
        'launchCount': 5 + random.nextInt(10),
        'minutes': 20 + random.nextInt(40),
      },
      {
        'packageName': 'com.spotify.music',
        'appName': 'Spotify',
        'launchCount': 3 + random.nextInt(8),
        'minutes': 15 + random.nextInt(45),
      },
      {
        'packageName': 'com.facebook.katana',
        'appName': 'Facebook',
        'launchCount': 4 + random.nextInt(8),
        'minutes': 12 + random.nextInt(30),
      },
      {
        'packageName': 'com.netflix.mediaclient',
        'appName': 'Netflix',
        'launchCount': 2 + random.nextInt(5),
        'minutes': 10 + random.nextInt(40),
      },
    ];
    
    return apps.map((app) {
      final minutes = app['minutes'] as int;
      final ms = minutes * 60 * 1000;
      final firstTime = now.subtract(Duration(hours: random.nextInt(48) + 1));
      final lastTime = now.subtract(Duration(minutes: random.nextInt(180)));
      
      return AppUsageInfo(
        packageName: app['packageName'] as String,
        appName: app['appName'] as String,
        firstTimeUsed: firstTime,
        lastTimeUsed: lastTime,
        launchCount: app['launchCount'] as int,
        totalTimeInForegroundMs: ms,
        totalTimeInForegroundMin: minutes.toDouble(),
      );
    }).toList();
  }

  void _applyFilter() {
    switch (_filterType) {
      case 'short':
        // Apps used for less than 1 minute
        _filteredStats = _appUsageStats
            .where((app) => app.totalTimeInForegroundMs < 60000)
            .toList();
        break;
      case 'medium':
        // Apps used between 1 and 10 minutes
        _filteredStats = _appUsageStats
            .where((app) => 
                app.totalTimeInForegroundMs >= 60000 && 
                app.totalTimeInForegroundMs < 600000)
            .toList();
        break;
      case 'long':
        // Apps used for more than 10 minutes
        _filteredStats = _appUsageStats
            .where((app) => app.totalTimeInForegroundMs >= 600000)
            .toList();
        break;
      default:
        // All apps
        _filteredStats = List.from(_appUsageStats);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Time range and filters
        _buildControlsArea(),
        // Stats content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAppUsageList(),
        ),
      ],
    );
  }

  Widget _buildControlsArea() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Time Range:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadAppUsageStats,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          
          // Time range selector
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timeRanges.map((hours) {
                final isSelected = hours == _selectedTimeRange;
                String label;
                if (hours < 24) {
                  label = '$hours Hours';
                } else {
                  final days = hours ~/ 24;
                  label = days == 1 ? '1 Day' : '$days Days';
                }
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTimeRange = hours;
                        });
                        _loadAppUsageStats();
                      }
                    },
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Duration filter
          const SizedBox(height: 12),
          Text(
            'Filter by Duration:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('< 1min', 'short'),
                const SizedBox(width: 8),
                _buildFilterChip('1-10min', 'medium'),
                const SizedBox(width: 8),
                _buildFilterChip('> 10min', 'long'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = value == _filterType;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterType = value;
            _applyFilter();
          });
        }
      },
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _buildAppUsageList() {
    if (_appUsageStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.app_blocking,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No app usage data available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Use your device for a while and check back later',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate total usage time
    double totalMinutes = _filteredStats.fold(
      0.0,
      (sum, app) => sum + app.totalTimeInForegroundMin,
    );

    return Column(
      children: [
        // Summary card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'App Usage Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredStats.length} Apps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem(
                        icon: Icons.timer,
                        title: 'Total Time',
                        value: _formatTotalTime(totalMinutes),
                        color: Colors.purple,
                      ),
                      _buildSummaryItem(
                        icon: Icons.open_in_new,
                        title: 'Most Opened',
                        value: _filteredStats.isNotEmpty
                            ? _filteredStats
                                .reduce((a, b) => a.launchCount > b.launchCount ? a : b)
                                .appName
                            : 'None',
                        color: Colors.blue,
                      ),
                      _buildSummaryItem(
                        icon: Icons.watch_later,
                        title: 'Most Used',
                        value: _filteredStats.isNotEmpty
                            ? _filteredStats
                                .reduce((a, b) =>
                                    a.totalTimeInForegroundMs > b.totalTimeInForegroundMs ? a : b)
                                .appName
                            : 'None',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // App list heading with count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.apps,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'App Usage List',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getFilterText(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // App list
        Expanded(
          child: _filteredStats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_off,
                        size: 48,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No apps match this filter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: _filteredStats.length,
                  itemBuilder: (context, index) {
                    final app = _filteredStats[index];
                    return _buildAppUsageItem(app, index);
                  },
                ),
        ),
      ],
    );
  }

  String _getFilterText() {
    switch (_filterType) {
      case 'short':
        return 'Less than 1 minute';
      case 'medium':
        return '1-10 minutes';
      case 'long':
        return 'More than 10 minutes';
      default:
        return 'All durations';
    }
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAppUsageItem(AppUsageInfo app, int index) {
    final usagePercentage = _filteredStats.isNotEmpty
        ? (app.totalTimeInForegroundMin /
                _filteredStats.fold(
                    0.0, (sum, app) => sum + app.totalTimeInForegroundMin)) *
            100
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            app.appName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          app.appName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  app.formattedUsageTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${app.launchCount} ${app.launchCount == 1 ? 'time' : 'times'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: usagePercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForPercentage(usagePercentage / 100),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${usagePercentage.toStringAsFixed(1)}% of total usage',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Last used',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatLastUsed(app.lastTimeUsed),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double value) {
    if (value < 0.2) {
      return Colors.green;
    } else if (value < 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _formatTotalTime(double minutes) {
    final hours = (minutes / 60).floor();
    final remainingMinutes = (minutes % 60).floor();
    
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    } else {
      return '${remainingMinutes}m';
    }
  }

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(lastUsed);
    }
  }
} 