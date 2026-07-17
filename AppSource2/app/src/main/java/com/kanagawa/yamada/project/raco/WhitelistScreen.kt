package com.kanagawa.yamada.project.raco

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WhitelistScreen(onBack: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    
    var addedApps by remember { mutableStateOf<List<String>>(emptyList()) }
    var showAddDialog by remember { mutableStateOf(false) }
    var allInstalledApps by remember { mutableStateOf<List<String>>(emptyList()) }
    var isLoadingAllApps by remember { mutableStateOf(false) }
    
    val whitelistPath = "/data/ProjectRaco/WhitelistKillAll.txt"

    fun loadWhitelist() {
        coroutineScope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat $whitelistPath"))
                    val reader = BufferedReader(InputStreamReader(process.inputStream))
                    reader.readLines().filter { it.isNotBlank() }
                }
                addedApps = apps
            } catch (e: Exception) {
            }
        }
    }

    LaunchedEffect(Unit) {
        loadWhitelist()
    }

    fun saveWhitelist(newList: List<String>) {
        addedApps = newList
        coroutineScope.launch {
            withContext(Dispatchers.IO) {
                try {
                    val content = newList.joinToString("\n")
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "echo '$content' > $whitelistPath"))
                    process.waitFor()
                } catch (e: Exception) {
                }
            }
        }
    }

    fun fetchAllApps() {
        isLoadingAllApps = true
        coroutineScope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "pm list packages -3"))
                    val reader = BufferedReader(InputStreamReader(process.inputStream))
                    val packages = reader.readLines().map { it.replace("package:", "").trim() }.filter { it.isNotEmpty() }
                    
                    val sysConfig = android.content.res.Configuration(android.content.res.Resources.getSystem().configuration)
                    val sysContext = context.createConfigurationContext(sysConfig)
                    val pm = sysContext.packageManager
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
            } catch (e: Exception) {
            } finally {
                isLoadingAllApps = false
            }
        }
    }

    fun addApp(pkg: String) {
        if (!addedApps.contains(pkg)) {
            saveWhitelist(addedApps + pkg)
        }
    }

    fun removeApp(pkg: String) {
        saveWhitelist(addedApps.filter { it != pkg })
    }

    if (showAddDialog) {
        LaunchedEffect(Unit) {
            if (allInstalledApps.isEmpty()) {
                fetchAllApps()
            }
        }
        AlertDialog(
            onDismissRequest = { showAddDialog = false },
            title = { Text("Add App to Whitelist") },
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
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) }
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                            items(allInstalledApps.filter { it.contains(dialogSearchQuery, ignoreCase = true) }) { pkg ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { 
                                            addApp(pkg)
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
            },
            confirmButton = {
                TextButton(onClick = { showAddDialog = false }) {
                    Text("Close")
                }
            }
        )
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("Kill All Whitelist") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                actions = {
                    IconButton(onClick = { showAddDialog = true }) { Icon(Icons.Default.Add, contentDescription = "Add App", tint = MaterialTheme.colorScheme.primary) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        }
    ) { pd ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pd).padding(horizontal = 16.dp)) {
            if (addedApps.isEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            Icons.Default.Shield,
                            contentDescription = null,
                            modifier = Modifier.size(80.dp),
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Text(
                            text = "No Apps Whitelisted",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Tap the + icon in the top right to add apps that should not be killed during Kill All.",
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
                            Text("Add App")
                        }
                    }
                }
            } else {
                items(addedApps) { pkg ->
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
                            IconButton(onClick = { removeApp(pkg) }) {
                                Icon(Icons.Default.Delete, contentDescription = "Remove", tint = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
            item { Spacer(modifier = Modifier.height(80.dp)) }
        }
    }
}
