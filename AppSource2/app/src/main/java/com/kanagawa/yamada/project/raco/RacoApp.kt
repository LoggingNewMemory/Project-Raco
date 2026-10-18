/*
 * Project Raco - Performance and Gaming Optimization Suite
 * Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

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
