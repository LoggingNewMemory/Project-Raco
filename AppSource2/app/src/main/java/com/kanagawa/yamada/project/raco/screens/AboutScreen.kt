package com.kanagawa.yamada.project.raco.screens

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
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
import java.io.BufferedReader
import java.io.InputStreamReader

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(onBack: () -> Unit) {
    var deviceModel by remember { mutableStateOf("") }
    var cpuInfo by remember { mutableStateOf("") }
    var ramInfo by remember { mutableStateOf("") }
    var storageInfo by remember { mutableStateOf("") }
    var batteryInfo by remember { mutableStateOf("") }
    var isLoaded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    val credits = listOf(
        "Rem01 Gaming", "MiAzami", "Kazuyoo", "RiProG",
        "HoyoSlave", "Koneko_dev", "Not_ValentineSTCV",
        "Andreyka4_45", "Zexshia", "kaminarich",
        "fuckyoustan", "Xyanz_25", "hirauki", "KanaDev_IS",
        stringResource(R.string.credits_11)
    )

    LaunchedEffect(Unit) {
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val processModel = Runtime.getRuntime().exec(arrayOf("su", "-c", "getprop ro.product.model"))
                    deviceModel = BufferedReader(InputStreamReader(processModel.inputStream)).readText().trim()

                    var cpuName = BufferedReader(InputStreamReader(Runtime.getRuntime().exec(arrayOf("su", "-c", "getprop ro.board.platform")).inputStream)).readText().trim()
                    if (cpuName.isEmpty() || cpuName.equals("unknown", ignoreCase = true)) {
                        cpuName = BufferedReader(InputStreamReader(Runtime.getRuntime().exec(arrayOf("su", "-c", "getprop ro.hardware")).inputStream)).readText().trim()
                    }
                    if (cpuName.isEmpty() || cpuName.equals("unknown", ignoreCase = true)) {
                        cpuName = BufferedReader(InputStreamReader(Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /proc/cpuinfo | grep Hardware | cut -d: -f2")).inputStream)).readText().trim()
                    }
                    val cpuFreqStr = BufferedReader(InputStreamReader(Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq | sort -nr | head -n 1")).inputStream)).readText().trim()
                    cpuInfo = if (cpuFreqStr.isNotEmpty() && cpuFreqStr.toLongOrNull() != null) {
                        val freqGhz = cpuFreqStr.toLong() / 1000000.0
                        String.format("%.2fGHz %s", freqGhz, cpuName)
                    } else {
                        cpuName
                    }

                    val processRam = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /proc/meminfo | grep MemTotal | awk '{print \$2}'"))
                    val ramKbStr = BufferedReader(InputStreamReader(processRam.inputStream)).readText().trim()
                    if (ramKbStr.isNotEmpty() && ramKbStr.toLongOrNull() != null) {
                        val ramGb = Math.ceil(ramKbStr.toLong() / (1024.0 * 1024.0)).toLong()
                        ramInfo = "$ramGb GB"
                    }

                    val processStorage = Runtime.getRuntime().exec(arrayOf("su", "-c", "df /data | tail -n 1 | awk '{print \$2}'"))
                    val storageKbStr = BufferedReader(InputStreamReader(processStorage.inputStream)).readText().trim()
                    if (storageKbStr.isNotEmpty() && storageKbStr.toLongOrNull() != null) {
                        val storageGb = storageKbStr.toLong() / (1024.0 * 1024.0)
                        storageInfo = when {
                            storageGb > 500 -> "1 TB"
                            storageGb > 240 -> "512 GB"
                            storageGb > 200 -> "256 GB"
                            storageGb > 100 -> "128 GB"
                            storageGb > 50 -> "64 GB"
                            else -> "${Math.round(storageGb)} GB"
                        }
                    }

                    val processBattery = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /sys/class/power_supply/battery/charge_full_design"))
                    val batteryUahStr = BufferedReader(InputStreamReader(processBattery.inputStream)).readText().trim()
                    if (batteryUahStr.isNotEmpty() && batteryUahStr.toLongOrNull() != null) {
                        var mah = Math.round(batteryUahStr.toLong() / 1000.0)
                        if (mah < 1000) mah *= 10
                        batteryInfo = "$mah mAh"
                    }
                }
            } catch (e: Exception) {
                // Ignore
            } finally {
                isLoaded = true
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.about)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = MaterialTheme.colorScheme.primary,
                    navigationIconContentColor = MaterialTheme.colorScheme.primary
                )
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        if (!isLoaded) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 24.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                Column(horizontalAlignment = Alignment.End, modifier = Modifier.fillMaxWidth()) {
                    DeviceInfoRow(deviceModel, "Device Name")
                    DeviceInfoRow(cpuInfo, stringResource(R.string.processor))
                    DeviceInfoRow(ramInfo, stringResource(R.string.ram))
                    DeviceInfoRow(storageInfo, "Storage")
                    DeviceInfoRow(batteryInfo, "Battery")
                }

                Spacer(modifier = Modifier.height(40.dp))
                Text(
                    stringResource(R.string.about_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    textDecoration = androidx.compose.ui.text.style.TextDecoration.Underline
                )
                Spacer(modifier = Modifier.height(15.dp))
                
                credits.forEach { credit ->
                    Text("• $credit", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(vertical = 3.dp))
                }

                Spacer(modifier = Modifier.height(20.dp))
                Text(
                    stringResource(R.string.about_note),
                    style = MaterialTheme.typography.bodyMedium
                )
                
                Spacer(modifier = Modifier.height(20.dp))
                Text(
                    "\"Great Collaboration Lead to Great Innovation\"\n~ Kanagawa Yamada (Main Dev)",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(20.dp))
            }
        }
    }
}

@Composable
fun DeviceInfoRow(value: String, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(vertical = 8.dp)
    ) {
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
        Spacer(modifier = Modifier.width(8.dp))
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(modifier = Modifier.width(4.dp))
        Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
    }
}
