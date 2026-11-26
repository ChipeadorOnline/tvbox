package com.chipeadoronline.tvbox_updater

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.chipeadoronline.tvbox_updater/install"
    }

    @Suppress("DEPRECATION")
    private fun packageInfo(packageName: String): PackageInfo =
        packageManager.getPackageInfo(packageName, 0)

    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }

    private fun appInfo(packageName: String): Map<String, Any> = try {
        val info = packageInfo(packageName)
        mapOf(
            "installed" to true,
            "versionCode" to versionCode(info),
            "versionName" to (info.versionName ?: ""),
        )
    } catch (_: PackageManager.NameNotFoundException) {
        mapOf("installed" to false, "versionCode" to 0, "versionName" to "")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(packageManager.canRequestPackageInstalls())
                "openInstallSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName"),
                    )
                    startActivity(intent)
                    result.success(null)
                }
                "installedInfo" -> {
                    val target = call.argument<String>("packageName")
                    if (target.isNullOrEmpty()) {
                        result.error("NO_PACKAGE", "Falta packageName", null)
                    } else {
                        result.success(appInfo(target))
                    }
                }
                "ownVersion" -> result.success(
                    appInfo(packageName) + mapOf("packageName" to packageName),
                )
                "openApp" -> {
                    val target = call.argument<String>("packageName")
                    val launch = target?.let { packageManager.getLaunchIntentForPackage(it) }
                    if (launch == null) {
                        result.success(false)
                    } else {
                        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launch)
                        result.success(true)
                    }
                }
                "uninstall" -> {
                    val target = call.argument<String>("packageName")
                    if (target.isNullOrEmpty()) {
                        result.error("NO_PACKAGE", "Falta packageName", null)
                    } else {
                        val intent = Intent(
                            Intent.ACTION_DELETE,
                            Uri.parse("package:$target"),
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
