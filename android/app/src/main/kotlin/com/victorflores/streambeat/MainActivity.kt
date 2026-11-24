package com.victorflores.streambeat

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ ya dibuja de borde a borde; esto lo iguala en versiones
        // anteriores, como pide Google Play para apps con targetSdk 35+.
        WindowCompat.enableEdgeToEdge(window)
        super.onCreate(savedInstanceState)
    }
}
