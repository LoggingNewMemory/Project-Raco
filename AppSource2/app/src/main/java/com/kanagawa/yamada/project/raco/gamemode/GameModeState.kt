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

package com.kanagawa.yamada.project.raco.gamemode

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color

/**
 * Global switch for the PS4-style "Game Mode" theme.
 *
 * The flag is persisted in SharedPreferences so the theme survives app restarts
 * and stays active until the user explicitly leaves it.
 */
object GameModeState {

    /** Set to true if you also want the mode-switch overlay in the normal UI. */
    const val OVERLAY_OUTSIDE_GAME_MODE = false

    private const val PREFS = "raco_app_config"
    private const val KEY_ACTIVE = "ps4_game_mode_active"

    var active by mutableStateOf(false)
        private set

    private var initialized = false

    fun init(context: Context) {
        if (initialized) return
        initialized = true
        Ps4Settings.init(context)
        active = prefs(context).getBoolean(KEY_ACTIVE, false)
    }

    fun setActive(context: Context, value: Boolean) {
        active = value
        prefs(context).edit().putBoolean(KEY_ACTIVE, value).apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** PS4 "dynamic theme" inspired palette. Deep/Mid/Bright/Accent follow the selected theme. */
object Ps4Colors {
    val Deep: Color get() = Ps4Settings.theme.deep
    val DeepAlt: Color get() = Ps4Settings.theme.deepAlt
    val Mid: Color get() = Ps4Settings.theme.mid
    val Bright: Color get() = Ps4Settings.theme.bright
    val Accent: Color get() = Ps4Settings.theme.accent

    // Mode colors stay fixed so ECO / BALANCED / AWAKEN are always recognisable
    val Eco = Color(0xFF3DE0A8)
    val Balanced = Color(0xFF63A4FF)
    val Awaken = Color(0xFFFF5470)
}

internal fun Context.findActivity(): Activity? {
    var c: Context = this
    while (c is ContextWrapper) {
        if (c is Activity) return c
        c = c.baseContext
    }
    return null
}
