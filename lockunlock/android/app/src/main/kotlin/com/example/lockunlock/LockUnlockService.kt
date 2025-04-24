package com.example.lockunlock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LockUnlockService : Service() {
    companion object {
        private const val TAG = "LockUnlockService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "lock_unlock_channel"
        private const val PREFS_NAME = "LockUnlockPrefs"
        private const val LOCK_HISTORY_KEY = "lock_history"
        private const val UNLOCK_HISTORY_KEY = "unlock_history"
    }
    
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen OFF")
                    logLockEvent(context)
                }
                Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG, "Screen ON")
                }
                Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "User present (Unlocked)")
                    logUnlockEvent(context)
                }
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        // Register for screen events
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        
        // Create notification channel for Android O and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Lock Unlock Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors device lock and unlock events"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
        
        // Create a notification for the foreground service
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Lock Unlock Monitor")
                .setContentText("Monitoring lock and unlock events")
                .setSmallIcon(R.drawable.ic_lock_idle_lock)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Lock Unlock Monitor")
                .setContentText("Monitoring lock and unlock events")
                .setSmallIcon(R.drawable.ic_lock_idle_lock)
                .setContentIntent(pendingIntent)
                .build()
        }
        
        startForeground(NOTIFICATION_ID, notification)
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(screenReceiver)
        Log.d(TAG, "Service destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    // Methods to log events
    private fun logLockEvent(context: Context) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
        val sharedPref = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentLockHistory = sharedPref.getString(LOCK_HISTORY_KEY, "") ?: ""
        
        val newLockHistory = if (currentLockHistory.isEmpty()) {
            timestamp
        } else {
            "$currentLockHistory\n$timestamp"
        }
        
        sharedPref.edit().putString(LOCK_HISTORY_KEY, newLockHistory).apply()
    }
    
    private fun logUnlockEvent(context: Context) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
        val sharedPref = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentUnlockHistory = sharedPref.getString(UNLOCK_HISTORY_KEY, "") ?: ""
        
        val newUnlockHistory = if (currentUnlockHistory.isEmpty()) {
            timestamp
        } else {
            "$currentUnlockHistory\n$timestamp"
        }
        
        sharedPref.edit().putString(UNLOCK_HISTORY_KEY, newUnlockHistory).apply()
    }
} 