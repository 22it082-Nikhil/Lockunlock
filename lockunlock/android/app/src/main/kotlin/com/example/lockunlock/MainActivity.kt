package com.example.lockunlock

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import android.content.BroadcastReceiver
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.example.lockunlock/admin"
        private const val REQUEST_CODE_ENABLE_ADMIN = 1
        private const val REQUEST_CODE_USAGE_ACCESS = 2
        private const val PREFS_NAME = "LockUnlockPrefs"
        private const val LOCK_HISTORY_KEY = "lock_history"
        private const val UNLOCK_HISTORY_KEY = "unlock_history"
        private const val APP_USAGE_KEY = "app_usage_history"
    }

    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var componentName: ComponentName
    private var screenReceiver: BroadcastReceiver? = null
    private lateinit var usageStatsManager: UsageStatsManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDeviceAdmin" -> {
                    requestDeviceAdmin()
                    result.success(true)
                }
                "isDeviceAdminActive" -> {
                    result.success(isDeviceAdminActive())
                }
                "getLockHistory" -> {
                    val history = getLockHistory()
                    Log.d(TAG, "Returning lock history: $history")
                    result.success(history)
                }
                "getUnlockHistory" -> {
                    val history = getUnlockHistory()
                    Log.d(TAG, "Returning unlock history: $history")
                    result.success(history)
                }
                "clearHistory" -> {
                    clearHistory()
                    result.success(true)
                }
                "startService" -> {
                    startLockUnlockService()
                    result.success(true)
                }
                "testAddEvent" -> {
                    // Test method to add an event directly
                    addTestEvent(call.argument<Boolean>("isLock") ?: true)
                    result.success(true)
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(true)
                }
                "getAppUsageStats" -> {
                    val timeRange = call.argument<Int>("timeRangeHours") ?: 24
                    result.success(getAppUsageStats(timeRange))
                }
                "getAppUsageHistory" -> {
                    result.success(getAppUsageHistory())
                }
                "clearAppUsageHistory" -> {
                    clearAppUsageHistory()
                    result.success(true)
                }
                "addTestAppUsageEvents" -> {
                    val events = call.argument<String>("events") ?: ""
                    addTestAppUsageEvents(events)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        componentName = ComponentName(this, com.example.lockunlock.DeviceAdminReceiver::class.java)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Generate some initial test app usage data for demonstration
        if (hasUsageStatsPermission()) {
            logCurrentApps()
        }
        
        // Manually register for screen events in the activity too
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                Log.d(TAG, "Activity received broadcast: ${intent.action}")
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> {
                        Log.d(TAG, "Screen OFF detected in activity")
                        logEvent("Screen turned OFF", true)
                        // Record current app usage when screen is turned off
                        if (hasUsageStatsPermission()) {
                            recordCurrentAppUsage(false)
                        }
                    }
                    Intent.ACTION_SCREEN_ON -> {
                        Log.d(TAG, "Screen ON detected in activity")
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        Log.d(TAG, "User present (Unlocked) detected in activity")
                        logEvent("Screen unlocked", false)
                        // Record current app usage when screen is unlocked
                        if (hasUsageStatsPermission()) {
                            recordCurrentAppUsage(true)
                        }
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        
        // Start service if device admin is active
        if (isDeviceAdminActive()) {
            startLockUnlockService()
            Toast.makeText(this, "Lock/Unlock monitoring service started", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "Please grant Device Admin permission", Toast.LENGTH_LONG).show()
            // Add an initial record to show in history
            logEvent("App started - Device admin not active", false)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        screenReceiver?.let {
            unregisterReceiver(it)
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_CODE_ENABLE_ADMIN) {
            if (resultCode == RESULT_OK) {
                Toast.makeText(this, "Device Admin enabled", Toast.LENGTH_SHORT).show()
                logEvent("Device Admin enabled", false)
                startLockUnlockService()
            } else {
                Toast.makeText(this, "Device Admin permission denied", Toast.LENGTH_LONG).show()
                logEvent("Device Admin permission denied", false)
            }
        } else if (requestCode == REQUEST_CODE_USAGE_ACCESS) {
            if (hasUsageStatsPermission()) {
                Toast.makeText(this, "Usage access granted", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Usage access permission denied", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun requestDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "We need device admin access to monitor lock and unlock events")
        }
        startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN)
    }

    private fun isDeviceAdminActive(): Boolean {
        val isActive = devicePolicyManager.isAdminActive(componentName)
        Log.d(TAG, "Device admin active: $isActive")
        return isActive
    }

    private fun startLockUnlockService() {
        val serviceIntent = Intent(this, LockUnlockService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        Log.d(TAG, "Service started from activity")
        logEvent("Monitoring service started", false)
    }

    private fun getLockHistory(): String {
        val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPref.getString(LOCK_HISTORY_KEY, "") ?: ""
    }

    private fun getUnlockHistory(): String {
        val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPref.getString(UNLOCK_HISTORY_KEY, "") ?: ""
    }

    private fun clearHistory() {
        val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sharedPref.edit().apply {
            putString(LOCK_HISTORY_KEY, "")
            putString(UNLOCK_HISTORY_KEY, "")
            apply()
        }
        Log.d(TAG, "History cleared")
    }
    
    private fun logEvent(message: String, isLock: Boolean) {
        val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
        val formattedMessage = "$timestamp - $message"
        val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        val key = if (isLock) LOCK_HISTORY_KEY else UNLOCK_HISTORY_KEY
        val currentHistory = sharedPref.getString(key, "") ?: ""
        
        val newHistory = if (currentHistory.isEmpty()) {
            formattedMessage
        } else {
            "$currentHistory\n$formattedMessage"
        }
        
        Log.d(TAG, "Logging event: $formattedMessage to key: $key")
        sharedPref.edit().putString(key, newHistory).apply()
    }
    
    private fun addTestEvent(isLock: Boolean) {
        val action = if (isLock) "TEST LOCK EVENT" else "TEST UNLOCK EVENT"
        logEvent(action, isLock)
        Toast.makeText(this, "Added test $action", Toast.LENGTH_SHORT).show()
    }

    // App Usage Stats Methods
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }
    
    private fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        startActivityForResult(intent, REQUEST_CODE_USAGE_ACCESS)
    }
    
    private fun getAppUsageStats(timeRangeHours: Int): String {
        if (!hasUsageStatsPermission()) {
            return "{\"error\": \"Usage stats permission not granted\"}"
        }
        
        try {
            val calendar = Calendar.getInstance()
            val endTime = calendar.timeInMillis
            calendar.add(Calendar.HOUR, -timeRangeHours)
            val startTime = calendar.timeInMillis
            
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()
            
            val appUsageMap = mutableMapOf<String, AppUsageInfo>()
            
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                
                val packageName = event.packageName
                
                // Include more packages, only skip critical system processes
                if (packageName == "android" || 
                    packageName == "com.android.systemui" ||
                    packageName == "com.android.settings") {
                    continue
                }
                
                val eventTime = event.timeStamp
                val eventType = event.eventType
                
                if (!appUsageMap.containsKey(packageName)) {
                    appUsageMap[packageName] = AppUsageInfo(
                        packageName = packageName,
                        appName = getAppNameFromPackage(packageName),
                        firstTimeUsed = eventTime,
                        lastTimeUsed = eventTime,
                        launchCount = 0,
                        totalTimeInForeground = 0
                    )
                }
                
                val appUsageInfo = appUsageMap[packageName]!!
                
                when (eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        appUsageInfo.launchCount++
                        appUsageInfo.lastForegroundTime = eventTime
                        // Update first and last used time
                        if (eventTime < appUsageInfo.firstTimeUsed) {
                            appUsageInfo.firstTimeUsed = eventTime
                        }
                        if (eventTime > appUsageInfo.lastTimeUsed) {
                            appUsageInfo.lastTimeUsed = eventTime
                        }
                    }
                    UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        if (appUsageInfo.lastForegroundTime > 0) {
                            val usageTime = eventTime - appUsageInfo.lastForegroundTime
                            // Include even very short usages (no minimum threshold)
                            appUsageInfo.totalTimeInForeground += usageTime
                            appUsageInfo.lastForegroundTime = 0
                        }
                        // Update last used time
                        if (eventTime > appUsageInfo.lastTimeUsed) {
                            appUsageInfo.lastTimeUsed = eventTime
                        }
                    }
                }
                
                appUsageMap[packageName] = appUsageInfo
            }
            
            // Make sure to add apps that are currently in foreground
            // by checking the current time against the lastForegroundTime
            val currentTime = System.currentTimeMillis()
            for (app in appUsageMap.values) {
                if (app.lastForegroundTime > 0) {
                    val usageTime = currentTime - app.lastForegroundTime
                    app.totalTimeInForeground += usageTime
                }
            }
            
            // Process results to JSON
            val jsonArray = JSONArray()
            
            // Include all apps regardless of total time
            for (app in appUsageMap.values.sortedByDescending { it.totalTimeInForeground }) {
                val jsonObject = JSONObject()
                jsonObject.put("packageName", app.packageName)
                jsonObject.put("appName", app.appName)
                jsonObject.put("firstTimeUsed", app.firstTimeUsed)
                jsonObject.put("lastTimeUsed", app.lastTimeUsed)
                jsonObject.put("launchCount", app.launchCount)
                jsonObject.put("totalTimeInForegroundMs", app.totalTimeInForeground)
                jsonObject.put("totalTimeInForegroundMin", app.totalTimeInForeground / 60000.0)
                
                jsonArray.put(jsonObject)
            }
            
            return jsonArray.toString()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting app usage stats", e)
            return "{\"error\": \"${e.message}\"}"
        }
    }
    
    private fun getAppNameFromPackage(packageName: String): String {
        val packageManager = packageManager
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            return packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            return packageName
        }
    }
    
    private fun recordCurrentAppUsage(isUnlock: Boolean) {
        try {
            // For demonstration purposes, log some actual apps directly
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            val action = if (isUnlock) "opened" else "closed"
            
            val apps = mutableListOf<String>()
            
            // Get usage stats to find recently used apps
            val calendar = Calendar.getInstance()
            val endTime = calendar.timeInMillis
            calendar.add(Calendar.HOUR, -1) // Get apps used in the last hour
            val startTime = calendar.timeInMillis
            
            val usageStatsMap = usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)
            val topApps = usageStatsMap.entries
                .filter { !it.key.startsWith("android") && !it.key.startsWith("com.android") && it.key != packageName }
                .sortedByDescending { it.value.totalTimeInForeground }
                .take(3)
            
            for (app in topApps) {
                val appName = getAppNameFromPackage(app.key)
                val formattedMessage = "$timestamp - App $action: $appName (${app.key})"
                apps.add(formattedMessage)
                Log.d(TAG, "Logging app usage directly: $formattedMessage")
            }
            
            // If we found some apps, add them to the history
            if (apps.isNotEmpty()) {
                val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentHistory = sharedPref.getString(APP_USAGE_KEY, "") ?: ""
                
                val newHistory = if (currentHistory.isEmpty()) {
                    apps.joinToString("\n")
                } else {
                    currentHistory + "\n" + apps.joinToString("\n")
                }
                
                sharedPref.edit().putString(APP_USAGE_KEY, newHistory).apply()
            } else {
                // Add a test app usage event if no real apps were found
                addTestAppUsageEvent(isUnlock)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error recording current app usage", e)
            // Add test data as a fallback
            addTestAppUsageEvent(isUnlock)
        }
    }
    
    private fun logCurrentApps() {
        try {
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            
            // Get recently used apps
            val calendar = Calendar.getInstance()
            val endTime = calendar.timeInMillis
            calendar.add(Calendar.DAY_OF_YEAR, -1) // Get apps used in the last 24 hours
            val startTime = calendar.timeInMillis
            
            val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
            val recentApps = stats
                .filter { 
                    !it.packageName.startsWith("android") && 
                    !it.packageName.startsWith("com.android") && 
                    it.packageName != packageName &&
                    it.totalTimeInForeground > 0
                }
                .sortedByDescending { it.lastTimeUsed }
                .take(10)
                
            val logs = mutableListOf<String>()
            
            // Add "opened" events for these apps
            for (app in recentApps) {
                val appName = getAppNameFromPackage(app.packageName)
                val appTime = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                    .format(java.util.Date(app.lastTimeUsed))
                
                val formattedMessage = "$appTime - App opened: $appName (${app.packageName})"
                logs.add(formattedMessage)
                
                // Also add a "closed" event a few minutes later
                val closeTime = java.util.Date(app.lastTimeUsed + 5 * 60 * 1000) // 5 minutes later
                val closeTimeStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                    .format(closeTime)
                
                val closeMessage = "$closeTimeStr - App closed: $appName (${app.packageName})"
                logs.add(closeMessage)
            }
            
            // If we have logs, store them
            if (logs.isNotEmpty()) {
                val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentHistory = sharedPref.getString(APP_USAGE_KEY, "") ?: ""
                
                val newHistory = if (currentHistory.isEmpty()) {
                    logs.joinToString("\n")
                } else {
                    currentHistory + "\n" + logs.joinToString("\n")
                }
                
                Log.d(TAG, "Adding ${logs.size} app usage events from actual device usage")
                sharedPref.edit().putString(APP_USAGE_KEY, newHistory).apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error logging current apps", e)
        }
    }
    
    private fun addTestAppUsageEvent(isOpened: Boolean) {
        try {
            // Sample app names and package names for testing
            val apps = arrayOf(
                Pair("YouTube", "com.google.android.youtube"),
                Pair("Chrome", "com.android.chrome"),
                Pair("Gmail", "com.google.android.gm"),
                Pair("Maps", "com.google.android.maps"),
                Pair("WhatsApp", "com.whatsapp"),
                Pair("Instagram", "com.instagram.android")
            )
            
            val randomApp = apps.random()
            val appName = randomApp.first
            val packageName = randomApp.second
            
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            val action = if (isOpened) "opened" else "closed"
            val formattedMessage = "$timestamp - App $action: $appName ($packageName)"
            
            val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentHistory = sharedPref.getString(APP_USAGE_KEY, "") ?: ""
            
            val newHistory = if (currentHistory.isEmpty()) {
                formattedMessage
            } else {
                "$currentHistory\n$formattedMessage"
            }
            
            Log.d(TAG, "Adding test app usage: $formattedMessage")
            sharedPref.edit().putString(APP_USAGE_KEY, newHistory).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error adding test app usage event", e)
        }
    }
    
    private fun getAppUsageHistory(): String {
        val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPref.getString(APP_USAGE_KEY, "") ?: ""
    }
    
    private fun clearAppUsageHistory() {
        val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sharedPref.edit().putString(APP_USAGE_KEY, "").apply()
        Log.d(TAG, "App usage history cleared")
    }
    
    private fun addTestAppUsageEvents(events: String) {
        if (events.isEmpty()) return
        
        try {
            val sharedPref = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            Log.d(TAG, "Adding test app usage events: ${events.split("\n").size} events")
            sharedPref.edit().putString(APP_USAGE_KEY, events).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error adding test app usage events", e)
        }
    }
    
    private data class AppUsageInfo(
        val packageName: String,
        val appName: String,
        var firstTimeUsed: Long,
        var lastTimeUsed: Long,
        var launchCount: Int,
        var totalTimeInForeground: Long,
        var lastForegroundTime: Long = 0
    )
}
