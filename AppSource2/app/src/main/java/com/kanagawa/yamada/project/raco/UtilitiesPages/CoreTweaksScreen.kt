package com.kanagawa.yamada.project.raco.UtilitiesPages

import androidx.compose.ui.draw.alpha

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val RACO_CONFIG = "/data/ProjectRaco/raco.txt"

private suspend fun readConfig(): String = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", "cat $RACO_CONFIG").redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor()
        out
    } catch (e: Exception) { "" }
}

private fun parseFlag(content: String, key: String, inverted: Boolean = false): Boolean {
    val match = Regex("^$key=(\\d)", RegexOption.MULTILINE).find(content)
    val value = match?.groupValues?.getOrNull(1)
    return if (inverted) value == "0" else value == "1"
}

private suspend fun writeFlag(key: String, enable: Boolean, inverted: Boolean = false): Boolean = withContext(Dispatchers.IO) {
    try {
        val value = if (inverted) (if (enable) "0" else "1") else (if (enable) "1" else "0")
        val p = ProcessBuilder("su", "-c", "sed -i 's|^$key=.*|$key=$value|' $RACO_CONFIG").redirectErrorStream(true).start()
        p.outputStream.close()
        p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor() == 0
    } catch (e: Exception) { false }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CoreTweaksScreen(onBack: () -> Unit) {
    var isLoading by remember { mutableStateOf(true) }
    var deviceMitigation by remember { mutableStateOf(false) }
    var litePowersave by remember { mutableStateOf(false) }
    var ultraPowersave by remember { mutableStateOf(false) }
    var litePerformance by remember { mutableStateOf(false) }
    var alterCpuMethod by remember { mutableStateOf(false) }
    var legacyNotif by remember { mutableStateOf(false) }
    var silentNotif by remember { mutableStateOf(false) }
    var availableGovernors by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedGovernor by remember { mutableStateOf<String?>(null) }
    var governorExpanded by remember { mutableStateOf(false) }

    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    val context = androidx.compose.ui.platform.LocalContext.current
    LaunchedEffect(Unit) {
        coroutineScope.launch {
            val content = readConfig()
            deviceMitigation = parseFlag(content, "DEVICE_MITIGATION")
            litePowersave = parseFlag(content, "LITE_POWERSAVE")
            ultraPowersave = parseFlag(content, "ULTRA_POWERSAVE")
            litePerformance = parseFlag(content, "LITE_PERFORMANCE")
            alterCpuMethod = parseFlag(content, "ALTER_CPU_METHOD")
            legacyNotif = parseFlag(content, "LEGACY_NOTIF")
            silentNotif = parseFlag(content, "SILENT_NOTIF", inverted = true)
            selectedGovernor = Regex("^GOV=(.*)$", RegexOption.MULTILINE).find(content)?.groupValues?.getOrNull(1)?.trim()
            availableGovernors = withContext(Dispatchers.IO) {
                try {
                    val p = ProcessBuilder("su", "-c", "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors").redirectErrorStream(true).start()
                    p.outputStream.close()
                    val out = p.inputStream.bufferedReader().use { it.readText().trim() }
                    p.waitFor()
                    if (out.isNotEmpty()) out.split(" ").filter { it.isNotEmpty() } else emptyList()
                } catch (e: Exception) { emptyList() }
            }
            isLoading = false
        }
    }

    fun toggle(key: String, current: Boolean, inverted: Boolean = false, setter: (Boolean) -> Unit) {
        val newValue = !current
        setter(newValue)
        coroutineScope.launch {
            val success = writeFlag(key, newValue, inverted)
            val failMsg = context.getString(R.string.failed_to_update_key, key)
            if (!success) { setter(current); snackbarHostState.showSnackbar(failMsg) }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.core_tweaks_title)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent
    ) { padding ->
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (isLoading) 0f else 1f,
            animationSpec = androidx.compose.animation.core.tween(500), label = ""
        )
        LazyColumn(modifier = Modifier.padding(padding).padding(horizontal = 16.dp).alpha(alpha), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            item {
                Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp)) {
                        Text(stringResource(R.string.fix_tweaks), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))

                        TweakToggle(stringResource(R.string.device_mitigation_title), stringResource(R.string.device_mitigation_description), Icons.Default.SecurityUpdate, deviceMitigation) {
                            toggle("DEVICE_MITIGATION", deviceMitigation) { deviceMitigation = it }
                        }
                        TweakToggle(stringResource(R.string.lite_powersave), stringResource(R.string.lite_powersave_desc), Icons.Default.EnergySavingsLeaf, litePowersave) {
                            toggle("LITE_POWERSAVE", litePowersave) { 
                                litePowersave = it
                                if (it && ultraPowersave) toggle("ULTRA_POWERSAVE", ultraPowersave) { ultraPowersave = it }
                            }
                        }
                        TweakToggle(stringResource(R.string.ultra_powersave), stringResource(R.string.ultra_powersave_desc), Icons.Default.BatterySaver, ultraPowersave) {
                            toggle("ULTRA_POWERSAVE", ultraPowersave) { 
                                ultraPowersave = it
                                if (it && litePowersave) toggle("LITE_POWERSAVE", litePowersave) { litePowersave = it }
                            }
                        }
                        TweakToggle(stringResource(R.string.lite_performance), stringResource(R.string.lite_performance_desc), Icons.Default.MonitorHeart, litePerformance) {
                            toggle("LITE_PERFORMANCE", litePerformance) { litePerformance = it }
                        }
                        TweakToggle(stringResource(R.string.alter_cpu_method), stringResource(R.string.alter_cpu_method_desc), Icons.Default.Memory, alterCpuMethod) {
                            toggle("ALTER_CPU_METHOD", alterCpuMethod) { alterCpuMethod = it }
                        }
                        TweakToggle(stringResource(R.string.legacy_notif_title), stringResource(R.string.legacy_notif_description), Icons.Default.NotificationsActive, legacyNotif) {
                            toggle("LEGACY_NOTIF", legacyNotif) { legacyNotif = it }
                        }
                        TweakToggle(stringResource(R.string.silent_notif_mode), stringResource(R.string.silent_notif_mode_desc), Icons.Default.NotificationsOff, silentNotif) {
                            toggle("SILENT_NOTIF", silentNotif, inverted = true) { silentNotif = it }
                        }
                    }
                }
            }

            item {
                Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.custom_cpu_governor), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(stringResource(R.string.select_the_cpu_scaling_governor_takes_effect_after_applying_a_profile), style = MaterialTheme.typography.bodySmall)
                        Spacer(modifier = Modifier.height(16.dp))
                        if (availableGovernors.isEmpty()) {
                            Text(stringResource(R.string.no_governors_found_or_root_access_denied), color = MaterialTheme.colorScheme.error)
                        } else {
                            ExposedDropdownMenuBox(expanded = governorExpanded, onExpandedChange = { governorExpanded = !governorExpanded }) {
                                OutlinedTextField(
                                    value = selectedGovernor ?: stringResource(R.string.no_governor_selected),
                                    onValueChange = {},
                                    readOnly = true,
                                    label = { Text(stringResource(R.string.governor)) },
                                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = governorExpanded) },
                                    modifier = Modifier.fillMaxWidth().menuAnchor()
                                )
                                ExposedDropdownMenu(expanded = governorExpanded, onDismissRequest = { governorExpanded = false }) {
                                    DropdownMenuItem(text = { Text(stringResource(R.string.no_governor_selected)) }, onClick = {
                                        selectedGovernor = null; governorExpanded = false
                                        coroutineScope.launch { withContext(Dispatchers.IO) {
                                            val p = ProcessBuilder("su", "-c", "sed -i 's|^GOV=.*|GOV=|' $RACO_CONFIG").redirectErrorStream(true).start()
                                            p.outputStream.close(); p.inputStream.bufferedReader().use { it.readText() }; p.waitFor()
                                        }}
                                    })
                                    availableGovernors.forEach { gov ->
                                        DropdownMenuItem(text = { Text(gov) }, onClick = {
                                            selectedGovernor = gov; governorExpanded = false
                                            coroutineScope.launch { withContext(Dispatchers.IO) {
                                                val p = ProcessBuilder("su", "-c", "sed -i 's|^GOV=.*|GOV=$gov|' $RACO_CONFIG").redirectErrorStream(true).start()
                                                p.outputStream.close(); p.inputStream.bufferedReader().use { it.readText() }; p.waitFor()
                                            }}
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TweakToggle(title: String, description: String, icon: androidx.compose.ui.graphics.vector.ImageVector, checked: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() }
            .padding(16.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(2.dp))
            Text(description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(modifier = Modifier.width(16.dp))
        Switch(checked = checked, onCheckedChange = { onToggle() })
    }
}
