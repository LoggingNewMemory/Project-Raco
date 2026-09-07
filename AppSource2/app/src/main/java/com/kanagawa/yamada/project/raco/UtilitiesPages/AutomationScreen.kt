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
import kotlinx.coroutines.sync.withLock
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
    var showRSwapPage by remember { mutableStateOf(false) }

    val context = LocalContext.current
    var isLoading by remember { mutableStateOf(true) }
    var dndEnabled by remember { mutableStateOf(false) }
    var gameAssistantEnabled by remember { mutableStateOf(false) }
    var companionModeEnabled by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    
    LaunchedEffect(Unit) {
        val config = runRoot("cat $AUTOMATION_CONFIG_PATH")
        dndEnabled = Regex("^DND[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
        gameAssistantEnabled = Regex("^GAME_ASSISTANT[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
        companionModeEnabled = Regex("^COMPANION_MODE[ \\t]+(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
        isLoading = false
    }

    if (showAppList) {
        AppListPage(onBack = { showAppList = false }, gameAssistantEnabled = gameAssistantEnabled)
        return
    }
    if (showRSwapPage) {
        RSwapScreen(onBack = { showRSwapPage = false })
        return
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
                                        runRoot("grep -q '^GAME_ASSISTANT ' $AUTOMATION_CONFIG_PATH && sed -i 's/^GAME_ASSISTANT .*/GAME_ASSISTANT $v/' $AUTOMATION_CONFIG_PATH || echo 'GAME_ASSISTANT $v' >> $AUTOMATION_CONFIG_PATH")
                                        if (newValue) {
                                            runRoot("settings put secure accessibility_enabled 1")
                                            runRoot("""CURRENT=${'$'}(settings get secure enabled_accessibility_services); if [ "${'$'}CURRENT" = "null" ] || [ -z "${'$'}CURRENT" ]; then settings put secure enabled_accessibility_services com.kanagawa.yamada.project.raco/.GameAssistantService; else echo "${'$'}CURRENT" | grep -q "com.kanagawa.yamada.project.raco/.GameAssistantService" || settings put secure enabled_accessibility_services "${'$'}CURRENT:com.kanagawa.yamada.project.raco/.GameAssistantService"; fi""")
                                        } else {
                                            runRoot("""CURRENT=${'$'}(settings get secure enabled_accessibility_services); if [ "${'$'}CURRENT" != "null" ] && [ -n "${'$'}CURRENT" ]; then NEW=${'$'}(echo "${'$'}CURRENT" | sed 's|com.kanagawa.yamada.project.raco/.GameAssistantService||g' | sed 's/::/:/g' | sed 's/^://' | sed 's/:${'$'}//'); if [ -z "${'$'}NEW" ]; then settings put secure enabled_accessibility_services null; else settings put secure enabled_accessibility_services "${'$'}NEW"; fi; fi""")
                                            kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                                                RSwapLock.mutex.withLock {
                                                    runRoot("grep -q '^RSWAP ' $AUTOMATION_CONFIG_PATH && sed -i 's/^RSWAP .*/RSWAP 0/' $AUTOMATION_CONFIG_PATH || echo 'RSWAP 0' >> $AUTOMATION_CONFIG_PATH")
                                                    runRoot("swapoff /data/ProjectRaco/RSWAP; rm -f /data/ProjectRaco/RSWAP")
                                                }
                                            }
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            // Companion Mode Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.companion_mode), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.companion_mode_desc), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Group, null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(12.dp))
                            Text(stringResource(R.string.enable_service), modifier = Modifier.weight(1f), fontWeight = FontWeight.Bold)
                            Switch(
                                checked = companionModeEnabled,
                                onCheckedChange = { newValue ->
                                    companionModeEnabled = newValue
                                    scope.launch {
                                        val v = if (newValue) "1" else "0"
                                        runRoot("grep -q '^COMPANION_MODE ' $AUTOMATION_CONFIG_PATH && sed -i 's/^COMPANION_MODE .*/COMPANION_MODE $v/' $AUTOMATION_CONFIG_PATH || echo 'COMPANION_MODE $v' >> $AUTOMATION_CONFIG_PATH")
                                    }
                                }
                            )
                        }
                    }
                }
            }
            // RSWAP Card
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(stringResource(R.string.rswap_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(4.dp))
                        Text(stringResource(R.string.rswap_desc), style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(16.dp))
                        Button(
                            onClick = { showRSwapPage = true },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.Memory, null)
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.rswap_configuration))
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
private fun AppListPage(onBack: () -> Unit, gameAssistantEnabled: Boolean) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    
    var enabledPackages by remember { mutableStateOf<List<String>>(emptyList()) }
    var allInstalledApps by remember { mutableStateOf<List<String>>(emptyList()) }
    var showAddDialog by remember { mutableStateOf(false) }
    var isLoadingAllApps by remember { mutableStateOf(false) }
    
    var isMounted by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        scope.launch {
            try {
                val list = runRoot("cat /data/ProjectRaco/gamelist.txt")
                val rawPackages = list.lines().filter { it.isNotBlank() }
                
                val pm = context.packageManager
                val installedPackages = rawPackages.filter { pkg ->
                    try {
                        pm.getPackageInfo(pkg, 0)
                        true
                    } catch (e: Exception) {
                        false
                    }
                }
                enabledPackages = installedPackages
            } catch (e: Exception) {}
        }
        isMounted = true
    }
    
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
        
        scope.launch(Dispatchers.IO) {
            val safePkg = pkg.replace(".", "\\.")
            if (isEnable) {
                runRoot("grep -q '^[[:space:]]*${safePkg}[[:space:]]*$' /data/ProjectRaco/gamelist.txt || echo '${pkg}' >> /data/ProjectRaco/gamelist.txt")
            } else {
                runRoot("sed -i '/^[[:space:]]*${safePkg}[[:space:]]*$/d' /data/ProjectRaco/gamelist.txt")
            }
        }
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
                    }
                }
            }
        }
    }
}
