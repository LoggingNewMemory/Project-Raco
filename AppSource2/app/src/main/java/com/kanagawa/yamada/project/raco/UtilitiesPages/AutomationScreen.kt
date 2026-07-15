package com.kanagawa.yamada.project.raco.UtilitiesPages

import androidx.compose.ui.draw.alpha

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import android.content.pm.PackageManager
import android.graphics.drawable.BitmapDrawable
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

private const val GAME_TXT_PATH = "/data/ProjectRaco/game.txt"
private const val GAME_LIST_DB_PATH = "/data/adb/modules/ProjectRaco/game_list.txt"
private const val AUTOMATION_CONFIG_PATH = "/data/ProjectRaco/raco.txt"

private data class AppEntry(
    val name: String,
    val packageName: String
)

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

    var isLoading by remember { mutableStateOf(true) }
    var dndEnabled by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        val config = runRoot("cat $AUTOMATION_CONFIG_PATH")
        dndEnabled = Regex("^DND=(\\d)", RegexOption.MULTILINE).find(config)?.groupValues?.getOrNull(1) == "1"
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
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (isLoading) 0f else 1f,
            animationSpec = androidx.compose.animation.core.tween(500), label = ""
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp).alpha(alpha),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
        ) {
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
                                        runRoot("sed -i 's|^DND=.*|DND=$v|' $AUTOMATION_CONFIG_PATH")
                                    }
                                }
                            )
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
    var isLoading by remember { mutableStateOf(true) }
    var allApps by remember { mutableStateOf<List<AppEntry>>(emptyList()) }
    var enabledPackages by remember { mutableStateOf<Set<String>>(emptySet()) }
    var recommendedPackages by remember { mutableStateOf<Set<String>>(emptySet()) }
    var searchQuery by remember { mutableStateOf("") }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            // Load enabled packages
            val gameTxt = try {
                val p = ProcessBuilder("su", "-c", "cat $GAME_TXT_PATH").redirectErrorStream(true).start()
                p.outputStream.close(); val out = p.inputStream.bufferedReader().use { it.readText() }; p.waitFor(); out
            } catch (e: Exception) { "" }
            enabledPackages = gameTxt.lines().map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith("#") }.toSet()

            // Load recommended
            val dbTxt = try {
                val p = ProcessBuilder("su", "-c", "cat $GAME_LIST_DB_PATH").redirectErrorStream(true).start()
                p.outputStream.close(); val out = p.inputStream.bufferedReader().use { it.readText() }; p.waitFor(); out
            } catch (e: Exception) { "" }
            recommendedPackages = dbTxt.lines().map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith("#") && !it.startsWith("[") }.toSet()

            // Load installed user apps via pm list
            val pm = context.packageManager
            val pmOutput = try {
                val p = ProcessBuilder("su", "-c", "pm list packages -3").redirectErrorStream(true).start()
                p.outputStream.close(); val out = p.inputStream.bufferedReader().use { it.readText() }; p.waitFor(); out
            } catch (e: Exception) { "" }

            val apps = pmOutput.lines()
                .filter { it.startsWith("package:") }
                .map { it.removePrefix("package:").trim() }
                .mapNotNull { pkg ->
                    try {
                        val info = pm.getApplicationInfo(pkg, 0)
                        AppEntry(pm.getApplicationLabel(info).toString(), pkg)
                    } catch (e: Exception) { AppEntry(pkg, pkg) }
                }
                .sortedWith(compareByDescending<AppEntry> { enabledPackages.contains(it.packageName) }.thenBy { it.name.lowercase() })
            allApps = apps
        }
        isLoading = false
    }

    fun toggleApp(pkg: String) {
        val isEnable = !enabledPackages.contains(pkg)
        enabledPackages = if (isEnable) enabledPackages + pkg else enabledPackages - pkg
        scope.launch {
            if (isEnable) {
                runRoot("echo '$pkg' >> $GAME_TXT_PATH")
                snackbarHostState.showSnackbar(context.getString(R.string.added_to_gamelist).replace("{package}", pkg), duration = SnackbarDuration.Short)
            } else {
                val escaped = pkg.replace(".", "\\.")
                runRoot("sed -i '/^$escaped\$/d' $GAME_TXT_PATH")
                snackbarHostState.showSnackbar(context.getString(R.string.removed_from_gamelist).replace("{package}", pkg), duration = SnackbarDuration.Short)
            }
        }
    }

    val filteredApps = if (searchQuery.isEmpty()) allApps else {
        allApps.filter { it.name.lowercase().contains(searchQuery.lowercase()) || it.packageName.lowercase().contains(searchQuery.lowercase()) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_list)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                actions = {
                    IconButton(onClick = { /* trigger refresh */ }) {
                        Icon(Icons.Default.Refresh, null)
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text(stringResource(R.string.search_apps_hint)) },
                leadingIcon = { Icon(Icons.Default.Search, null) },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                shape = RoundedCornerShape(30.dp),
                singleLine = true
            )

            val alpha2 by androidx.compose.animation.core.animateFloatAsState(
                targetValue = if (isLoading) 0f else 1f,
                animationSpec = androidx.compose.animation.core.tween(500), label = ""
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize().alpha(alpha2),
                contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 4.dp, bottom = 80.dp)
                ) {
                    items(filteredApps) { app ->
                        val isEnabled = enabledPackages.contains(app.packageName)
                        val isRecommended = recommendedPackages.contains(app.packageName)
                        Card(
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable { toggleApp(app.packageName) }
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                // App icon
                                Box(
                                    modifier = Modifier.size(50.dp).clip(RoundedCornerShape(12.dp)).background(Color.Gray.copy(0.3f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    val iconDrawable = remember(app.packageName) {
                                        try { context.packageManager.getApplicationIcon(app.packageName) } catch (e: Exception) { null }
                                    }
                                    if (iconDrawable is BitmapDrawable) {
                                        Image(
                                            bitmap = iconDrawable.bitmap.asImageBitmap(),
                                            contentDescription = null,
                                            modifier = Modifier.fillMaxSize()
                                        )
                                    } else {
                                        Icon(Icons.Default.Android, null, tint = Color.White.copy(0.5f))
                                    }
                                }

                                Spacer(Modifier.width(16.dp))

                                Column(Modifier.weight(1f)) {
                                    Text(app.name, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                                    Text(app.packageName, fontSize = 12.sp, color = Color.White.copy(0.5f), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                                    Spacer(Modifier.height(8.dp))
                                    Row {
                                        AppBadge(if (isEnabled) stringResource(R.string.status_enabled) else stringResource(R.string.status_disabled), if (isEnabled) Color(0xFF4CAF50) else Color(0xFFE57373))
                                        if (isRecommended) {
                                            Spacer(Modifier.width(8.dp))
                                            AppBadge(stringResource(R.string.status_recommended), Color(0xFFF06292))
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
private fun AppBadge(text: String, color: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.2f))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(text, color = color, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)
    }
}
