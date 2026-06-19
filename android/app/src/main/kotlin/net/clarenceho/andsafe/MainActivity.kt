package net.clarenceho.andsafe3

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
