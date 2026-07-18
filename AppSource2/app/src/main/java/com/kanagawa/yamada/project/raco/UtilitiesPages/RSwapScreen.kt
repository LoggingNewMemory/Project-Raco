package com.kanagawa.yamada.project.raco.UtilitiesPages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kanagawa.yamada.project.raco.AppIcon
import com.kanagawa.yamada.project.raco.AppName
import com.kanagawa.yamada.project.raco.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

object RSwapLock {
    val mutex = Mutex()
}

private const val AUTOMATION_CONFIG_PATH = "/data/ProjectRaco/raco.txt"

private suspend fun runRootCommand(cmd: String): String = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor(); out
    } catch (e: Exception) { "" }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RSwapScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rswapEnabled by remember { mutableStateOf(false) }
    var rswapSize by remember { mutableStateOf("4") }
    var expandedRswapSize by remember { mutableStateOf(false) }
    var isConfiguring by remember { mutableStateOf(false) }
    var configProgressText by remember { mutableStateOf("") }
    
    val rswapSizeOptions = listOf("4" to "4 GB", "6" to "6 GB", "8" to "8 GB", "12" to "12 GB")
    
    var loadedGames by remember { mutableStateOf<List<String>>(emptyList()) }
    var rswapUsagePercent by remember { mutableStateOf(0) }
    var rswapUsedMB by remember { mutableStateOf(0) }
    var rswapTotalMB by remember { mutableStateOf(0) }
    
    var isMounted by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        val config = runRootCommand("cat $AUTOMATION_CONFIG_PATH")
        rswapEnabled = Regex("^RSWAP[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
        rswapSize = Regex("^RSWAP_SIZE[ \\t]+(\\d+)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) ?: "4"
        isMounted = true
    }

    LaunchedEffect(rswapEnabled) {
        if (rswapEnabled) {
            while(true) {
                val stopFiles = runRootCommand("ls -1 /data/ProjectRaco/RSWAPTrack/rswap_stop_* 2>/dev/null").trim()
                if (stopFiles.isNotEmpty()) {
                    loadedGames = stopFiles.lines().map { it.substringAfterLast("rswap_stop_") }
                } else {
                    loadedGames = emptyList()
                }
                
                val swaps = runRootCommand("cat /proc/swaps | grep /data/ProjectRaco/RSWAP").trim()
                if (swaps.isNotEmpty()) {
                    val parts = swaps.split("\\s+".toRegex())
                    if (parts.size >= 4) {
                        val size = parts[2].toIntOrNull() ?: 0
                        val used = parts[3].toIntOrNull() ?: 0
                        rswapTotalMB = size / 1024
                        rswapUsedMB = used / 1024
                        rswapUsagePercent = if (size > 0) (used * 100) / size else 0
                    }
                } else {
                    rswapTotalMB = 0
                    rswapUsedMB = 0
                    rswapUsagePercent = 0
                }
                kotlinx.coroutines.delay(3000)
            }
        } else {
            loadedGames = emptyList()
            rswapTotalMB = 0
            rswapUsedMB = 0
            rswapUsagePercent = 0
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.rswap_title)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        floatingActionButton = {
            if (rswapEnabled && !isConfiguring && loadedGames.isNotEmpty()) {
                ExtendedFloatingActionButton(
                    onClick = {
                        scope.launch { 
                            runRootCommand("for file in /data/ProjectRaco/RSWAPTrack/rswap_stop_*; do if [ -f \"\$file\" ]; then pkg=\${file##*_}; for p in \$(pidof \$pkg); do kill -9 \$p; done; rm -f \"\$file\"; fi; done")
                            runRootCommand("swapoff /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                        }
                    },
                    icon = { Icon(Icons.Default.DeleteSweep, contentDescription = null) },
                    text = { Text(stringResource(R.string.rswap_unload_all)) },
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                )
            }
        },
        containerColor = Color.Transparent
    ) { padding ->
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (isMounted) 1f else 0f,
            animationSpec = androidx.compose.animation.core.tween(150), label = ""
        )
        
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp).alpha(alpha),
            contentPadding = PaddingValues(top = 8.dp, bottom = 100.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Config Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Memory, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(stringResource(R.string.enable_rswap), fontWeight = FontWeight.Bold)
                                Text(stringResource(R.string.rswap_desc), style = MaterialTheme.typography.bodySmall)
                            }
                            Switch(
                                checked = rswapEnabled,
                                onCheckedChange = { newValue ->
                                    rswapEnabled = newValue
                                    isConfiguring = true
                                    configProgressText = context.getString(R.string.rswap_applying_changes)
                                    scope.launch {
                                        kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                                            RSwapLock.mutex.withLock {
                                                val v = if (newValue) "1" else "0"
                                                runRootCommand("grep -q '^RSWAP' $AUTOMATION_CONFIG_PATH && sed -i 's/^RSWAP.*/RSWAP $v/' $AUTOMATION_CONFIG_PATH || echo 'RSWAP $v' >> $AUTOMATION_CONFIG_PATH")
                                                if (newValue) {
                                                    runRootCommand("mkdir -p /data/ProjectRaco/RSWAPTrack")
                                                    configProgressText = context.getString(R.string.rswap_allocating)
                                                    runRootCommand("fallocate -l ${rswapSize}G /data/ProjectRaco/RSWAP")
                                                    configProgressText = context.getString(R.string.rswap_activating)
                                                    runRootCommand("chmod 0600 /data/ProjectRaco/RSWAP; mkswap /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                                                    runRootCommand("echo 100 > /proc/sys/vm/swappiness")
                                                    runRootCommand("echo \$(( \$(cat /proc/sys/vm/min_free_kbytes) * 12 / 10 )) > /proc/sys/vm/min_free_kbytes")
                                                } else {
                                                    configProgressText = context.getString(R.string.rswap_removing_old)
                                                    runRootCommand("swapoff /data/ProjectRaco/RSWAP; rm -f /data/ProjectRaco/RSWAP")
                                                }
                                                isConfiguring = false
                                            }
                                        }
                                    }
                                },
                                enabled = !isConfiguring
                            )
                        }
                        
                        if (rswapEnabled) {
                            Spacer(Modifier.height(16.dp))
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                                Text(stringResource(R.string.rswap_size), modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                                Box {
                                    TextButton(onClick = { expandedRswapSize = true }, enabled = !isConfiguring) {
                                        Text(rswapSizeOptions.find { it.first == rswapSize }?.second ?: "4 GB")
                                    }
                                    DropdownMenu(
                                        expanded = expandedRswapSize,
                                        onDismissRequest = { expandedRswapSize = false }
                                    ) {
                                        rswapSizeOptions.forEach { (value, label) ->
                                            DropdownMenuItem(
                                                text = { Text(label) },
                                                onClick = {
                                                    rswapSize = value
                                                    expandedRswapSize = false
                                                    isConfiguring = true
                                                    configProgressText = context.getString(R.string.rswap_removing_old)
                                                    scope.launch {
                                                        kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                                                            RSwapLock.mutex.withLock {
                                                                runRootCommand("grep -q '^RSWAP_SIZE' $AUTOMATION_CONFIG_PATH && sed -i 's/^RSWAP_SIZE.*/RSWAP_SIZE $value/' $AUTOMATION_CONFIG_PATH || echo 'RSWAP_SIZE $value' >> $AUTOMATION_CONFIG_PATH")
                                                                runRootCommand("for file in /data/ProjectRaco/RSWAPTrack/rswap_stop_*; do if [ -f \"\$file\" ]; then pkg=\${file##*_}; for p in \$(pidof \$pkg); do kill -9 \$p; done; rm -f \"\$file\"; fi; done")
                                                                runRootCommand("swapoff /data/ProjectRaco/RSWAP; rm -f /data/ProjectRaco/RSWAP")
                                                                configProgressText = context.getString(R.string.rswap_allocating)
                                                                runRootCommand("fallocate -l ${value}G /data/ProjectRaco/RSWAP")
                                                                configProgressText = context.getString(R.string.rswap_activating)
                                                                runRootCommand("chmod 0600 /data/ProjectRaco/RSWAP; mkswap /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                                                                isConfiguring = false
                                                            }
                                                        }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            
                            if (isConfiguring) {
                                Spacer(Modifier.height(16.dp))
                                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                                        CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                                        Spacer(Modifier.width(12.dp))
                                        Text(configProgressText, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                                    }
                                    Spacer(Modifier.height(8.dp))
                                    Text(stringResource(R.string.rswap_warning_do_not_close), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }
            }
            
            // Status Card and Game List
            if (rswapEnabled && !isConfiguring) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(Modifier.padding(16.dp)) {
                            Text(stringResource(R.string.rswap_status), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(12.dp))
                            
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Capacity:", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                                Text("$rswapUsedMB MB / $rswapTotalMB MB ($rswapUsagePercent%)", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                            }
                            Spacer(Modifier.height(8.dp))
                            LinearProgressIndicator(
                                progress = { rswapUsagePercent / 100f },
                                modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                                color = MaterialTheme.colorScheme.primary,
                                trackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)
                            )
                            
                            Spacer(Modifier.height(24.dp))
                            Text(stringResource(R.string.rswap_loaded_games), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(8.dp))
                            
                            if (loadedGames.isEmpty()) {
                                Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                                    Text(stringResource(R.string.rswap_no_games), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            } else {
                                loadedGames.forEach { pkg ->
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(vertical = 4.dp)
                                            .background(MaterialTheme.colorScheme.background.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(12.dp)) {
                                            AppIcon(pkg = pkg, modifier = Modifier.size(36.dp))
                                            Spacer(modifier = Modifier.width(12.dp))
                                            Column(modifier = Modifier.weight(1f)) {
                                                AppName(pkg = pkg, color = MaterialTheme.colorScheme.onSurface)
                                                Text(pkg, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                            IconButton(onClick = {
                                                scope.launch {
                                                    runRootCommand("for p in \$(pidof $pkg); do kill -9 \$p; done")
                                                    runRootCommand("rm -f /data/ProjectRaco/RSWAPTrack/rswap_stop_$pkg")
                                                    runRootCommand("swapoff /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                                                }
                                            }) {
                                                Icon(Icons.Default.Clear, contentDescription = stringResource(R.string.rswap_unload), tint = MaterialTheme.colorScheme.error)
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
    }
}
