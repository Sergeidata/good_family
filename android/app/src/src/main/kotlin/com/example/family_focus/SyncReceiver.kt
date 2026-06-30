package com.example.family_focus

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SyncReceiver : BroadcastReceiver() {

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {

        android.util.Log.d(
            "SYNC_RECEIVER",
            "onReceive called"
        )

        try {

            SyncService.syncNowStatic(
                context
            )

            SyncService.scheduleNextAlarmStatic(
                context
            )

            android.util.Log.d(
                "SYNC_RECEIVER",
                "sync completed"
            )

        } catch (e: Exception) {

            android.util.Log.e(
                "SYNC_RECEIVER",
                "Error: ${e.message}",
                e
            )
        }
    }
}