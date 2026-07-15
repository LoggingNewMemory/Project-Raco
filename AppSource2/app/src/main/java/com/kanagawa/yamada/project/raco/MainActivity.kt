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
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.kanagawa.yamada.project.raco.ui.theme.ProjectRacoTheme
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
            ProjectRacoTheme(darkTheme = true) {
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
                        .background(Color(0xFF050505)) // Deep black background
                ) {
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