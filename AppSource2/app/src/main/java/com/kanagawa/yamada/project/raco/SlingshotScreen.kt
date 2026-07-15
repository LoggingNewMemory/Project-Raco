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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SlingshotScreen(onBack: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)

    var installedApps by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedApp by remember { mutableStateOf<String?>(null) }
    var selectedMode by remember { mutableStateOf("n") }
    var useAngle by remember { mutableStateOf(sharedPrefs.getBoolean("use_angle", false)) }
    var useSkia by remember { mutableStateOf(sharedPrefs.getBoolean("use_skia", false)) }
    var usePlayboost by remember { mutableStateOf(sharedPrefs.getBoolean("use_playboost", false)) }

    var isLoadingApps by remember { mutableStateOf(true) }
    var isExecuting by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    
    val modes = listOf(
        "n" to stringResource(R.string.slingshot_mode_normal),
        "d" to stringResource(R.string.slingshot_mode_deep),
        "e" to stringResource(R.string.slingshot_mode_extreme),
        "r" to stringResource(R.string.slingshot_mode_recursive)
    )
    val modesMap = modes.toMap()

    fun fetchApps(forceRefresh: Boolean = false) {
        isLoadingApps = true
        coroutineScope.launch {
            try {
                val prefs = context.getSharedPreferences("raco_slingshot", android.content.Context.MODE_PRIVATE)
                val cached = prefs.getString("cached_apps", null)
                
                if (!forceRefresh && !cached.isNullOrEmpty()) {
                    installedApps = cached.split(",")
                    isLoadingApps = false
                    return@launch
                }
                
                val apps = withContext(Dispatchers.IO) {
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "pm list packages -3"))
                    val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
                    val packages = reader.readLines().map { it.replace("package:", "").trim() }.filter { it.isNotEmpty() }
                    
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
                prefs.edit().putString("cached_apps", apps.joinToString(",")).apply()
                installedApps = apps
            } catch (e: Exception) {
            } finally {
                isLoadingApps = false
            }
        }
    }

    LaunchedEffect(Unit) {
        fetchApps()
    }

    fun executeSlingshot() {
        if (selectedApp == null) {
            coroutineScope.launch { snackbarHostState.showSnackbar(context.getString(R.string.no_target_package)) }
            return
        }
        isExecuting = true
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    if (useSkia) {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "setprop debug.hwui.renderer skiavk")).waitFor()
                    }
                    if (useAngle) {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put global angle_gl_driver_selection_pkgs $selectedApp && settings put global angle_gl_driver_selection_values angle")).waitFor()
                    }
                    
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "/data/adb/modules/ProjectRaco/Binaries/kasane -a $selectedApp -m $selectedMode -l")).waitFor()
                    
                    if (usePlayboost) {
                        Thread.sleep(3000)
                        val script = "pid=\$(pgrep -f $selectedApp | head -n 1); if [ -n \"\$pid\" ]; then for task in /proc/\$pid/task/*; do tid=\$(basename \$task); taskset -p ffffffff \$tid; done; fi"
                        Runtime.getRuntime().exec(arrayOf("su", "-c", script)).waitFor()
                    }
                }
                snackbarHostState.showSnackbar(context.getString(R.string.payload_deployed_to, selectedApp))
            } catch (e: Exception) {
            } finally {
                isExecuting = false
            }
        }
    }

    val filteredApps = installedApps.filter { it.contains(searchQuery, ignoreCase = true) }

        val scaffoldContent = @Composable { padding: PaddingValues ->
// STANDARD LAYOUT
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.slingshot_title)) },
                    navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                    actions = {
                        IconButton(onClick = { fetchApps(true) }) { Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = MaterialTheme.colorScheme.primary) }
                    },
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
            val listAlpha by androidx.compose.animation.core.animateFloatAsState(
                targetValue = if (isLoadingApps) 0f else 1f,
                animationSpec = androidx.compose.animation.core.tween(500), label = ""
            )
            LazyColumn(modifier = Modifier.fillMaxSize().padding(pd).padding(horizontal = 16.dp)) {
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)), modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.slingshot_description), style = MaterialTheme.typography.bodyMedium, color = Color.White, modifier = Modifier.padding(16.dp))
                    }
                    Spacer(modifier = Modifier.height(16.dp))

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
                    androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.height(16.dp))

                    var expanded by remember { mutableStateOf(false) }
                    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = !expanded }) {
                        OutlinedTextField(
                            value = modesMap[selectedMode] ?: "",
                            onValueChange = {}, readOnly = true, label = { Text(stringResource(R.string.preload_mode)) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                            modifier = Modifier.fillMaxWidth().menuAnchor()
                        )
                        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                            modes.forEach { (key, label) ->
                                DropdownMenuItem(text = { Text(label) }, onClick = { selectedMode = key; expanded = false })
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.angle_title), modifier = Modifier.weight(1f), color = Color.White)
                        Switch(checked = useAngle, onCheckedChange = { useAngle = it; sharedPrefs.edit().putBoolean("use_angle", it).apply() })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.skia_title), modifier = Modifier.weight(1f), color = Color.White)
                        Switch(checked = useSkia, onCheckedChange = { useSkia = it; sharedPrefs.edit().putBoolean("use_skia", it).apply() })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.playboost_title), modifier = Modifier.weight(1f), color = Color.White)
                        Switch(checked = usePlayboost, onCheckedChange = { usePlayboost = it; sharedPrefs.edit().putBoolean("use_playboost", it).apply() })
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    

                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text(stringResource(R.string.search_apps_hint)) },
                        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) }
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                }

                    items(filteredApps) { pkg ->
                        val isSelected = selectedApp == pkg
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .alpha(listAlpha)
                                .padding(vertical = 4.dp)
                                .background(if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha=0.2f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha=0.2f), MaterialTheme.shapes.medium)
                                .border(1.dp, if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent, MaterialTheme.shapes.medium)
                                .clickable { selectedApp = pkg }
                                .padding(16.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                AppIcon(pkg = pkg, modifier = Modifier.size(32.dp))
                                Spacer(modifier = Modifier.width(16.dp))
                                Column {
                                    AppName(pkg = pkg, color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                    Text(pkg, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                if (isSelected) {
                                    Spacer(modifier = Modifier.weight(1f))
                                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                item { Spacer(modifier = Modifier.height(80.dp)) }
            }
        }
    }
    
    Box(modifier = Modifier.fillMaxSize()) {
        scaffoldContent(PaddingValues(0.dp))
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
                    val pm = context.packageManager
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
