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

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class AppInfo(
    val name: String,
    val packageName: String,
    val icon: Drawable
)

object GameManager {
    private const val PREFS_NAME = "raco_prefs"
    private const val KEY_CUSTOM_GAMES = "custom_games"

    /** Retrieves the package names of games the user manually added */
    fun getManuallyAddedGames(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_CUSTOM_GAMES, emptySet()) ?: emptySet()
    }

    /** Saves a new manually added game */
    fun addGame(context: Context, packageName: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentGames = prefs.getStringSet(KEY_CUSTOM_GAMES, emptySet())?.toMutableSet() ?: mutableSetOf()
        currentGames.add(packageName)
        prefs.edit().putStringSet(KEY_CUSTOM_GAMES, currentGames).apply()
    }

    /** Removes a game from the custom list */
    fun removeGame(context: Context, packageName: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentGames = prefs.getStringSet(KEY_CUSTOM_GAMES, emptySet())?.toMutableSet() ?: mutableSetOf()
        currentGames.remove(packageName)
        prefs.edit().putStringSet(KEY_CUSTOM_GAMES, currentGames).apply()
    }

    /** Fetches all user-installed applications (filtering out bloatware/system apps) */
    suspend fun getAllInstalledApps(context: Context): List<AppInfo> = withContext(Dispatchers.IO) {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val appList = mutableListOf<AppInfo>()

        for (app in apps) {
            // Only show user-installed apps, exclude core system apps
            if ((app.flags and ApplicationInfo.FLAG_SYSTEM) == 0 || (app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0) {
                val name = app.loadLabel(pm).toString()
                val packageName = app.packageName
                val icon = app.loadIcon(pm)
                appList.add(AppInfo(name, packageName, icon))
            }
        }
        appList.sortedBy { it.name.lowercase() }
    }
}