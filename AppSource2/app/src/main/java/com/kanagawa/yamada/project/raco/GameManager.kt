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
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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

    fun getManuallyAddedGames(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_CUSTOM_GAMES, emptySet()) ?: emptySet()
    }

    fun addGame(context: Context, packageName: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentGames = prefs.getStringSet(KEY_CUSTOM_GAMES, emptySet())?.toMutableSet() ?: mutableSetOf()
        currentGames.add(packageName)
        prefs.edit().putStringSet(KEY_CUSTOM_GAMES, currentGames).apply()
    }

    fun removeGame(context: Context, packageName: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentGames = prefs.getStringSet(KEY_CUSTOM_GAMES, emptySet())?.toMutableSet() ?: mutableSetOf()
        currentGames.remove(packageName)
        prefs.edit().putStringSet(KEY_CUSTOM_GAMES, currentGames).apply()
    }

    suspend fun getAllInstalledApps(context: Context): List<AppInfo> = withContext(Dispatchers.IO) {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val appList = mutableListOf<AppInfo>()

        for (app in apps) {
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

// ── UI Components ─────────────────────────────────────────────────────────

@Composable
fun GamePickerScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var appList by remember { mutableStateOf<List<AppInfo>>(emptyList()) }
    var addedGames by remember { mutableStateOf<Set<String>>(emptySet()) }
    var isLoading by remember { mutableStateOf(true) }

    // Updated colors to match HomeScreen's deep black
    val bgColor = Color(0xFF0A0A0A)
    val topBarColor = Color(0xFF0A0A0A)
    val dividerColor = Color(0xFF1A1A1A)

    val gilmerLight = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerLight.otf")))
    }

    BackHandler { onBack() }

    LaunchedEffect(Unit) {
        appList = GameManager.getAllInstalledApps(context)
        addedGames = GameManager.getManuallyAddedGames(context)
        isLoading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(bgColor)
            .displayCutoutPadding()
    ) {
        // Top Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(topBarColor)
                .padding(horizontal = 16.dp, vertical = 20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = Color.White,
                modifier = Modifier
                    .size(28.dp)
                    .clickable { onBack() }
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = "Add Games",
                color = Color.White,
                fontSize = 20.sp,
                fontFamily = gilmerLight,
                fontWeight = FontWeight.Bold
            )
        }

        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Color.White)
            }
        } else {
            val addedList = appList.filter { it.packageName in addedGames }
            val notAddedList = appList.filter { it.packageName !in addedGames }

            LazyColumn(modifier = Modifier.fillMaxSize()) {
                // ADDED SECTION
                if (addedList.isNotEmpty()) {
                    item {
                        Text(
                            text = "${addedList.size} Added",
                            color = Color.LightGray,
                            fontSize = 14.sp,
                            fontFamily = gilmerLight,
                            modifier = Modifier.padding(start = 16.dp, top = 24.dp, bottom = 12.dp)
                        )
                    }
                    items(addedList) { app ->
                        AppListItem(
                            app = app,
                            isAdded = true,
                            fontFamily = gilmerLight,
                            onToggle = { isIncluded ->
                                if (isIncluded) {
                                    GameManager.addGame(context, app.packageName)
                                    addedGames = addedGames + app.packageName
                                } else {
                                    GameManager.removeGame(context, app.packageName)
                                    addedGames = addedGames - app.packageName
                                }
                            }
                        )
                        HorizontalDivider(color = dividerColor, thickness = 1.dp)
                    }
                }

                // NOT ADDED SECTION
                if (notAddedList.isNotEmpty()) {
                    item {
                        Text(
                            text = "${notAddedList.size} Not added",
                            color = Color.LightGray,
                            fontSize = 14.sp,
                            fontFamily = gilmerLight,
                            modifier = Modifier.padding(start = 16.dp, top = 24.dp, bottom = 12.dp)
                        )
                    }
                    items(notAddedList) { app ->
                        AppListItem(
                            app = app,
                            isAdded = false,
                            fontFamily = gilmerLight,
                            onToggle = { isIncluded ->
                                if (isIncluded) {
                                    GameManager.addGame(context, app.packageName)
                                    addedGames = addedGames + app.packageName
                                } else {
                                    GameManager.removeGame(context, app.packageName)
                                    addedGames = addedGames - app.packageName
                                }
                            }
                        )
                        HorizontalDivider(color = dividerColor, thickness = 1.dp)
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(32.dp))
                }
            }
        }
    }
}

@Composable
fun AppListItem(app: AppInfo, isAdded: Boolean, fontFamily: FontFamily, onToggle: (Boolean) -> Unit) {
    val excludeBgColor by animateColorAsState(if (!isAdded) Color(0xFF333544) else Color.Transparent, label = "excludeBg")
    val excludeTextColor by animateColorAsState(if (!isAdded) Color.White else Color.Gray, label = "excludeText")

    val includeBgColor by animateColorAsState(if (isAdded) Color(0xFFC62828) else Color.Transparent, label = "includeBg")
    val includeTextColor by animateColorAsState(if (isAdded) Color.White else Color.Gray, label = "includeText")

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        // Fetch the original system icon without any unmasking or reshaping
        val imageBitmap = remember(app.icon) { getOriginalImageBitmap(app.icon) }
        if (imageBitmap != null) {
            Image(
                bitmap = imageBitmap,
                contentDescription = app.name,
                modifier = Modifier.size(48.dp) // Rendered in original shape, no clip or crop
            )
        }

        Text(
            text = app.name,
            color = Color.White,
            fontSize = 16.sp,
            fontFamily = fontFamily,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 16.dp)
        )

        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF20222D))
                .padding(2.dp)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(excludeBgColor)
                    .clickable { onToggle(false) }
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("Exclude", color = excludeTextColor, fontSize = 13.sp, fontFamily = fontFamily)
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(includeBgColor)
                    .clickable { onToggle(true) }
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("Include", color = includeTextColor, fontSize = 13.sp, fontFamily = fontFamily)
            }
        }
    }
}

// Uniquely named standard fallback extractor to render whatever original shape the OS provides
fun getOriginalImageBitmap(drawable: Drawable): ImageBitmap? {
    try {
        if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap.asImageBitmap()
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 256
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 256
        val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap.asImageBitmap()
    } catch (e: Exception) { return null }
}