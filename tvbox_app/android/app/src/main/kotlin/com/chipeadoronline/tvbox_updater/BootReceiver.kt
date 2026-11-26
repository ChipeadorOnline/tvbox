package com.chipeadoronline.tvbox_updater

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Si quedó una actualización pendiente, reabre la app al encender el TV Box
 * para que el usuario vea el aviso. Depende de las restricciones de Android
 * 12+ para iniciar activities desde segundo plano.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        if (!prefs.getBoolean("flutter.pending_catalog_update", false)) return
        try {
            val launch = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(launch)
        } catch (e: Exception) {
            Log.w("BootReceiver", "No se pudo abrir la app: ${e.message}")
        }
    }
}
