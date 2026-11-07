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
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.kanagawa.yamada.project.raco.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** Copies a picked content Uri into app storage and returns the new file path (or null). */
private fun copyPickedFile(context: Context, uri: Uri, prefix: String): String? {
    return try {
        val out = File(context.filesDir, "${prefix}_${System.currentTimeMillis()}")
        context.contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { input.copyTo(it) }
        } ?: return null
        out.absolutePath
    } catch (e: Exception) {
        null
    }
}

/** Theme / background / sound settings as a dialog (kept for callers that want a pop-up). */
@Composable
fun Ps4SettingsDialog(onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(24.dp))
                .background(Brush.verticalGradient(listOf(Ps4Colors.DeepAlt, Ps4Colors.Deep)))
                .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(24.dp))
                .heightIn(max = 520.dp)
        ) {
            Ps4SettingsContent(onClose = onDismiss)
        }
    }
}

/** Theme / background / sound settings; used inside the PS4 panel and the dialog. */
@Composable
fun Ps4SettingsContent(onClose: (() -> Unit)? = null, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val path = withContext(Dispatchers.IO) { copyPickedFile(context, uri, "ps4_bg") }
                if (path != null) Ps4Settings.setCustomImage(context, path)
            }
        }
    }
    val musicPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val path = withContext(Dispatchers.IO) { copyPickedFile(context, uri, "ps4_music") }
                if (path != null) {
                    Ps4Settings.setCustomMusic(context, path)
                    Ps4Audio.refreshMusic()
                }
            }
        }
    }

    run {
        Column(
            modifier = modifier
                .verticalScroll(rememberScrollState())
                .padding(20.dp)
        ) {
            Text(
                stringResource(R.string.ps4_settings),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Light,
                letterSpacing = 1.sp
            )

            // ---------------- theme
            SectionTitle(stringResource(R.string.ps4_theme))
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                for (t in Ps4Themes.all) {
                    val selected = Ps4Settings.themeId == t.id
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(Brush.linearGradient(listOf(t.bright, t.mid, t.deep)))
                                .border(if (selected) 3.dp else 1.dp, if (selected) Color.White else Color.White.copy(alpha = 0.3f), CircleShape)
                                .clickable { Ps4Settings.setTheme(context, t.id) },
                            contentAlignment = Alignment.Center
                        ) {
                            if (selected) Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
                        }
                        Spacer(Modifier.height(4.dp))
                        Text(t.name, color = Color.White.copy(alpha = 0.75f), fontSize = 10.sp, maxLines = 1)
                    }
                }
            }

            // ---------------- custom background
            SectionTitle(stringResource(R.string.ps4_bg_image))
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(onClick = { imagePicker.launch("image/*") }) {
                    Icon(Icons.Default.Image, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.ps4_bg_pick), color = Color.White)
                }
            }
            if (Ps4Settings.bgImagePath.isNotEmpty()) {
                ToggleRow(
                    label = stringResource(R.string.ps4_bg_use),
                    checked = Ps4Settings.useCustomImage
                ) { Ps4Settings.setUseCustomImage(context, it) }
            }

            // ---------------- sound
            SectionTitle(stringResource(R.string.ps4_sound))
            ToggleRow(stringResource(R.string.ps4_sfx), Ps4Settings.sfxEnabled) { Ps4Settings.setSfx(context, it) }
            ToggleRow(stringResource(R.string.ps4_music), Ps4Settings.musicEnabled) {
                Ps4Settings.setMusic(context, it)
                Ps4Audio.refreshMusic()
            }
            if (Ps4Settings.musicEnabled) {
                val custom = Ps4Settings.customMusicPath
                Text(
                    text = if (custom.isEmpty()) stringResource(R.string.ps4_music_source_default) else File(custom).name,
                    color = Color.White.copy(alpha = 0.6f),
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 4.dp)
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { musicPicker.launch("audio/*") }) {
                        Text(stringResource(R.string.ps4_music_pick), color = Ps4Colors.Accent)
                    }
                    if (custom.isNotEmpty()) {
                        TextButton(onClick = {
                            Ps4Settings.setCustomMusic(context, "")
                            Ps4Audio.refreshMusic()
                        }) { Text(stringResource(R.string.ps4_music_reset), color = Ps4Colors.Accent) }
                    }
                }
            }
            Text(stringResource(R.string.ps4_volume), color = Color.White.copy(alpha = 0.8f), fontSize = 13.sp)
            Slider(
                value = Ps4Settings.volume,
                onValueChange = {
                    Ps4Settings.setVolume(context, it)
                    Ps4Audio.updateVolume()
                },
                valueRange = 0f..1f,
                colors = SliderDefaults.colors(
                    thumbColor = Color.White,
                    activeTrackColor = Ps4Colors.Accent,
                    inactiveTrackColor = Color.White.copy(alpha = 0.2f)
                )
            )

            if (onClose != null) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onClose) { Text(stringResource(R.string.ps4_close), color = Color.White) }
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Spacer(Modifier.height(18.dp))
    Text(
        text.uppercase(),
        color = Ps4Colors.Accent,
        fontSize = 11.sp,
        letterSpacing = 3.sp,
        modifier = Modifier.padding(bottom = 8.dp)
    )
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, color = Color.White, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Ps4Colors.Bright,
                uncheckedTrackColor = Color.White.copy(alpha = 0.2f)
            )
        )
    }
}
