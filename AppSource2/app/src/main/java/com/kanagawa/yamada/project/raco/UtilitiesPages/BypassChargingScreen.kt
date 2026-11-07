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

import android.os.BatteryManager
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kanagawa.yamada.project.raco.R
import com.kanagawa.yamada.project.raco.tools.BypassCharging
import com.kanagawa.yamada.project.raco.ui.theme.GlassCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

@Composable
private fun plugLabel(plugged: Int): String = when {
    plugged and BatteryManager.BATTERY_PLUGGED_AC != 0 -> stringResource(R.string.bypass_plug_ac)
    plugged and BatteryManager.BATTERY_PLUGGED_USB != 0 -> stringResource(R.string.bypass_plug_usb)
    plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS != 0 -> stringResource(R.string.bypass_plug_wireless)
    plugged != 0 -> stringResource(R.string.bypass_plug_ac)
    else -> stringResource(R.string.bypass_plug_none)
}

@Composable
private fun stateLabel(code: Int): String = when (code) {
    BatteryManager.BATTERY_STATUS_CHARGING -> stringResource(R.string.bypass_state_charging)
    BatteryManager.BATTERY_STATUS_DISCHARGING -> stringResource(R.string.bypass_state_discharging)
    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> stringResource(R.string.bypass_state_not_charging)
    BatteryManager.BATTERY_STATUS_FULL -> stringResource(R.string.bypass_state_full)
    else -> stringResource(R.string.bypass_state_unknown)
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BypassChargingScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.bypass_title)) },
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
        BypassChargingContent(Modifier.padding(padding))
    }
}

/** The Bypass Charging settings; shared by the Utilities page and the PS4 Game Mode panel. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BypassChargingContent(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }

    var enabled by remember { mutableStateOf(BypassCharging.isEnabled(context)) }
    var status by remember { mutableStateOf<BypassCharging.Status?>(null) }
    var nodes by remember { mutableStateOf<List<BypassCharging.Detected>>(emptyList()) }
    var scanning by remember { mutableStateOf(true) }
    var selected by remember { mutableStateOf(BypassCharging.currentNode(context)) }
    var resume by remember { mutableFloatStateOf(BypassCharging.resumeLevel(context).toFloat()) }

    var customPath by remember { mutableStateOf(selected?.path ?: "") }
    var customNormal by remember { mutableStateOf(selected?.normal ?: "") }
    var customBypass by remember { mutableStateOf(selected?.bypass ?: "") }

    val invalidText = stringResource(R.string.bypass_custom_invalid)
    val savedText = stringResource(R.string.bypass_custom_saved)

    suspend fun scan() {
        scanning = true
        nodes = withContext(Dispatchers.IO) { BypassCharging.detect() }
        scanning = false
    }

    LaunchedEffect(Unit) { scan() }
    // Live battery status; also keeps the switch in sync with the Game Assistant tile / safety service.
    LaunchedEffect(Unit) {
        while (true) {
            status = withContext(Dispatchers.IO) { BypassCharging.readStatus(context) }
            enabled = BypassCharging.isEnabled(context)
            delay(2000)
        }
    }

    Box(modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            // ---- master switch
            item {
                GlassCard(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.BatteryChargingFull, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
                        Spacer(Modifier.width(16.dp))
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(R.string.bypass_enable), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(2.dp))
                            Text(stringResource(R.string.bypass_enable_desc), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Spacer(Modifier.width(8.dp))
                        Switch(
                            checked = enabled,
                            onCheckedChange = { want ->
                                scope.launch {
                                    val err = withContext(Dispatchers.IO) { BypassCharging.setEnabled(context, want) }
                                    enabled = BypassCharging.isEnabled(context)
                                    selected = BypassCharging.currentNode(context)
                                    if (err != null) snackbar.showSnackbar(err)
                                }
                            }
                        )
                    }
                }
            }

            // ---- battery status
            item {
                GlassCard(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.bypass_status), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(6.dp))
                        val st = status
                        if (st != null) {
                            StatRow(stringResource(R.string.bypass_level), if (st.level >= 0) "${st.level}%" else "-")
                            StatRow(stringResource(R.string.bypass_power), plugLabel(st.plugged))
                            StatRow(stringResource(R.string.bypass_state), stateLabel(st.statusCode))
                            StatRow(stringResource(R.string.bypass_current), st.currentMa?.let { "$it mA" } ?: "-")
                            StatRow(stringResource(R.string.bypass_temp), "${"%.1f".format(st.tempC)} °C")
                            // Honest check: with a real bypass the battery current drops to ~0 mA.
                            if (enabled && st.plugged != 0 && st.currentMa != null) {
                                Spacer(Modifier.height(8.dp))
                                if (st.currentMa <= 30) {
                                    Text(
                                        stringResource(R.string.bypass_verify_ok),
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                } else {
                                    Text(
                                        stringResource(R.string.bypass_verify_bad, st.currentMa),
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.error
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ---- node selection
            item {
                GlassCard(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                stringResource(R.string.bypass_node),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.weight(1f)
                            )
                            TextButton(onClick = { scope.launch { scan() } }) { Text(stringResource(R.string.bypass_rescan)) }
                        }
                        if (scanning) {
                            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                        } else if (nodes.isEmpty()) {
                            Text(
                                stringResource(R.string.bypass_no_nodes),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        for (d in nodes) {
                            val isSel = selected?.path == d.node.path
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable(enabled = !enabled) {
                                        BypassCharging.saveNode(context, d.node)
                                        selected = d.node
                                        customPath = d.node.path
                                        customNormal = d.node.normal
                                        customBypass = d.node.bypass
                                    }
                                    .padding(vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                RadioButton(selected = isSel, onClick = null, enabled = !enabled)
                                Spacer(Modifier.width(8.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(
                                        d.node.path.removePrefix("/sys/"),
                                        style = MaterialTheme.typography.bodyMedium,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        stringResource(R.string.bypass_node_current, d.currentValue.ifEmpty { "?" }) +
                                            "  (${d.node.normal} / ${d.node.bypass})",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ---- custom node
            item {
                GlassCard(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.bypass_custom), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        OutlinedTextField(
                            value = customPath,
                            onValueChange = { customPath = it.trim() },
                            label = { Text(stringResource(R.string.bypass_custom_path)) },
                            singleLine = true,
                            enabled = !enabled,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = customNormal,
                                onValueChange = { customNormal = it.trim() },
                                label = { Text(stringResource(R.string.bypass_custom_normal)) },
                                singleLine = true,
                                enabled = !enabled,
                                modifier = Modifier.weight(1f)
                            )
                            OutlinedTextField(
                                value = customBypass,
                                onValueChange = { customBypass = it.trim() },
                                label = { Text(stringResource(R.string.bypass_custom_bypass)) },
                                singleLine = true,
                                enabled = !enabled,
                                modifier = Modifier.weight(1f)
                            )
                        }
                        Button(
                            enabled = !enabled,
                            onClick = {
                                val cn = BypassCharging.cleanValue(customNormal)
                                val cb = BypassCharging.cleanValue(customBypass)
                                if (BypassCharging.isValidCustom(customPath, cn, cb)) {
                                    customNormal = cn
                                    customBypass = cb
                                    val n = BypassCharging.Node(customPath, cn, cb)
                                    BypassCharging.saveNode(context, n)
                                    selected = n
                                    scope.launch { snackbar.showSnackbar(savedText) }
                                } else {
                                    scope.launch { snackbar.showSnackbar(invalidText) }
                                }
                            }
                        ) { Text(stringResource(R.string.bypass_custom_save)) }
                    }
                }
            }

            // ---- safety
            item {
                GlassCard(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Row {
                            Text(
                                stringResource(R.string.bypass_resume),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.weight(1f)
                            )
                            Text(stringResource(R.string.bypass_resume_value, resume.roundToInt()), fontWeight = FontWeight.Medium)
                        }
                        Slider(
                            value = resume,
                            onValueChange = { resume = it },
                            onValueChangeFinished = { BypassCharging.setResumeLevel(context, resume.roundToInt()) },
                            valueRange = 5f..50f,
                            steps = 44
                        )
                        Text(
                            stringResource(R.string.bypass_safety),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            item {
                Text(
                    stringResource(R.string.bypass_warn),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
                )
            }
        }
        SnackbarHost(snackbar, modifier = Modifier.align(Alignment.BottomCenter))
    }
}
