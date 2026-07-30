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
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
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
import kotlinx.coroutines.launch

// RacoSec imports
import com.kanagawa.yamada.project.raco.BuildConfig
import com.kanagawa.yamada.project.raco.security.RacoSecManager
import com.kanagawa.yamada.project.raco.security.RacoSecSetupScreen
import com.kanagawa.yamada.project.raco.security.SecCheckResult

enum class ScreenState {
    CHECKING_ROOT, ROOT_NOTICE, NO_ROOT, HOME_SCREEN,
    // RacoSec states
    CHECKING_LICENSE, LICENSE_SETUP, TAMPER_BLOCKED
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
            var bannerUpdateTrigger by remember { mutableStateOf(sharedPrefs.getLong("banner_update_timestamp", 0L)) }
            
            DisposableEffect(Unit) {
                bgImagePath = sharedPrefs.getString("background_image_path", "") ?: ""
                bgOpacity = sharedPrefs.getFloat("bg_opacity", 0.3f)
                bgBlur = sharedPrefs.getFloat("bg_blur", 10f)
                isAdaptiveEnabled = sharedPrefs.getBoolean("adaptive_color_enabled", false)
                bannerPath = sharedPrefs.getString("banner_image_path", "") ?: ""
                bannerUpdateTrigger = sharedPrefs.getLong("banner_update_timestamp", 0L)
                
                val listener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { prefs, key ->
                    when (key) {
                        "background_image_path" -> bgImagePath = prefs.getString(key, "") ?: ""
                        "bg_opacity" -> bgOpacity = prefs.getFloat(key, 0.3f)
                        "bg_blur" -> bgBlur = prefs.getFloat(key, 10f)
                        "adaptive_color_enabled" -> isAdaptiveEnabled = prefs.getBoolean(key, false)
                        "banner_image_path" -> bannerPath = prefs.getString(key, "") ?: ""
                        "banner_update_timestamp" -> bannerUpdateTrigger = prefs.getLong(key, 0L)
                    }
                }
                sharedPrefs.registerOnSharedPreferenceChangeListener(listener)
                onDispose {
                    sharedPrefs.unregisterOnSharedPreferenceChangeListener(listener)
                }
            }
            
            LaunchedEffect(isAdaptiveEnabled, bannerPath, bannerUpdateTrigger) {
                if (isAdaptiveEnabled) {
                    withContext(Dispatchers.IO) {
                        try {
                            val bitmap = if (bannerPath.isNotEmpty() && java.io.File(bannerPath).exists()) {
                                android.graphics.BitmapFactory.decodeFile(bannerPath)
                            } else {
                                android.graphics.BitmapFactory.decodeResource(context.resources, R.drawable.banner)
                            }
                            if (bitmap != null) {
                                val palette = androidx.palette.graphics.Palette.from(bitmap).generate()
                                val bestColor = palette.lightVibrantSwatch?.rgb
                                    ?: palette.vibrantSwatch?.rgb
                                    ?: palette.lightMutedSwatch?.rgb
                                    ?: palette.dominantSwatch?.rgb
                                    ?: android.graphics.Color.GRAY
                                adaptiveColor = Color(bestColor)
                            } else {
                                adaptiveColor = null
                            }
                        } catch (e: Exception) {
                            adaptiveColor = null
                        }
                    }
                } else {
                    adaptiveColor = null
                }
            }

            ProjectRacoTheme(darkTheme = true, seedColor = adaptiveColor) {
                var currentScreen by remember { mutableStateOf(ScreenState.CHECKING_LICENSE) }

                LaunchedEffect(Unit) {
                    // ── Step 1: Root check FIRST — user must grant before anything else ──
                    currentScreen = ScreenState.CHECKING_ROOT
                    val isRooted = checkRootAccess()
                    if (!isRooted) {
                        currentScreen = ScreenState.ROOT_NOTICE
                        return@LaunchedEffect
                    }

                    // ── Step 2: RacoSec license check (if LACCESS is enabled) ──
                    if (BuildConfig.LACCESS) {
                        currentScreen = ScreenState.CHECKING_LICENSE
                        val secResult = RacoSecManager.performStartupCheck(context, true)
                        when (secResult) {
                            is SecCheckResult.Clean,
                            is SecCheckResult.NetworkUnavailable -> { /* OK — continue */ }
                            is SecCheckResult.NotActivated -> {
                                currentScreen = ScreenState.LICENSE_SETUP
                                return@LaunchedEffect
                            }
                            is SecCheckResult.Tampered,
                            is SecCheckResult.ClonedBackup,
                            is SecCheckResult.WrongDevice -> {
                                currentScreen = ScreenState.TAMPER_BLOCKED
                                return@LaunchedEffect
                            }
                        }
                    }

                    currentScreen = ScreenState.HOME_SCREEN
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

                    androidx.compose.animation.Crossfade(
                        targetState = currentScreen,
                        label = "Screen Transition",
                        animationSpec = androidx.compose.animation.core.tween(durationMillis = 600)
                    ) { targetScreen ->
                        when (targetScreen) {
                            ScreenState.CHECKING_LICENSE,
                            ScreenState.CHECKING_ROOT -> { /* Black screen while checking */ }

                            ScreenState.ROOT_NOTICE,
                            ScreenState.NO_ROOT -> {
                                // Root Notice screen — upgraded from the original NO_ROOT state.
                                // Informs the user to grant root via their root manager, then restart.
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(MaterialTheme.colorScheme.background),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.spacedBy(16.dp),
                                        modifier = Modifier.padding(32.dp)
                                    ) {
                                        Text("🔐", style = MaterialTheme.typography.displayLarge)
                                        Text(
                                            "Root Access Required",
                                            style = MaterialTheme.typography.headlineSmall,
                                            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onBackground
                                        )
                                        Text(
                                            "Project Raco requires root access to function.\n" +
                                            "Please grant root permission via your root manager (Magisk / KernelSU / APatch), then restart the app.",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
                                            textAlign = TextAlign.Center
                                        )
                                    }
                                }
                            }

                            ScreenState.LICENSE_SETUP -> {
                                // Show the RacoSec activation screen
                                val scope = rememberCoroutineScope()
                                RacoSecSetupScreen(
                                    onActivationSuccess = {
                                        scope.launch {
                                            currentScreen = ScreenState.CHECKING_ROOT
                                            val isRooted = withContext(Dispatchers.IO) { checkRootAccess() }
                                            currentScreen = if (isRooted) ScreenState.HOME_SCREEN else ScreenState.NO_ROOT
                                        }
                                    }
                                )
                            }

                            ScreenState.TAMPER_BLOCKED -> {
                                // App should already be crashing from RacoSecManager.
                                // Fallback message if somehow we land here.
                                Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
                                    Text(
                                        "⛔",
                                        color = Color.Red,
                                        modifier = Modifier.align(Alignment.Center),
                                        textAlign = TextAlign.Center
                                    )
                                }
                            }

                            ScreenState.HOME_SCREEN -> {
                                RacoApp()
                            }
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
            }
            isRooted
        } catch (e: Exception) {
            false
        }
    }
}