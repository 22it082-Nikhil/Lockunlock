package com.example.lockunlock

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DeviceAdminReceiver : DeviceAdminReceiver() {
    companion object {
        private const val TAG = "DeviceAdminReceiver"
        private const val PREFS_NAME = "LockUnlockPrefs"
        private const val LOCK_HISTORY_KEY = "lock_history"
        private const val UNLOCK_HISTORY_KEY = "unlock_history"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device admin enabled")
        logEvent(context, "Device admin enabled", false)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device admin disabled")
        logEvent(context, "Device admin disabled", false)
    }

    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.d(TAG, "Password changed")
    }

    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.d(TAG, "Password failed")
    }

    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        Log.d(TAG, "Password succeeded - device unlocked")
        logUnlockEvent(context)
    }

    // This is usually not triggered for normal device lock, let's try other methods
    override fun onLockTaskModeEntering(context: Context, intent: Intent, pkg: String) {
        super.onLockTaskModeEntering(context, intent, pkg)
        logLockEvent(context)
        Log.d(TAG, "Device locked via lock task mode")
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        Log.d(TAG, "DeviceAdminReceiver onReceive: ${intent.action}")
        
        // Additional handlers for screen events
        when (intent.action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "Screen OFF detected in DeviceAdminReceiver")
                logLockEvent(context)
            }
            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "Screen ON detected in DeviceAdminReceiver")
            }
            Intent.ACTION_USER_PRESENT -> {
                Log.d(TAG, "User present (Unlocked) detected in DeviceAdminReceiver")
                logUnlockEvent(context)
            }
        }
    }

    // Custom methods to log events
    private fun logLockEvent(context: Context) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
        val sharedPref = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentLockHistory = sharedPref.getString(LOCK_HISTORY_KEY, "") ?: ""
        
        val newLockHistory = if (currentLockHistory.isEmpty()) {
            timestamp
        } else {
            "$currentLockHistory\n$timestamp"
        }
        
        Log.d(TAG, "Logging lock event: $timestamp")
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
        
        Log.d(TAG, "Logging unlock event: $timestamp")
        sharedPref.edit().putString(UNLOCK_HISTORY_KEY, newUnlockHistory).apply()
    }
    
    private fun logEvent(context: Context, message: String, isLock: Boolean) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
        val formattedMessage = "$timestamp - $message"
        val sharedPref = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        val key = if (isLock) LOCK_HISTORY_KEY else UNLOCK_HISTORY_KEY
        val currentHistory = sharedPref.getString(key, "") ?: ""
        
        val newHistory = if (currentHistory.isEmpty()) {
            formattedMessage
        } else {
            "$currentHistory\n$formattedMessage"
        }
        
        sharedPref.edit().putString(key, newHistory).apply()
    }
} 