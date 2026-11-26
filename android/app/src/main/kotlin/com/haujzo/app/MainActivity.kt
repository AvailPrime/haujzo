package com.haujzo.app

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity

@Suppress("NewApi", "Unused")
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        seedDebugAppCheckTokenIfDebuggable()
        super.onCreate(savedInstanceState)
    }

    private fun seedDebugAppCheckTokenIfDebuggable() {
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) return

        val debugSecret = "955ae9a9-10ef-467b-8c0f-970cc5331f88"
        val appId = "1:674897217546:android:2e3095bec125fc5c7777f3"
        val flags = Base64.NO_PADDING or Base64.NO_WRAP or Base64.URL_SAFE
        val encodedName = Base64.encodeToString("[DEFAULT]".toByteArray(Charsets.UTF_8), flags)
        val encodedAppId = Base64.encodeToString(appId.toByteArray(Charsets.UTF_8), flags)
        val prefsName = "com.google.firebase.appcheck.debug.store.$encodedName+$encodedAppId"

        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", debugSecret)
            .apply()
    }
}
