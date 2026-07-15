package com.kanagawa.yamada.project.raco.screens

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
    var liteMode by remember { mutableStateOf(false) }
    var lifeMode by remember { mutableStateOf(false) }
    var betterPowersave by remember { mutableStateOf(false) }
    var alterCpuMethod by remember { mutableStateOf(false) }
    var legacyNotif by remember { mutableStateOf(false) }
    var silentNotif by remember { mutableStateOf(false) }
    var availableGovernors by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedGovernor by remember { mutableStateOf<String?>(null) }
    var governorExpanded by remember { mutableStateOf(false) }

    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        coroutineScope.launch {
            val content = readConfig()
            deviceMitigation = parseFlag(content, "DEVICE_MITIGATION")
            liteMode = parseFlag(content, "LITE_MODE")
            lifeMode = parseFlag(content, "LIFE_MODE")
            betterPowersave = parseFlag(content, "BETTER_POWERAVE")
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
            if (!success) { setter(current); snackbarHostState.showSnackbar("Failed to update $key") }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Core Tweaks") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        if (isLoading) { Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) { CircularProgressIndicator() }; return@Scaffold }

        LazyColumn(modifier = Modifier.padding(padding).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            item {
                Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp)) {
                        Text("Fix & Tweaks", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))

                        TweakToggle("Device Mitigation", "Fix screen freeze and device stability issues", Icons.Default.SecurityUpdate, deviceMitigation) {
                            toggle("DEVICE_MITIGATION", deviceMitigation) { deviceMitigation = it }
                        }
                        TweakToggle("Lite Mode", "Enable battery-optimized lite performance", Icons.Default.EnergySavingsLeaf, liteMode) {
                            toggle("LITE_MODE", liteMode) { liteMode = it }
                        }
                        TweakToggle("Life Mode", "Balanced CPU at half frequency", Icons.Default.MonitorHeart, lifeMode) {
                            toggle("LIFE_MODE", lifeMode) { lifeMode = it }
                        }
                        TweakToggle("Better Powersave", "Cap CPU for maximum battery savings", Icons.Default.BatterySaver, betterPowersave) {
                            toggle("BETTER_POWERAVE", betterPowersave) { betterPowersave = it }
                        }
                        TweakToggle("Alter CPU Method", "Use this if Scaling Frequency is Wrong for your device", Icons.Default.Memory, alterCpuMethod) {
                            toggle("ALTER_CPU_METHOD", alterCpuMethod) { alterCpuMethod = it }
                        }
                        TweakToggle("Legacy Notification", "Fix missing notifications", Icons.Default.NotificationsActive, legacyNotif) {
                            toggle("LEGACY_NOTIF", legacyNotif) { legacyNotif = it }
                        }
                        TweakToggle("Silent Notif Mode", "Suppress notification sounds during performance mode", Icons.Default.NotificationsOff, silentNotif) {
                            toggle("SILENT_NOTIF", silentNotif, inverted = true) { silentNotif = it }
                        }
                    }
                }
            }

            item {
                Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Custom CPU Governor", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Select the CPU scaling governor. Takes effect after applying a profile.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                        Spacer(modifier = Modifier.height(16.dp))
                        if (availableGovernors.isEmpty()) {
                            Text("No governors found or root access denied.", color = MaterialTheme.colorScheme.error)
                        } else {
                            ExposedDropdownMenuBox(expanded = governorExpanded, onExpandedChange = { governorExpanded = !governorExpanded }) {
                                OutlinedTextField(
                                    value = selectedGovernor ?: "None",
                                    onValueChange = {},
                                    readOnly = true,
                                    label = { Text("Governor") },
                                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = governorExpanded) },
                                    modifier = Modifier.fillMaxWidth().menuAnchor()
                                )
                                ExposedDropdownMenu(expanded = governorExpanded, onDismissRequest = { governorExpanded = false }) {
                                    DropdownMenuItem(text = { Text("None") }, onClick = {
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
    ListItem(
        headlineContent = { Text(title, fontWeight = FontWeight.Bold) },
        supportingContent = { Text(description, style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic) },
        leadingContent = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
        trailingContent = { Switch(checked = checked, onCheckedChange = { onToggle() }) },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent)
    )
}
