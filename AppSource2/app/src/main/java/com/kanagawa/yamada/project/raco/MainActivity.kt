/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada
This program is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.

If not, see https://www.gnu.org/licenses/.
*/

package com.kanagawa.yamada.project.raco

import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.MaterialTheme
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.kanagawa.yamada.project.raco.ui.theme.ProjectRacoTheme
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

enum class ScreenState {
    CHECKING_ROOT, NO_ROOT, HOME_SCREEN
}

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()


        // ── Auto Notch Detector / Full Screen Mode ──
        // Allow the app window to extend into the display cutout (notch) area.
        // Compose will handle the safe padding internally.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        setContent {
            val context = androidx.compose.ui.platform.LocalContext.current
            var bgImagePath by remember { mutableStateOf("") }
            var bgOpacity by remember { mutableFloatStateOf(0.3f) }
            var bgBlur by remember { mutableFloatStateOf(10f) }
            var adaptiveColor by remember { mutableStateOf<Color?>(null) }
            var isAdaptiveEnabled by remember { mutableStateOf(false) }
            
            val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
            var bannerPath by remember { mutableStateOf(sharedPrefs.getString("banner_image_path", "") ?: "") }
            
            DisposableEffect(Unit) {
                bgImagePath = sharedPrefs.getString("background_image_path", "") ?: ""
                bgOpacity = sharedPrefs.getFloat("bg_opacity", 0.3f)
                bgBlur = sharedPrefs.getFloat("bg_blur", 10f)
                isAdaptiveEnabled = sharedPrefs.getBoolean("adaptive_color_enabled", false)
                bannerPath = sharedPrefs.getString("banner_image_path", "") ?: ""
                
                val listener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { prefs, key ->
                    when (key) {
                        "background_image_path" -> bgImagePath = prefs.getString(key, "") ?: ""
                        "bg_opacity" -> bgOpacity = prefs.getFloat(key, 0.3f)
                        "bg_blur" -> bgBlur = prefs.getFloat(key, 10f)
                        "adaptive_color_enabled" -> isAdaptiveEnabled = prefs.getBoolean(key, false)
                        "banner_image_path" -> bannerPath = prefs.getString(key, "") ?: ""
                    }
                }
                sharedPrefs.registerOnSharedPreferenceChangeListener(listener)
                onDispose {
                    sharedPrefs.unregisterOnSharedPreferenceChangeListener(listener)
                }
            }
            
            LaunchedEffect(isAdaptiveEnabled, bannerPath) {
                if (isAdaptiveEnabled && bannerPath.isNotEmpty() && java.io.File(bannerPath).exists()) {
                    withContext(Dispatchers.IO) {
                        try {
                            val bitmap = android.graphics.BitmapFactory.decodeFile(bannerPath)
                            val scaled = android.graphics.Bitmap.createScaledBitmap(bitmap, 1, 1, true)
                            val pixel = scaled.getPixel(0, 0)
                            adaptiveColor = Color(pixel)
                        } catch (e: Exception) {
                            adaptiveColor = null
                        }
                    }
                } else {
                    adaptiveColor = null
                }
            }

            ProjectRacoTheme(darkTheme = true, seedColor = adaptiveColor) {
                var currentScreen by remember { mutableStateOf(ScreenState.CHECKING_ROOT) }

                LaunchedEffect(Unit) {
                    val isRooted = checkRootAccess()
                    currentScreen = if (isRooted) {
                        ScreenState.HOME_SCREEN
                    } else {
                        ScreenState.NO_ROOT
                    }
                }

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.background)
                ) {
                    if (bgImagePath.isNotEmpty() && java.io.File(bgImagePath).exists()) {
                        coil.compose.AsyncImage(
                            model = bgImagePath,
                            contentDescription = "Background",
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxSize()
                                .alpha(bgOpacity)
                                .blur(bgBlur.dp)
                        )
                    }

                    when (currentScreen) {
                        ScreenState.CHECKING_ROOT -> { } // Black screen while Magisk prompts
                        ScreenState.NO_ROOT -> {
                            Text(stringResource(R.string.root_access_denied_project_raco_requires_root),
                                color = Color.Red,
                                modifier = Modifier.align(Alignment.Center)
                            )
                        }
                        // Removed ENTRANCE_ANIM
                        ScreenState.HOME_SCREEN -> {
                            RacoApp()
                        }
                    }
                }
            }
        }
    }

    private suspend fun checkRootAccess(): Boolean = withContext(Dispatchers.IO) {
        try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            val isRooted = process.waitFor() == 0
            if (isRooted) {
                // Grant SYSTEM_ALERT_WINDOW permission for the game overlay service
                Runtime.getRuntime().exec(arrayOf("su", "-c", "appops set com.kanagawa.yamada.project.raco SYSTEM_ALERT_WINDOW allow")).waitFor()
                // Grant GET_USAGE_STATS to allow polling the foreground app for the in-game menu
                Runtime.getRuntime().exec(arrayOf("su", "-c", "appops set com.kanagawa.yamada.project.raco GET_USAGE_STATS allow")).waitFor()
                // Removed AutoGameMonitorService

            }
            isRooted
        } catch (e: Exception) {
            false
        }
    }
}