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

package com.kanagawa.yamada.project.raco.UtilitiesPages

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BlurOn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kanagawa.yamada.project.raco.R
import com.kanagawa.yamada.project.raco.tools.PixelSleepController
import com.kanagawa.yamada.project.raco.ui.theme.GlassCard
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PixelSleepScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.pixelsleep_title)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = MaterialTheme.colorScheme.primary,
                    navigationIconContentColor = MaterialTheme.colorScheme.primary
                )
            )
        },
        containerColor = Color.Transparent
    ) { padding ->
        PixelSleepContent(Modifier.padding(padding))
    }
}

/** The PixelSleep settings; shared by the Utilities page and the PS4 Game Mode panel. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PixelSleepContent(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var enabled by remember { mutableStateOf(PixelSleepController.isEnabled(context)) }
    var percent by remember { mutableFloatStateOf(PixelSleepController.percent(context).toFloat()) }
    var size by remember { mutableIntStateOf(PixelSleepController.size(context)) }
    var hasPermission by remember { mutableStateOf(Settings.canDrawOverlays(context)) }

    // Keeps the screen in sync with the Game Assistant switch and with the permission screen.
    LaunchedEffect(Unit) {
        while (true) {
            hasPermission = Settings.canDrawOverlays(context)
            enabled = PixelSleepController.isEnabled(context)
            delay(1000)
        }
    }

    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 8.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(bottom = 32.dp)
    ) {
        if (!hasPermission) {
            item {
                GlassCard(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.pixelsleep_perm_title), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.pixelsleep_perm_desc), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(8.dp))
                        Button(onClick = {
                            context.startActivity(
                                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }) { Text(stringResource(R.string.pixelsleep_perm_btn)) }
                    }
                }
            }
        }

        // ---- master switch
        item {
            GlassCard(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
            ) {
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.BlurOn, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
                    Spacer(Modifier.width(16.dp))
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.pixelsleep_enable), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(2.dp))
                        Text(stringResource(R.string.pixelsleep_enable_desc), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Spacer(Modifier.width(8.dp))
                    Switch(
                        checked = enabled,
                        onCheckedChange = {
                            enabled = it
                            PixelSleepController.setEnabled(context, it)
                        }
                    )
                }
            }
        }

        // ---- amount
        item {
            GlassCard(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text(stringResource(R.string.pixelsleep_amount), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    val p = percent.roundToInt()
                    Text(
                        stringResource(R.string.pixelsleep_amount_value, p, (100f / p).roundToInt().coerceAtLeast(2)),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Slider(
                        value = percent,
                        onValueChange = {
                            percent = it
                            PixelSleepController.preview(it.roundToInt(), size)
                        },
                        onValueChangeFinished = { PixelSleepController.setPercent(context, percent.roundToInt()) },
                        valueRange = PixelSleepController.MIN_PERCENT.toFloat()..PixelSleepController.MAX_PERCENT.toFloat(),
                        steps = PixelSleepController.MAX_PERCENT - PixelSleepController.MIN_PERCENT - 1
                    )
                }
            }
        }

        // ---- pixel size
        item {
            GlassCard(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text(stringResource(R.string.pixelsleep_size), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (s in 1..3) {
                            FilterChip(
                                selected = size == s,
                                onClick = {
                                    size = s
                                    PixelSleepController.setSize(context, s)
                                },
                                label = { Text(stringResource(R.string.pixelsleep_size_value, s)) }
                            )
                        }
                    }
                }
            }
        }

        item {
            Text(
                stringResource(R.string.pixelsleep_note),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
            )
        }
    }
}
