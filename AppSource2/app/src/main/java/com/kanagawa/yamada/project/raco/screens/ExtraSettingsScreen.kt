package com.kanagawa.yamada.project.raco.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material.icons.filled.DisplaySettings
import androidx.compose.material.icons.filled.RocketLaunch
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val EXTRA_CONFIG_PATH = "/data/ProjectRaco/raco.txt"

private data class ExtraToggleItem(
    val key: String,
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
)

private val EXTRA_TOGGLE_ITEMS = listOf(
    ExtraToggleItem("INCLUDE_ANYA",    "Anya Thermal",            "Install the Anya thermal engine on next boot.",               Icons.Filled.Thermostat),
    ExtraToggleItem("INCLUDE_KOBO",    "Kobo Fast Charge",        "Install the Kobo fast charging module on next boot.",         Icons.Filled.BatteryChargingFull),
    ExtraToggleItem("INCLUDE_ZETAMIN", "Zetamin Game Optimizer",  "Install Zetamin optimization services on next boot.",         Icons.Filled.DisplaySettings),
    ExtraToggleItem("INCLUDE_SANDEV",  "Sandevistan",             "Install the Sandevistan module on next boot.",                Icons.Filled.RocketLaunch)
)

private fun readExtraConfig(): String? = runCatching {
    val p = ProcessBuilder("su", "-c", "cat $EXTRA_CONFIG_PATH").redirectErrorStream(true).start()
    p.outputStream.close()
    val out = p.inputStream.bufferedReader().use { it.readText() }
    p.waitFor(); out
}.getOrNull()

private fun parseExtraFlag(content: String, key: String): Boolean {
    val match = Regex("^$key=(.*)$", RegexOption.MULTILINE).find(content) ?: return false
    return match.groupValues.getOrNull(1)?.trim() == "1"
}

private fun writeExtraFlag(key: String, value: Boolean) {
    val intVal = if (value) 1 else 0
    val p = ProcessBuilder("su", "-c", "sed -i 's/^$key=.*/$key=$intVal/' $EXTRA_CONFIG_PATH").redirectErrorStream(true).start()
    p.outputStream.close(); p.inputStream.bufferedReader().use { it.readText() }; p.waitFor()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExtraSettingsScreen(onBack: () -> Unit) {
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val toggleStates = remember { mutableStateMapOf<String, Boolean>() }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            val content = readExtraConfig()
            if (content != null) {
                EXTRA_TOGGLE_ITEMS.forEach { item -> toggleStates[item.key] = parseExtraFlag(content, item.key) }
            }
        }
        isLoading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Extra Settings") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = androidx.compose.ui.graphics.Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth(0.6f))
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 8.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                contentPadding = PaddingValues(bottom = 32.dp)
            ) {
                items(EXTRA_TOGGLE_ITEMS.size) { index ->
                    val item = EXTRA_TOGGLE_ITEMS[index]
                    val checked = toggleStates[item.key] ?: false
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(item.icon, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(24.dp))
                            Spacer(modifier = Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(item.title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
                                Text(item.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Switch(
                                checked = checked,
                                onCheckedChange = { newValue ->
                                    toggleStates[item.key] = newValue
                                    scope.launch {
                                        withContext(Dispatchers.IO) { writeExtraFlag(item.key, newValue) }
                                        snackbarHostState.showSnackbar("Reboot to take effect", duration = SnackbarDuration.Short)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}
