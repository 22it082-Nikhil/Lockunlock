import 'package:flutter/material.dart';
import '../models/app_usage.dart';
import '../services/app_usage_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AppEventsScreen extends StatefulWidget {
  const AppEventsScreen({Key? key}) : super(key: key);

  @override
  State<AppEventsScreen> createState() => _AppEventsScreenState();
}

class _AppEventsScreenState extends State<AppEventsScreen> {
  List<AppUsageEvent> _appEvents = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAppEvents();
    
    // Set up refresh timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadAppEvents();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAppEvents() async {
    setState(() {
      _isLoading = true;
    });

    final events = await AppUsageService.getAppUsageHistory();

    setState(() {
      _appEvents = events;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'App Activity Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadAppEvents,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        
        // Event count badge
        if (_appEvents.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_note, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_appEvents.length} App Events',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        
        // Events list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAppEventsList(),
        ),
      ],
    );
  }

  Widget _buildAppEventsList() {
    if (_appEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No app events recorded',
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
                'Lock and unlock your device to record app activity',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateTestData,
              icon: const Icon(Icons.data_array),
              label: const Text('Generate Test Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    // Group events by day
    final groupedEvents = <String, List<AppUsageEvent>>{};
    for (final event in _appEvents) {
      final day = DateFormat('yyyy-MM-dd').format(event.timestamp);
      if (!groupedEvents.containsKey(day)) {
        groupedEvents[day] = [];
      }
      groupedEvents[day]!.add(event);
    }

    final sortedDays = groupedEvents.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: sortedDays.length,
      itemBuilder: (context, dayIndex) {
        final day = sortedDays[dayIndex];
        final events = groupedEvents[day]!;
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
        
        String dayDisplay;
        if (day == today) {
          dayDisplay = 'Today';
        } else if (day == yesterday) {
          dayDisplay = 'Yesterday';
        } else {
          final date = DateTime.parse(day);
          dayDisplay = DateFormat('EEEE, MMMM d').format(date);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                dayDisplay,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            _buildTimelineForDay(events),
          ],
        );
      },
    );
  }

  Widget _buildTimelineForDay(List<AppUsageEvent> events) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isFirst = index == 0;
        final isLast = index == events.length - 1;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 16.0),
                child: Text(
                  DateFormat('h:mm a').format(event.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: event.isOpened ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    event.isOpened ? Icons.open_in_new : Icons.close,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            Expanded(
              child: Card(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              event.appName.isEmpty ? 'Unknown App' : event.appName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: event.isOpened ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              event.isOpened ? 'Opened' : 'Closed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: event.isOpened ? Colors.green[800] : Colors.red[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.packageName.isEmpty ? 'Unknown package' : event.packageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getFormattedTimeDifference(event.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getFormattedTimeDifference(DateTime eventTime) {
    final now = DateTime.now();
    final difference = now.difference(eventTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(eventTime);
    }
  }

  Future<void> _generateTestData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Generate 20 test app events
    await AppUsageService.addTestEvents(20);
    
    // Reload the events
    await _loadAppEvents();
  }
} 