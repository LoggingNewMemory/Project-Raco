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

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material.icons.filled.BlurOn
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.RocketLaunch
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kanagawa.yamada.project.raco.AboutScreen
import com.kanagawa.yamada.project.raco.R
import com.kanagawa.yamada.project.raco.RacoScreen
import com.kanagawa.yamada.project.raco.SlingshotScreen
import com.kanagawa.yamada.project.raco.UtilitiesPages.BypassChargingContent
import com.kanagawa.yamada.project.raco.UtilitiesPages.PixelSleepContent
import com.kanagawa.yamada.project.raco.UtilitiesScreen
import com.kanagawa.yamada.project.raco.WhitelistScreen

/** The pages that can be opened from the PS4 top bar. */
internal enum class Ps4Panel { PIXELSLEEP, BYPASS, LOOK, SETTINGS }

@Composable
internal fun panelTitle(panel: Ps4Panel): String = when (panel) {
    Ps4Panel.PIXELSLEEP -> stringResource(R.string.pixelsleep_title)
    Ps4Panel.BYPASS -> stringResource(R.string.bypass_title)
    Ps4Panel.LOOK -> stringResource(R.string.ps4_look)
    Ps4Panel.SETTINGS -> stringResource(R.string.ps4_all_settings)
}

internal fun panelIcon(panel: Ps4Panel): ImageVector = when (panel) {
    Ps4Panel.PIXELSLEEP -> Icons.Default.BlurOn
    Ps4Panel.BYPASS -> Icons.Default.BatteryChargingFull
    Ps4Panel.LOOK -> Icons.Default.Headphones
    Ps4Panel.SETTINGS -> Icons.Default.Settings
}

/**
 * The existing settings pages were designed for the app's own theme. Inside the PS4 panel they get
 * a dark blue color scheme derived from the selected PS4 theme so text and cards stay readable.
 */
@Composable
internal fun Ps4PanelTheme(content: @Composable () -> Unit) {
    val scheme = darkColorScheme(
        primary = Ps4Colors.Accent,
        onPrimary = Ps4Colors.Deep,
        primaryContainer = Ps4Colors.Mid,
        onPrimaryContainer = Color.White,
        secondary = Ps4Colors.Accent,
        onSecondary = Ps4Colors.Deep,
        secondaryContainer = Ps4Colors.Mid,
        onSecondaryContainer = Color.White,
        tertiary = Ps4Colors.Accent,
        background = Color.Transparent,
        onBackground = Color.White,
        surface = Ps4Colors.DeepAlt,
        onSurface = Color.White,
        surfaceVariant = Ps4Colors.Mid,
        onSurfaceVariant = Color(0xFFC7D4F5),
        outline = Color.White.copy(alpha = 0.35f),
        errorContainer = Color(0xFF5A1620),
        onErrorContainer = Color.White
    )
    MaterialTheme(colorScheme = scheme, typography = MaterialTheme.typography, shapes = MaterialTheme.shapes) {
        content()
    }
}

/** Full-page PS4 style panel that sits below the top bar. */
@Composable
internal fun Ps4PanelHost(panel: Ps4Panel, onClose: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Ps4Colors.Deep.copy(alpha = 0.94f), Ps4Colors.DeepAlt.copy(alpha = 0.97f))
                )
            )
            // swallow taps so nothing behind the panel reacts
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = {})
    ) {
        Column(Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onClose) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.ps4_back), tint = Color.White)
                }
                Icon(panelIcon(panel), null, tint = Ps4Colors.Accent, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Text(
                    panelTitle(panel),
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Light,
                    letterSpacing = 1.sp
                )
            }
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
                Box(Modifier.widthIn(max = 780.dp).fillMaxHeight().fillMaxWidth()) {
                    Ps4PanelTheme {
                        when (panel) {
                            Ps4Panel.PIXELSLEEP -> PixelSleepContent()
                            Ps4Panel.BYPASS -> BypassChargingContent()
                            Ps4Panel.LOOK -> Ps4SettingsContent()
                            Ps4Panel.SETTINGS -> Ps4SettingsMenu()
                        }
                    }
                }
            }
        }
    }
}

private enum class SettingsPage { UTILITIES, LAUNCHPAD, WHITELIST, RACO, ABOUT }

private class MenuEntry(val page: SettingsPage, val title: @Composable () -> String, val icon: ImageVector, val desc: @Composable () -> String?)

/** PS4-"Settings"-like list: every settings page of the app, opened inside Game Mode. */
@Composable
private fun Ps4SettingsMenu() {
    var page by remember { mutableStateOf<SettingsPage?>(null) }
    // takes priority over the screen-level back handler while a sub page is open
    BackHandler(enabled = page != null) { page = null }

    when (page) {
        SettingsPage.UTILITIES -> UtilitiesScreen(onBack = { page = null })
        SettingsPage.LAUNCHPAD -> SlingshotScreen(onBack = { page = null })
        SettingsPage.WHITELIST -> WhitelistScreen(onBack = { page = null })
        SettingsPage.RACO -> RacoScreen(onBack = { page = null })
        SettingsPage.ABOUT -> AboutScreen(onBack = { page = null })
        null -> {
            val entries = listOf(
                MenuEntry(SettingsPage.UTILITIES, { stringResource(R.string.utilities_title) }, Icons.Default.Build, { stringResource(R.string.ps4_menu_utilities_desc) }),
                MenuEntry(SettingsPage.LAUNCHPAD, { stringResource(R.string.slingshot_title) }, Icons.Default.RocketLaunch, { null }),
                MenuEntry(SettingsPage.WHITELIST, { stringResource(R.string.kill_all_whitelist) }, Icons.Default.List, { null }),
                MenuEntry(SettingsPage.RACO, { stringResource(R.string.ps4_menu_raco) }, Icons.Default.Person, { null }),
                MenuEntry(SettingsPage.ABOUT, { stringResource(R.string.ps4_menu_about) }, Icons.Default.Info, { null })
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                items(entries) { e ->
                    val shape = RoundedCornerShape(4.dp)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .clip(shape)
                            .background(Color.White.copy(alpha = 0.07f))
                            .border(1.dp, Color.White.copy(alpha = 0.15f), shape)
                            .clickable { page = e.page }
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(e.icon, null, tint = Ps4Colors.Accent, modifier = Modifier.size(26.dp))
                        Spacer(Modifier.width(16.dp))
                        Column(Modifier.weight(1f)) {
                            Text(e.title(), color = Color.White, fontSize = 16.sp)
                            e.desc()?.let {
                                Spacer(Modifier.height(2.dp))
                                Text(it, color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}
