package com.kanagawa.yamada.project.raco

import androidx.compose.ui.draw.alpha

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import androidx.activity.compose.BackHandler
import androidx.compose.animation.*
import androidx.compose.animation.core.tween

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SlingshotScreen(onBack: () -> Unit) {
    var configApp by remember { mutableStateOf<String?>(null) }
    
    BackHandler(enabled = configApp != null) {
        configApp = null
    }

    Crossfade(
        targetState = configApp,
        label = "SlingshotTransition"
    ) { currentConfigApp ->
        if (currentConfigApp != null) {
            SlingshotConfigScreen(pkg = currentConfigApp, onBack = { configApp = null })
        } else {
            SlingshotMainScreen(onBack = onBack, onOpenConfig = { configApp = it })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SlingshotMainScreen(onBack: () -> Unit, onOpenConfig: (String) -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)

    var addedGames by remember { mutableStateOf<List<String>>(
        sharedPrefs.getStringSet("added_games", emptySet())?.toList() ?: emptyList()
    ) }

    val coroutineScope = rememberCoroutineScope()
    var showAddDialog by remember { mutableStateOf(false) }
    var allInstalledApps by remember { mutableStateOf<List<String>>(emptyList()) }
    var isLoadingAllApps by remember { mutableStateOf(false) }

    fun fetchAllApps() {
        isLoadingAllApps = true
        coroutineScope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "pm list packages -3"))
                    val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
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


    fun addGame(pkg: String) {
        if (!addedGames.contains(pkg)) {
            val newSet = addedGames + pkg
            sharedPrefs.edit().putStringSet("added_games", newSet.toSet()).apply()
            addedGames = newSet
        }
    }

    fun removeGame(pkg: String) {
        val newSet = addedGames.filter { it != pkg }
        sharedPrefs.edit().putStringSet("added_games", newSet.toSet()).apply()
        addedGames = newSet
    }

    if (showAddDialog) {
        LaunchedEffect(Unit) {
            if (allInstalledApps.isEmpty()) {
                fetchAllApps()
            }
        }
        AlertDialog(
            onDismissRequest = { showAddDialog = false },
            title = { Text("Add Game") },
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
                                            addGame(pkg)
                                            showAddDialog = false
                                            onOpenConfig(pkg)
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
                title = { Text(stringResource(R.string.slingshot_title)) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                actions = {
                    IconButton(onClick = { showAddDialog = true }) { Icon(Icons.Default.Add, contentDescription = "Add Game", tint = MaterialTheme.colorScheme.primary) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        }
    ) { pd ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pd).padding(horizontal = 16.dp)) {
            if (addedGames.isEmpty()) {
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
                            text = "Tap the button below or the + icon in the top right to select games for Slingshot.",
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
                            Text("Add Game")
                        }
                    }
                }
            } else {
                items(addedGames) { pkg ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha=0.2f), MaterialTheme.shapes.medium)
                            .clickable { onOpenConfig(pkg) }
                            .padding(16.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            AppIcon(pkg = pkg, modifier = Modifier.size(32.dp))
                            Spacer(modifier = Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                AppName(pkg = pkg, color = MaterialTheme.colorScheme.onSurface)
                            }
                            IconButton(onClick = { removeGame(pkg) }) {
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SlingshotConfigScreen(pkg: String, onBack: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    
    var useAngle by remember { mutableStateOf(sharedPrefs.getBoolean("use_angle_$pkg", false)) }
    var useSkia by remember { mutableStateOf(sharedPrefs.getBoolean("use_skia_$pkg", false)) }
    var usePlayboost by remember { mutableStateOf(sharedPrefs.getBoolean("use_playboost_$pkg", false)) }
    
    var isExecuting by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    fun executeSlingshot() {
        isExecuting = true
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    if (useSkia) {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "setprop debug.hwui.renderer skiavk")).waitFor()
                    }
                    if (useAngle) {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put global angle_gl_driver_selection_pkgs $pkg && settings put global angle_gl_driver_selection_values angle")).waitFor()
                    }
                }
                
                val intent = context.packageManager.getLaunchIntentForPackage(pkg)
                if (intent != null) {
                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                } else {
                    snackbarHostState.showSnackbar("Could not launch app")
                }
                
                snackbarHostState.showSnackbar(context.getString(R.string.payload_deployed_to, pkg))
                
                if (usePlayboost) {
                    coroutineScope.launch(Dispatchers.IO) {
                        Thread.sleep(3000)
                        val script = "pid=\$(pgrep -f $pkg | head -n 1); if [ -n \"\$pid\" ]; then for task in /proc/\$pid/task/*; do tid=\$(basename \$task); taskset -p ffffffff \$tid; done; fi"
                        Runtime.getRuntime().exec(arrayOf("su", "-c", script)).waitFor()
                    }
                }
            } catch (e: Exception) {
            } finally {
                isExecuting = false
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { AppName(pkg = pkg) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = MaterialTheme.colorScheme.primary, navigationIconContentColor = MaterialTheme.colorScheme.primary)
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { executeSlingshot() },
                containerColor = Color(0xFF8B4513),
                contentColor = Color.White,
                icon = { Icon(Icons.Default.RocketLaunch, "Launch") },
                text = { Text(stringResource(R.string.start_preload)) }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { pd ->
        Column(modifier = Modifier.fillMaxSize().padding(pd).padding(16.dp)) {
            AppIcon(pkg = pkg, modifier = Modifier.size(80.dp).align(Alignment.CenterHorizontally))
            Spacer(modifier = Modifier.height(16.dp))
            AppName(pkg = pkg, modifier = Modifier.align(Alignment.CenterHorizontally), style = MaterialTheme.typography.titleLarge, color = Color.White)
            Spacer(modifier = Modifier.height(32.dp))
            
            Text("Configuration", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.height(16.dp))
            
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.angle_title), modifier = Modifier.weight(1f), color = Color.White)
                Switch(checked = useAngle, onCheckedChange = { useAngle = it; sharedPrefs.edit().putBoolean("use_angle_$pkg", it).apply() })
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.skia_title), modifier = Modifier.weight(1f), color = Color.White)
                Switch(checked = useSkia, onCheckedChange = { useSkia = it; sharedPrefs.edit().putBoolean("use_skia_$pkg", it).apply() })
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.playboost_title), modifier = Modifier.weight(1f), color = Color.White)
                Switch(checked = usePlayboost, onCheckedChange = { usePlayboost = it; sharedPrefs.edit().putBoolean("use_playboost_$pkg", it).apply() })
            }
            
            Spacer(modifier = Modifier.height(32.dp))
            androidx.compose.material3.Card(
                colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = androidx.compose.ui.graphics.Color(0xFFFFA726).copy(alpha = 0.1f)),
                border = androidx.compose.foundation.BorderStroke(1.dp, androidx.compose.ui.graphics.Color(0xFFFFA726).copy(alpha = 0.3f)),
                modifier = androidx.compose.ui.Modifier.fillMaxWidth()
            ) {
                androidx.compose.foundation.layout.Row(modifier = androidx.compose.ui.Modifier.padding(12.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.Default.Warning, contentDescription = null, tint = androidx.compose.ui.graphics.Color(0xFFFFA726))
                    androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.width(12.dp))
                    androidx.compose.material3.Text(stringResource(R.string.slingshot_graphics_warning), style = androidx.compose.material3.MaterialTheme.typography.bodySmall, color = androidx.compose.ui.graphics.Color(0xFFFFB74D))
                }
            }
        }
    }
}


private val iconCache = android.util.LruCache<String, androidx.compose.ui.graphics.ImageBitmap>(150)
private val nameCache = android.util.LruCache<String, String>(150)

@Composable
fun AppIcon(pkg: String, modifier: Modifier = Modifier) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var bitmap by remember(pkg) { mutableStateOf(iconCache.get(pkg)) }
    
    if (bitmap == null) {
        LaunchedEffect(pkg) {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                try {
                    val pm = context.packageManager
                    val icon = pm.getApplicationIcon(pkg)
                    val bmp = if (icon is android.graphics.drawable.BitmapDrawable) {
                        icon.bitmap
                    } else {
                        val fallbackBmp = android.graphics.Bitmap.createBitmap(
                            icon.intrinsicWidth.takeIf { it > 0 } ?: 96,
                            icon.intrinsicHeight.takeIf { it > 0 } ?: 96,
                            android.graphics.Bitmap.Config.ARGB_8888
                        )
                        val canvas = android.graphics.Canvas(fallbackBmp)
                        icon.setBounds(0, 0, canvas.width, canvas.height)
                        icon.draw(canvas)
                        fallbackBmp
                    }
                    val imageBitmap = bmp.asImageBitmap()
                    iconCache.put(pkg, imageBitmap)
                    bitmap = imageBitmap
                } catch (e: Exception) {}
            }
        }
    }
    
    if (bitmap != null) {
        androidx.compose.foundation.Image(bitmap = bitmap!!, contentDescription = null, modifier = modifier)
    } else {
        Icon(Icons.Default.Android, contentDescription = null, modifier = modifier, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun AppName(pkg: String, modifier: Modifier = Modifier, style: androidx.compose.ui.text.TextStyle = androidx.compose.material3.LocalTextStyle.current, color: Color = Color.Unspecified, fontWeight: FontWeight? = null, maxLines: Int = Int.MAX_VALUE) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var name by remember(pkg) { mutableStateOf(nameCache.get(pkg) ?: pkg.split(".").last()) }
    
    if (nameCache.get(pkg) == null) {
        LaunchedEffect(pkg) {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                try {
                    val sysConfig = android.content.res.Configuration(android.content.res.Resources.getSystem().configuration)
                    val sysContext = context.createConfigurationContext(sysConfig)
                    val pm = sysContext.packageManager
                    val info = pm.getApplicationInfo(pkg, 0)
                    val label = pm.getApplicationLabel(info).toString()
                    nameCache.put(pkg, label)
                    name = label
                } catch (e: Exception) {}
            }
        }
    }
    
    Text(text = name, modifier = modifier, style = style, color = color, fontWeight = fontWeight, maxLines = maxLines)
}
