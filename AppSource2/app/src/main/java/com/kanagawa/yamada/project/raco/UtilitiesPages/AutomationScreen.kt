package com.kanagawa.yamada.project.raco.UtilitiesPages

import androidx.compose.ui.draw.alpha
import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource
import android.content.pm.PackageManager
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.kanagawa.yamada.project.raco.AppIcon
import com.kanagawa.yamada.project.raco.AppName

private const val AUTOMATION_CONFIG_PATH = "/data/ProjectRaco/raco.txt"

private suspend fun runRoot(cmd: String): String = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor(); out
    } catch (e: Exception) { "" }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AutomationScreen(onBack: () -> Unit) {
    var showAppList by remember { mutableStateOf(false) }

    if (showAppList) {
        AppListPage(onBack = { showAppList = false })
        return
    }

    val context = LocalContext.current
    var isLoading by remember { mutableStateOf(true) }
    var dndEnabled by remember { mutableStateOf(false) }
    var gameAssistantEnabled by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    
    LaunchedEffect(Unit) {
        val config = runRoot("cat $AUTOMATION_CONFIG_PATH")
        dndEnabled = Regex("^DND[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
        gameAssistantEnabled = Regex("^GAME_ASSISTANT[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
        isLoading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.automation_title)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent
    ) { padding ->
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (isLoading) 0f else 1f,
            animationSpec = androidx.compose.animation.core.tween(150), label = ""
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp).alpha(alpha),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
        ) {
            // Game Assistant Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.game_assistant), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.game_assistant_desc), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.SportsEsports, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(12.dp))
                            Text(stringResource(R.string.enable_service), modifier = Modifier.weight(1f), fontWeight = FontWeight.Bold)
                            Switch(
                                checked = gameAssistantEnabled,
                                onCheckedChange = { newValue ->
                                    gameAssistantEnabled = newValue
                                    scope.launch {
                                        val v = if (newValue) "1" else "0"
                                        runRoot("grep -q '^GAME_ASSISTANT' $AUTOMATION_CONFIG_PATH && sed -i 's/^GAME_ASSISTANT.*/GAME_ASSISTANT $v/' $AUTOMATION_CONFIG_PATH || echo 'GAME_ASSISTANT $v' >> $AUTOMATION_CONFIG_PATH")
                                        if (newValue) {
                                            runRoot("settings put secure enabled_accessibility_services com.kanagawa.yamada.project.raco/.GameAssistantService")
                                            runRoot("settings put secure accessibility_enabled 1")
                                        } else {
                                            runRoot("settings put secure enabled_accessibility_services null")
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // DND Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.do_not_disturb), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.enable_dnd_mode_during_gaming_to_block_notifications), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.DoNotDisturbOn, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(12.dp))
                            Text(stringResource(R.string.enable_dnd), modifier = Modifier.weight(1f), fontWeight = FontWeight.Bold)
                            Switch(
                                checked = dndEnabled,
                                onCheckedChange = { newValue ->
                                    dndEnabled = newValue
                                    scope.launch {
                                        val v = if (newValue) "1" else "0"
                                        runRoot("grep -q '^DND' $AUTOMATION_CONFIG_PATH && sed -i 's/^DND.*/DND $v/' $AUTOMATION_CONFIG_PATH || echo 'DND $v' >> $AUTOMATION_CONFIG_PATH")
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // RSWAP Card
            item {
                var rswapEnabled by remember { mutableStateOf(false) }
                var rswapSize by remember { mutableStateOf("4") }
                var expandedRswapSize by remember { mutableStateOf(false) }
                val rswapSizeOptions = listOf("4" to "4 GB", "6" to "6 GB", "8" to "8 GB", "12" to "12 GB")

                LaunchedEffect(Unit) {
                    val config = runRoot("cat $AUTOMATION_CONFIG_PATH")
                    rswapEnabled = Regex("^RSWAP[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
                    rswapSize = Regex("^RSWAP_SIZE[ \\t]+(\\d+)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) ?: "4"
                }

                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.rswap_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.rswap_desc), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Memory, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(12.dp))
                            Text(stringResource(R.string.enable_rswap), modifier = Modifier.weight(1f), fontWeight = FontWeight.Bold)
                            Switch(
                                checked = rswapEnabled,
                                onCheckedChange = { newValue ->
                                    rswapEnabled = newValue
                                    scope.launch {
                                        val v = if (newValue) "1" else "0"
                                        runRoot("grep -q '^RSWAP' $AUTOMATION_CONFIG_PATH && sed -i 's/^RSWAP.*/RSWAP $v/' $AUTOMATION_CONFIG_PATH || echo 'RSWAP $v' >> $AUTOMATION_CONFIG_PATH")
                                        if (newValue) {
                                            runRoot("mkdir -p /data/ProjectRaco")
                                            runRoot("fallocate -l ${rswapSize}G /data/ProjectRaco/RSWAP")
                                            runRoot("mkswap /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                                            runRoot("echo 100 > /proc/sys/vm/swappiness")
                                            runRoot("echo \$(( \$(cat /proc/sys/vm/min_free_kbytes) * 12 / 10 )) > /proc/sys/vm/min_free_kbytes")
                                        } else {
                                            runRoot("swapoff /data/ProjectRaco/RSWAP; rm -f /data/ProjectRaco/RSWAP")
                                        }
                                    }
                                }
                            )
                        }
                        if (rswapEnabled) {
                            var rswapGameLoaded by remember { mutableStateOf<String?>(null) }
                            var rswapUsagePercent by remember { mutableStateOf(0) }
                            var rswapUsedMB by remember { mutableStateOf(0) }
                            var rswapTotalMB by remember { mutableStateOf(0) }

                            LaunchedEffect(Unit) {
                                while(true) {
                                    val stopFile = runRoot("ls /data/ProjectRaco/RSWAPTrack/rswap_stop_* 2>/dev/null").trim()
                                    if (stopFile.isNotEmpty()) {
                                        val firstFile = stopFile.lines().firstOrNull()
                                        if (firstFile != null) {
                                            rswapGameLoaded = firstFile.substringAfterLast("rswap_stop_")
                                        }
                                    } else {
                                        rswapGameLoaded = null
                                    }
                                    
                                    val swaps = runRoot("cat /proc/swaps | grep /data/ProjectRaco/RSWAP").trim()
                                    if (swaps.isNotEmpty()) {
                                        val parts = swaps.split("\\s+".toRegex())
                                        if (parts.size >= 4) {
                                            val size = parts[2].toIntOrNull() ?: 0
                                            val used = parts[3].toIntOrNull() ?: 0
                                            rswapTotalMB = size / 1024
                                            rswapUsedMB = used / 1024
                                            if (size > 0) {
                                                rswapUsagePercent = (used * 100) / size
                                            } else {
                                                rswapUsagePercent = 0
                                            }
                                        }
                                    } else {
                                        rswapTotalMB = 0
                                        rswapUsedMB = 0
                                        rswapUsagePercent = 0
                                    }
                                    kotlinx.coroutines.delay(3000)
                                }
                            }

                            Spacer(Modifier.height(12.dp))
                            HorizontalDivider(color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f))
                            Spacer(Modifier.height(12.dp))

                            Text("Status", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                            Spacer(Modifier.height(4.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Loaded Game:", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                                Text(rswapGameLoaded ?: "None", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = if (rswapGameLoaded != null) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Spacer(Modifier.height(8.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Capacity:", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                                Text("$rswapUsedMB MB / $rswapTotalMB MB ($rswapUsagePercent%)", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                            }
                            Spacer(Modifier.height(4.dp))
                            LinearProgressIndicator(
                                progress = { rswapUsagePercent / 100f },
                                modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                                color = MaterialTheme.colorScheme.primary,
                                trackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)
                            )
                            
                            Spacer(Modifier.height(16.dp))
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                                Text(stringResource(R.string.rswap_size), modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                                Box {
                                    TextButton(onClick = { expandedRswapSize = true }) {
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
                                                    scope.launch {
                                                        runRoot("grep -q '^RSWAP_SIZE' $AUTOMATION_CONFIG_PATH && sed -i 's/^RSWAP_SIZE.*/RSWAP_SIZE $value/' $AUTOMATION_CONFIG_PATH || echo 'RSWAP_SIZE $value' >> $AUTOMATION_CONFIG_PATH")
                                                        runRoot("for file in /data/ProjectRaco/RSWAPTrack/rswap_stop_*; do if [ -f \"\$file\" ]; then pkg=\${file##*_}; for p in \$(pidof \$pkg); do kill -9 \$p; done; rm -f \"\$file\"; fi; done")
                                                        runRoot("swapoff /data/ProjectRaco/RSWAP; rm -f /data/ProjectRaco/RSWAP")
                                                        runRoot("fallocate -l ${value}G /data/ProjectRaco/RSWAP")
                                                        runRoot("mkswap /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                            Button(
                                onClick = { 
                                    scope.launch { 
                                        runRoot("for file in /data/ProjectRaco/RSWAPTrack/rswap_stop_*; do if [ -f \"\$file\" ]; then pkg=\${file##*_}; for p in \$(pidof \$pkg); do kill -9 \$p; done; rm -f \"\$file\"; fi; done")
                                        runRoot("swapoff /data/ProjectRaco/RSWAP; swapon -p 32767 /data/ProjectRaco/RSWAP")
                                    }
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.Default.DeleteSweep, null)
                                Spacer(Modifier.width(8.dp))
                                Text("Manually Clean & Unload RSWAP")
                            }
                        }
                    }
                }
            }
            
            // App List Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.game_app_list), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.manage_the_list_of_apps_that_trigger_performance_mode_automatically), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(16.dp))
                        Button(
                            onClick = { showAppList = true },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.Apps, null)
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.open_app_list))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AppListPage(onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    var enabledPackages by remember { 
        mutableStateOf<List<String>>(sharedPrefs.getStringSet("automation_games", emptySet())?.toList() ?: emptyList()) 
    }
    
    var allInstalledApps by remember { mutableStateOf<List<String>>(emptyList()) }
    var showAddDialog by remember { mutableStateOf(false) }
    var isLoadingAllApps by remember { mutableStateOf(false) }
    
    var isMounted by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isMounted = true }
    
    androidx.activity.compose.BackHandler(enabled = !showAddDialog) {
        onBack()
    }
    
    fun fetchAllApps() {
        isLoadingAllApps = true
        scope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    val pmOutput = runRoot("pm list packages -3")
                    val packages = pmOutput.lines()
                        .filter { it.startsWith("package:") }
                        .map { it.removePrefix("package:").trim() }
                    
                    val pm = context.packageManager
                    packages.sortedBy { pkg ->
                        try {
                            val info = pm.getApplicationInfo(pkg, 0)
                            pm.getApplicationLabel(info).toString().lowercase()
                        } catch (e: Exception) {
                            pkg.lowercase()
                        }
                    }
                }
                allInstalledApps = apps
            } catch (e: Exception) {} finally {
                isLoadingAllApps = false
            }
        }
    }
    
    fun toggleApp(pkg: String, isEnable: Boolean) {
        val newSet = if (isEnable) (enabledPackages + pkg).distinct() else enabledPackages.filter { it != pkg }
        enabledPackages = newSet
        
        val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
        sharedPrefs.edit().putStringSet("automation_games", newSet.toSet()).apply()
    }

    if (showAddDialog) {
        LaunchedEffect(Unit) {
            if (allInstalledApps.isEmpty()) fetchAllApps()
        }
        AlertDialog(
            onDismissRequest = { showAddDialog = false },
            title = { Text(stringResource(R.string.add_app)) },
            text = {
                if (isLoadingAllApps) {
                    Box(modifier = Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else {
                    var dialogSearchQuery by remember { mutableStateOf("") }
                    Column {
                        OutlinedTextField(
                            value = dialogSearchQuery,
                            onValueChange = { dialogSearchQuery = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text(stringResource(R.string.search_apps_hint)) },
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                            singleLine = true
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                            val pm = context.packageManager
                            val filteredApps = allInstalledApps.filter { pkg ->
                                val label = try { pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString() } catch(e: Exception){ pkg }
                                pkg.contains(dialogSearchQuery, ignoreCase = true) || label.contains(dialogSearchQuery, ignoreCase = true)
                            }
                            items(filteredApps) { pkg ->
                                if (!enabledPackages.contains(pkg)) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { 
                                                toggleApp(pkg, true)
                                                showAddDialog = false
                                            }
                                            .padding(vertical = 8.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        AppIcon(pkg = pkg, modifier = Modifier.size(32.dp))
                                        Spacer(modifier = Modifier.width(16.dp))
                                        Column {
                                            AppName(pkg = pkg)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showAddDialog = false }) { Text(stringResource(R.string.close)) }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.game_app_list)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                actions = {
                    IconButton(onClick = { showAddDialog = true }) { Icon(Icons.Default.Add, contentDescription = "Add Game", tint = MaterialTheme.colorScheme.primary) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        containerColor = Color.Transparent
    ) { padding ->
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (isMounted) 1f else 0f,
            animationSpec = androidx.compose.animation.core.tween(150), label = ""
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp).alpha(alpha),
            contentPadding = PaddingValues(top = 8.dp, bottom = 80.dp)
        ) {
            if (enabledPackages.isEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            Icons.Default.RocketLaunch,
                            contentDescription = null,
                            modifier = Modifier.size(80.dp),
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Text(
                            text = "No Games Added",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Tap the + icon in the top right to select games.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                            modifier = Modifier.padding(horizontal = 32.dp)
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Button(
                            onClick = { showAddDialog = true },
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                        ) {
                            Icon(Icons.Default.Add, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(stringResource(R.string.add_app))
                        }
                    }
                }
            } else {
                items(enabledPackages) { pkg ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha=0.2f), MaterialTheme.shapes.medium)
                            .padding(16.dp)
                    ) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                AppIcon(pkg = pkg, modifier = Modifier.size(32.dp))
                                Spacer(modifier = Modifier.width(16.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    AppName(pkg = pkg, color = MaterialTheme.colorScheme.onSurface)
                                }
                                IconButton(onClick = { toggleApp(pkg, false) }) {
                                    Icon(Icons.Default.Delete, contentDescription = "Remove", tint = MaterialTheme.colorScheme.error)
                                }
                            }
                            
                            var gameMode by remember { mutableStateOf(sharedPrefs.getString("game_mode_$pkg", "none") ?: "none") }
                            var expandedGameMode by remember { mutableStateOf(false) }
                            val gameModeOptions = listOf(
                                "none" to stringResource(R.string.game_mode_none),
                                "standard" to stringResource(R.string.game_mode_standard),
                                "performance" to stringResource(R.string.game_mode_performance),
                                "battery" to stringResource(R.string.game_mode_battery)
                            )
                            
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                                Text("CMD Game Mode", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                Box {
                                    TextButton(onClick = { expandedGameMode = true }) {
                                        Text(gameModeOptions.find { it.first == gameMode }?.second ?: "None")
                                    }
                                    DropdownMenu(
                                        expanded = expandedGameMode,
                                        onDismissRequest = { expandedGameMode = false }
                                    ) {
                                        gameModeOptions.forEach { (value, label) ->
                                            DropdownMenuItem(
                                                text = { Text(label) },
                                                onClick = {
                                                    gameMode = value
                                                    sharedPrefs.edit().putString("game_mode_$pkg", value).apply()
                                                    expandedGameMode = false
                                                    scope.launch(Dispatchers.IO) {
                                                        if (value != "none") {
                                                            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd game mode $value $pkg")).waitFor()
                                                        }
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
            }
        }
    }
}
