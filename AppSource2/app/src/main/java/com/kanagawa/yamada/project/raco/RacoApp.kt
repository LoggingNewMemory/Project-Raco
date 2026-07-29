package com.kanagawa.yamada.project.raco

import androidx.compose.animation.Crossfade
import androidx.compose.animation.with
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

@OptIn(androidx.compose.animation.ExperimentalAnimationApi::class)
@Composable
fun RacoApp() {
    var currentScreen by remember { mutableStateOf(Screen.Main) }

    androidx.activity.compose.BackHandler(enabled = currentScreen != Screen.Main) {
        currentScreen = Screen.Main
    }

    androidx.compose.animation.AnimatedContent(
        targetState = currentScreen,
        label = "ScreenTransition",
        transitionSpec = {
            androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(300)) with androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(300))
        }
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
