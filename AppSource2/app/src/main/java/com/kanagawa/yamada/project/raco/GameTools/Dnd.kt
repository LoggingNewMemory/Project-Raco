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

package com.kanagawa.yamada.project.raco.GameTools

import androidx.compose.runtime.MutableState

object DndTool {
    fun toggle(
        currentPackage: String,
        activeDndState: MutableState<Boolean>,
        sharedPrefs: android.content.SharedPreferences
    ) {
        val newState = !activeDndState.value
        activeDndState.value = newState
        sharedPrefs.edit().putBoolean("dnd_active_$currentPackage", newState).apply()
        
        if (newState) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd notification set_dnd priority")).waitFor()
        } else {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd notification set_dnd off")).waitFor()
        }
    }
}
