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

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import java.io.File

class Ps4Theme(
    val id: String,
    val name: String,
    val deep: Color,
    val deepAlt: Color,
    val mid: Color,
    val bright: Color,
    val accent: Color
)

object Ps4Themes {
    val all = listOf(
        Ps4Theme("classic", "Classic Blue", Color(0xFF020B26), Color(0xFF04164A), Color(0xFF0B2A78), Color(0xFF2B6BFF), Color(0xFF63A4FF)),
        Ps4Theme("midnight", "Midnight", Color(0xFF05060D), Color(0xFF0B0F24), Color(0xFF161D45), Color(0xFF4458C9), Color(0xFF8EA0FF)),
        Ps4Theme("violet", "Violet", Color(0xFF12041F), Color(0xFF260A45), Color(0xFF4A1D8F), Color(0xFF8A4DFF), Color(0xFFC19BFF)),
        Ps4Theme("sunset", "Sunset", Color(0xFF1F0612), Color(0xFF3D0F2A), Color(0xFF8A2C4C), Color(0xFFFF6B4A), Color(0xFFFFB07A)),
        Ps4Theme("emerald", "Emerald", Color(0xFF021A14), Color(0xFF04302A), Color(0xFF0B6B58), Color(0xFF1FD6A4), Color(0xFF7DF0CF)),
        Ps4Theme("crimson", "Crimson", Color(0xFF1A0306), Color(0xFF380A10), Color(0xFF7A1424), Color(0xFFFF3B55), Color(0xFFFF8FA0))
    )

    fun byId(id: String): Ps4Theme = all.firstOrNull { it.id == id } ?: all[0]
}

/** Persisted look & sound preferences of the PS4 Game Mode. */
object Ps4Settings {
    private const val PREFS = "raco_app_config"

    var themeId by mutableStateOf("classic")
        private set
    var useCustomImage by mutableStateOf(false)
        private set
    var bgImagePath by mutableStateOf("")
        private set
    var sfxEnabled by mutableStateOf(true)
        private set
    var musicEnabled by mutableStateOf(true)
        private set
    var customMusicPath by mutableStateOf("")
        private set
    var volume by mutableFloatStateOf(0.6f)
        private set

    val theme: Ps4Theme get() = Ps4Themes.byId(themeId)

    private var initialized = false

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun init(context: Context) {
        if (initialized) return
        initialized = true
        val p = prefs(context)
        themeId = p.getString("ps4_theme", "classic") ?: "classic"
        useCustomImage = p.getBoolean("ps4_use_image", false)
        bgImagePath = p.getString("ps4_bg_image", "") ?: ""
        sfxEnabled = p.getBoolean("ps4_sfx", true)
        musicEnabled = p.getBoolean("ps4_music", true)
        customMusicPath = p.getString("ps4_music_custom", "") ?: ""
        volume = p.getFloat("ps4_volume", 0.6f)
        if (useCustomImage && (bgImagePath.isEmpty() || !File(bgImagePath).exists())) useCustomImage = false
    }

    fun setTheme(context: Context, id: String) {
        themeId = id
        prefs(context).edit().putString("ps4_theme", id).apply()
    }

    fun setUseCustomImage(context: Context, value: Boolean) {
        useCustomImage = value && bgImagePath.isNotEmpty()
        prefs(context).edit().putBoolean("ps4_use_image", useCustomImage).apply()
    }

    fun setCustomImage(context: Context, path: String) {
        val old = bgImagePath
        bgImagePath = path
        useCustomImage = true
        prefs(context).edit().putString("ps4_bg_image", path).putBoolean("ps4_use_image", true).apply()
        if (old.isNotEmpty() && old != path) try { File(old).delete() } catch (_: Exception) {}
    }

    fun setSfx(context: Context, value: Boolean) {
        sfxEnabled = value
        prefs(context).edit().putBoolean("ps4_sfx", value).apply()
    }

    fun setMusic(context: Context, value: Boolean) {
        musicEnabled = value
        prefs(context).edit().putBoolean("ps4_music", value).apply()
    }

    fun setCustomMusic(context: Context, path: String) {
        val old = customMusicPath
        customMusicPath = path
        prefs(context).edit().putString("ps4_music_custom", path).apply()
        if (old.isNotEmpty() && old != path) try { File(old).delete() } catch (_: Exception) {}
    }

    fun setVolume(context: Context, v: Float) {
        volume = v.coerceIn(0f, 1f)
        prefs(context).edit().putFloat("ps4_volume", volume).apply()
    }
}
