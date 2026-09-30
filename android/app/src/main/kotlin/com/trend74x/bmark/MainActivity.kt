package com.trend74x.bmark

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "bmark/source"
    private var initialSource: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialSource = resolveSource(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getShareSource" -> {
                        // The launch intent is only reported once so a later
                        // re-share is not attributed to the original source.
                        val source = initialSource
                        if (source != null) initialSource = null
                        result.success(source ?: resolveSource(intent))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    /**
     * Best-effort lookup of the app that sent the share intent, so a bookmark can
     * be attributed to Chrome / Instagram / TikTok and friends.
     *
     * Shares that go through the system share sheet report the chooser as referrer,
     * so the app name is only returned when it is a real, non-system package.
     */
    private fun resolveSource(intent: Intent?): String? {
        if (intent == null) return null
        val isShare = intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE ||
            intent.action == Intent.ACTION_VIEW
        if (!isShare) return null

        val explicitPackage = intent.`package`
        val candidate = referrerPackage(intent)
            ?: explicitPackage?.takeIf { it != packageName }
            ?: return null

        if (SYSTEM_REFERRERS.any { candidate.startsWith(it) }) return null

        return runCatching {
            val pm = applicationContext.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(candidate, 0)).toString()
        }.getOrDefault(candidate)
    }

    private fun referrerPackage(intent: Intent): String? {
        intent.getStringExtra(Intent.EXTRA_REFERRER)
            ?.substringAfter("//")
            ?.takeIf { it.isNotBlank() }
            ?.let { return it }

        getReferrer()?.schemeSpecificPart?.removePrefix("//")?.let { return it }
        return callingPackage
    }

    private companion object {
        /**
         * Shares that arrive through the system share sheet, adb or the launcher
         * report these as the referrer. They say nothing about the real source.
         */
        val SYSTEM_REFERRERS = listOf(
            "android", "com.android.systemui", "com.android.shell",
            "com.google.android.gms", "com.google.android.googlequicksearchbox"
        )
    }
}
