package com.kanagawa.yamada.project.raco

import androidx.compose.animation.Crossfade
import androidx.compose.runtime.*
import com.kanagawa.yamada.project.raco.*

enum class Screen {
    Main,
    Utilities,
    Slingshot,
    Whitelist,
    About,
    Raco
}

@Composable
fun RacoApp() {
    var currentScreen by remember { mutableStateOf(Screen.Main) }

    androidx.activity.compose.BackHandler(enabled = currentScreen != Screen.Main) {
        currentScreen = Screen.Main
    }

    Crossfade(
        targetState = currentScreen,
        label = "ScreenTransition",
        animationSpec = androidx.compose.animation.core.tween(150)
    ) { screen ->
        when (screen) {
            Screen.Main -> MainScreen(onNavigate = { currentScreen = it })
            Screen.Utilities -> UtilitiesScreen(onBack = { currentScreen = Screen.Main })
            Screen.Slingshot -> SlingshotScreen(onBack = { currentScreen = Screen.Main })
            Screen.Whitelist -> WhitelistScreen(onBack = { currentScreen = Screen.Main })
            Screen.About -> AboutScreen(onBack = { currentScreen = Screen.Main })
            Screen.Raco -> RacoScreen(onBack = { currentScreen = Screen.Main })
        }
    }
}
