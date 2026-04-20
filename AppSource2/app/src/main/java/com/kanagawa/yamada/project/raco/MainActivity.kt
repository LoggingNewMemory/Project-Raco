package com.kanagawa.yamada.project.raco

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
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
    CHECKING_ROOT, NO_ROOT, ENTRANCE_ANIM, HOME_SCREEN
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Enable Immersive Full-Screen Mode
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        windowInsetsController.hide(WindowInsetsCompat.Type.systemBars())

        setContent {
            ProjectRacoTheme {
                var currentScreen by remember { mutableStateOf(ScreenState.CHECKING_ROOT) }

                LaunchedEffect(Unit) {
                    val isRooted = checkRootAccess()
                    currentScreen = if (isRooted) {
                        ScreenState.ENTRANCE_ANIM
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
                            Text(
                                "Root Access Denied. Project Raco requires Root.",
                                color = Color.Red,
                                modifier = Modifier.align(Alignment.Center)
                            )
                        }
                        ScreenState.ENTRANCE_ANIM -> {
                            EntranceAnim(onAnimComplete = {
                                currentScreen = ScreenState.HOME_SCREEN
                            })
                        }
                        ScreenState.HOME_SCREEN -> {
                            HomeScreen()
                        }
                    }
                }
            }
        }
    }

    private suspend fun checkRootAccess(): Boolean = withContext(Dispatchers.IO) {
        try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            process.waitFor() == 0
        } catch (e: Exception) {
            false
        }
    }
}