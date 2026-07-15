package com.kanagawa.yamada.project.raco.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val SYS_CONFIG = "/data/ProjectRaco/raco.txt"

private suspend fun sysRunRoot(cmd: String): String = withContext(Dispatchers.IO) {
    try {
        kotlinx.coroutines.withTimeoutOrNull(5000L) {
            val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
            p.outputStream.close()
            val out = p.inputStream.bufferedReader().use { it.readText() }
            p.waitFor(); out
        } ?: ""
    } catch (e: Exception) { "" }
}

private suspend fun sysWriteKey(key: String, value: String) {
    sysRunRoot("sed -i 's|^$key=.*|$key=$value|' $SYS_CONFIG")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SystemScreen(onBack: () -> Unit) {
    var isLoading by remember { mutableStateOf(true) }

    // State
    var dndEnabled by remember { mutableStateOf(false) }
    var anyaThermalEnabled by remember { mutableStateOf(false) }
    var anyaIncluded by remember { mutableStateOf(false) }
    var sandevIncluded by remember { mutableStateOf(false) }
    var sandevDurationText by remember { mutableStateOf("10") }

    var graphicsDriver by remember { mutableIntStateOf(0) }
    var originalResolution by remember { mutableStateOf("") }
    var currentResolution by remember { mutableStateOf("") }
    var originalDensity by remember { mutableIntStateOf(0) }
    var resolutionAvailable by remember { mutableStateOf(false) }
    var isBusyAnya by remember { mutableStateOf(false) }

    var isBusySandev by remember { mutableStateOf(false) }
    var isBusyGraphics by remember { mutableStateOf(false) }
    var isBusyFstrim by remember { mutableStateOf(false) }
    var isBusyClearCache by remember { mutableStateOf(false) }
    var fstrimResult by remember { mutableStateOf("") }

    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        val config = sysRunRoot("cat $SYS_CONFIG")
        fun parseFlag(key: String) = Regex("^$key=(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"

        dndEnabled = parseFlag("DND")
        anyaThermalEnabled = parseFlag("ANYA")
        anyaIncluded = Regex("^INCLUDE_ANYA=(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) != "0"
        sandevIncluded = parseFlag("INCLUDE_SANDEV")
        sandevDurationText = Regex("^SANDEV_DUR=(\\d+)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) ?: "10"

        // Graphics driver
        val driverOut = sysRunRoot("settings get global updatable_driver_all_apps")
        graphicsDriver = driverOut.trim().toIntOrNull() ?: 0

        // Resolution
        val wmSize = sysRunRoot("wm size")
        val wmDensity = sysRunRoot("wm density")
        if (wmSize.contains("Physical size:")) {
            originalResolution = Regex("Physical size:\\s*([0-9]+x[0-9]+)").find(wmSize)?.groupValues?.getOrNull(1) ?: ""
            val overrideMatch = Regex("Override size:\\s*([0-9]+x[0-9]+)").find(wmSize)
            currentResolution = overrideMatch?.groupValues?.getOrNull(1) ?: originalResolution
            originalDensity = Regex("(?:Physical|Override) density:\\s*([0-9]+)").find(wmDensity)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: 0
            resolutionAvailable = originalResolution.isNotEmpty() && originalDensity > 0
        }

        isLoading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("System") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        if (isLoading) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
        ) {
            // Anya Thermal Card
            if (anyaIncluded) {
                item {
                    SystemCard("Anya Thermal") {
                        Text("FlowState thermal management. Disable throttling for sustained performance.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Thermostat, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(12.dp))
                            Text("Enable Anya Thermal Control", Modifier.weight(1f), fontWeight = FontWeight.Bold)
                            if (isBusyAnya) CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                            else Switch(checked = anyaThermalEnabled, onCheckedChange = { newVal ->
                                isBusyAnya = true
                                anyaThermalEnabled = newVal
                                scope.launch {
                                    val script = if (newVal) "/data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh" else "/data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh"
                                    sysRunRoot(script)
                                    sysWriteKey("ANYA", if (newVal) "1" else "0")
                                    isBusyAnya = false
                                }
                            })
                        }
                    }
                }
            }

            // Sandevistan Duration Card
            if (sandevIncluded) {
                item {
                    SystemCard("Sandevistan Duration") {
                        Text("Duration in seconds for the Sandevistan boost. Higher = longer burst.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                        Spacer(Modifier.height(16.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(
                                value = sandevDurationText,
                                onValueChange = { sandevDurationText = it },
                                label = { Text("Duration (seconds)") },
                                modifier = Modifier.weight(1f),
                                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Number),
                                singleLine = true
                            )
                            Spacer(Modifier.width(16.dp))
                            IconButton(
                                onClick = {
                                    val newDur = sandevDurationText.toIntOrNull()
                                    if (newDur != null && newDur >= 0) {
                                        isBusySandev = true
                                        scope.launch {
                                            sysRunRoot("grep -q '^SANDEV_DUR=' $SYS_CONFIG && sed -i 's|^SANDEV_DUR=.*|SANDEV_DUR=$newDur|' $SYS_CONFIG || echo 'SANDEV_DUR=$newDur' >> $SYS_CONFIG")
                                            isBusySandev = false
                                            snackbarHostState.showSnackbar("Saved!")
                                        }
                                    }
                                }
                            ) {
                                if (isBusySandev) CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                                else Icon(Icons.Default.Save, null, tint = MaterialTheme.colorScheme.primary)
                            }
                        }
                        // Easter egg messages
                        val dur = sandevDurationText.toIntOrNull()
                        if (dur != null) {
                            val msg = when {
                                dur < 10 -> "Too short... completely useless."
                                dur == 10 -> "Original duration. Classic."
                                dur <= 30 -> "Better. You're doing great."
                                dur <= 60 -> "David Martinez would be proud."
                                else -> "You're a full-on Smasher now."
                            }
                            Spacer(Modifier.height(8.dp))
                            Text(msg, color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }

            // Graphics Driver Card
            item {
                SystemCard("Graphics Driver") {
                    Text("Set the ANGLE/Vulkan graphics driver mode.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                    Spacer(Modifier.height(8.dp))
                    Text("Current: ${when(graphicsDriver) { 1 -> "Game Driver"; 2 -> "Developer Driver"; else -> "Default" }}", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(16.dp))
                    listOf("Default" to 0, "Game Driver" to 1, "Developer Driver" to 2).forEach { (label, value) ->
                        OutlinedButton(
                            onClick = {
                                isBusyGraphics = true
                                scope.launch {
                                    sysRunRoot("settings put global updatable_driver_all_apps $value")
                                    graphicsDriver = value
                                    isBusyGraphics = false
                                }
                            },
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            colors = if (graphicsDriver == value) ButtonDefaults.outlinedButtonColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                                     else ButtonDefaults.outlinedButtonColors()
                        ) { Text(label) }
                    }
                }
            }

            // Resolution Downscale Card
            if (resolutionAvailable) {
                item {
                    SystemCard("Resolution Downscale") {
                        Text("Override display resolution and density. Use Reset to restore defaults.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                        Spacer(Modifier.height(8.dp))
                        Text("Physical: $originalResolution | Current: $currentResolution", style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(12.dp))
                        val resolutionOptions = remember(originalResolution) {
                            try {
                                val parts = originalResolution.split("x")
                                val w = parts[0].toInt(); val h = parts[1].toInt()
                                listOf(
                                    "100% (${w}x${h})" to "${w}x${h}",
                                    "90% (${(w * 0.9).toInt()}x${(h * 0.9).toInt()})" to "${(w * 0.9).toInt()}x${(h * 0.9).toInt()}",
                                    "80% (${(w * 0.8).toInt()}x${(h * 0.8).toInt()})" to "${(w * 0.8).toInt()}x${(h * 0.8).toInt()}",
                                    "70% (${(w * 0.7).toInt()}x${(h * 0.7).toInt()})" to "${(w * 0.7).toInt()}x${(h * 0.7).toInt()}",
                                )
                            } catch (e: Exception) { emptyList() }
                        }
                        resolutionOptions.forEach { (label, res) ->
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        sysRunRoot("wm size $res")
                                        currentResolution = res
                                    }
                                },
                                modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
                                colors = if (currentResolution == res) ButtonDefaults.outlinedButtonColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                                         else ButtonDefaults.outlinedButtonColors()
                            ) { Text(label) }
                        }
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = {
                                scope.launch {
                                    sysRunRoot("wm size reset")
                                    sysRunRoot("wm density reset")
                                    currentResolution = originalResolution
                                    snackbarHostState.showSnackbar("Resolution reset to default")
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                        ) { Text("Reset to Default") }
                    }
                }
            }

            // System Actions Card
            item {
                SystemCard("System Actions") {
                    // FSTRIM
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("FSTRIM", fontWeight = FontWeight.Bold)
                            Text("Trim filesystem for storage performance.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                        }
                        Button(
                            onClick = {
                                isBusyFstrim = true
                                scope.launch {
                                    fstrimResult = sysRunRoot("fstrim -v /data /cache /system")
                                    isBusyFstrim = false
                                    snackbarHostState.showSnackbar("FSTRIM completed!")
                                }
                            },
                            enabled = !isBusyFstrim
                        ) {
                            if (isBusyFstrim) CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = Color.White)
                            else Text("Run")
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    // Clear Cache
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Clear Cache", fontWeight = FontWeight.Bold)
                            Text("Remove system cache partition contents.", style = MaterialTheme.typography.bodySmall, fontStyle = FontStyle.Italic)
                        }
                        Button(
                            onClick = {
                                isBusyClearCache = true
                                scope.launch {
                                    sysRunRoot("rm -rf /cache/*")
                                    isBusyClearCache = false
                                    snackbarHostState.showSnackbar("Cache cleared!")
                                }
                            },
                            enabled = !isBusyClearCache,
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                        ) {
                            if (isBusyClearCache) CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = Color.White)
                            else Text("Clear")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SystemCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            content()
        }
    }
}
