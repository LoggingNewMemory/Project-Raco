package com.kanagawa.yamada.project.raco.screens

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

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
    val titleRes: Int,
    val subtitleRes: Int,
    val icon: ImageVector,
)

private val EXTRA_TOGGLE_ITEMS = listOf(
    ExtraToggleItem("INCLUDE_ANYA", R.string.anya_thermal, R.string.install_the_anya_thermal_engine_on_next_boot, Icons.Filled.Thermostat),
    ExtraToggleItem("INCLUDE_KOBO", R.string.kobo_fast_charge, R.string.install_the_kobo_fast_charging_module_on_next_boot, Icons.Filled.BatteryChargingFull),
    ExtraToggleItem("INCLUDE_ZETAMIN", R.string.zetamin_game_optimizer, R.string.install_zetamin_optimization_services_on_next_boot, Icons.Filled.DisplaySettings),
    ExtraToggleItem("INCLUDE_SANDEV", R.string.sandevistan, R.string.install_the_sandevistan_module_on_next_boot, Icons.Filled.RocketLaunch)
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
                title = { Text(stringResource(R.string.extra_settings_title)) },
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
                                Text(text = stringResource(item.titleRes), style = MaterialTheme.typography.titleMedium)
                                Text(text = stringResource(item.subtitleRes), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
