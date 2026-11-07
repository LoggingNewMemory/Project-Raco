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
import androidx.compose.animation.core.tween
import androidx.compose.animation.with
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.kanagawa.yamada.project.raco.*
import com.kanagawa.yamada.project.raco.gamemode.GameModeState
import com.kanagawa.yamada.project.raco.gamemode.ModeSwitchOverlay
import com.kanagawa.yamada.project.raco.gamemode.Ps4GameModeScreen

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
    val context = LocalContext.current
    // Restores the persisted Game Mode flag (idempotent).
    remember { GameModeState.init(context) }

    var currentScreen by remember { mutableStateOf(Screen.Main) }

    androidx.activity.compose.BackHandler(enabled = currentScreen != Screen.Main && !GameModeState.active) {
        currentScreen = Screen.Main
    }

    Box(Modifier.fillMaxSize()) {
        // Game Mode (PS4 theme) replaces the whole UI and stays until the user leaves it.
        Crossfade(
            targetState = GameModeState.active,
            animationSpec = tween(600),
            label = "GameModeTransition"
        ) { gameMode ->
            if (gameMode) {
                Ps4GameModeScreen(onExit = {
                    currentScreen = Screen.Main
                    GameModeState.setActive(context, false)
                })
            } else {
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
        }

        // Animated overlay for ECO / BALANCED / AWAKEN switches
        ModeSwitchOverlay(enabled = GameModeState.active || GameModeState.OVERLAY_OUTSIDE_GAME_MODE)
    }
}
