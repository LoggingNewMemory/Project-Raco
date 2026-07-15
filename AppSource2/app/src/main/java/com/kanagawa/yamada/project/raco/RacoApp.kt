package com.kanagawa.yamada.project.raco

import androidx.compose.animation.Crossfade
import androidx.compose.runtime.*
import com.kanagawa.yamada.project.raco.screens.*

enum class Screen {
    Main,
    Utilities,
    Slingshot,
    About,
    Raco
}

@Composable
fun RacoApp() {
    var currentScreen by remember { mutableStateOf(Screen.Main) }

    Crossfade(targetState = currentScreen, label = "ScreenTransition") { screen ->
        when (screen) {
            Screen.Main -> MainScreen(onNavigate = { currentScreen = it })
            Screen.Utilities -> UtilitiesScreen(onBack = { currentScreen = Screen.Main })
            Screen.Slingshot -> SlingshotScreen(onBack = { currentScreen = Screen.Main })
            Screen.About -> AboutScreen(onBack = { currentScreen = Screen.Main })
            Screen.Raco -> RacoScreen(onBack = { currentScreen = Screen.Main })
        }
    }
}
