package com.kanagawa.yamada.project.raco.screens

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
    val endfieldCollabEnabled = false

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
        "n" to "Normal (fadvise hint)",
        "d" to "Deep (fadvise + dlopen)",
        "e" to "Extreme (mmap + MAP_POPULATE)",
        "r" to "Recursive (looped deep check)"
    )
    val modesMap = modes.toMap()

    fun fetchApps() {
        isLoadingApps = true
        coroutineScope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "pm list packages -3"))
                    val reader = BufferedReader(InputStreamReader(process.inputStream))
                    reader.readLines().map { it.replace("package:", "").trim() }.filter { it.isNotEmpty() }.sorted()
                }
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
            coroutineScope.launch { snackbarHostState.showSnackbar("NO TARGET PACKAGE SELECTED") }
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
                snackbarHostState.showSnackbar("PAYLOAD DEPLOYED TO $selectedApp")
            } catch (e: Exception) {
            } finally {
                isExecuting = false
            }
        }
    }

    val filteredApps = installedApps.filter { it.contains(searchQuery, ignoreCase = true) }

    val scaffoldContent = @Composable { padding: PaddingValues ->
        if (endfieldCollabEnabled) {
            // ENDFIELD LAYOUT
            val techYellow = Color(0xFFFFD700)
            val techBlue = Color(0xFF00BFFF)
            val bgDark = Color(0xFF0D0D0D)
            val monoStyle = androidx.compose.ui.text.TextStyle(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp
            )

            Scaffold(
                containerColor = Color.Transparent,
                topBar = {
                    TopAppBar(
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                        navigationIcon = {
                            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = techBlue) }
                        },
                        title = { Text("PAYLOAD // SELECTOR", style = monoStyle.copy(color = techYellow, fontSize = 18.sp)) },
                        actions = {
                            IconButton(onClick = { fetchApps() }) { Icon(Icons.Default.Refresh, contentDescription = null, tint = Color.White.copy(alpha=0.54f)) }
                        }
                    )
                },
                floatingActionButton = {
                    Box(
                        modifier = Modifier
                            .background(techYellow)
                            .border(2.dp, Color.White)
                            .clickable { executeSlingshot() }
                            .padding(horizontal = 24.dp, vertical = 12.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.RocketLaunch, contentDescription = null, tint = Color.Black, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("INITIATE SEQUENCE", style = monoStyle.copy(color = Color.Black, fontWeight = FontWeight.Black))
                        }
                    }
                },
                snackbarHost = { SnackbarHost(snackbarHostState) }
            ) { pd ->
                LazyColumn(modifier = Modifier.fillMaxSize().padding(pd)) {
                    item {
                        // Top Control Panel
                        Column(
                            modifier = Modifier
                                .padding(horizontal = 16.dp)
                                .border(1.dp, techBlue.copy(alpha=0.5f))
                                .background(Color.Black.copy(alpha=0.6f))
                                .padding(12.dp)
                        ) {
                            Text("// SYSTEM OVERRIDES", style = monoStyle.copy(color = techBlue, fontSize = 10.sp))
                            Spacer(modifier = Modifier.height(8.dp))
                            
                            EndfieldSwitch("ANGLE_DRIVER", useAngle) { useAngle = it }
                            Spacer(modifier = Modifier.height(8.dp))
                            EndfieldSwitch("SKIA_RENDERER", useSkia) { useSkia = it }
                            Spacer(modifier = Modifier.height(8.dp))
                            EndfieldSwitch("P-BOOST", usePlayboost) { usePlayboost = it }
                            
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("// EXECUTION MODE", style = monoStyle.copy(color = techBlue, fontSize = 10.sp))
                            Spacer(modifier = Modifier.height(4.dp))
                            
                            var expanded by remember { mutableStateOf(false) }
                            Box(modifier = Modifier.fillMaxWidth().height(40.dp).border(1.dp, Color.White.copy(alpha=0.24f)).background(Color.Black)) {
                                Row(
                                    modifier = Modifier.fillMaxSize().clickable { expanded = true }.padding(horizontal = 16.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(modesMap[selectedMode] ?: "", style = monoStyle.copy(color = Color.White))
                                    Icon(Icons.Default.ArrowDropDown, contentDescription = null, tint = techYellow)
                                }
                                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                                    modes.forEach { (key, label) ->
                                        DropdownMenuItem(
                                            text = { Text(label, style = monoStyle.copy(color = Color.Black)) },
                                            onClick = { selectedMode = key; expanded = false }
                                        )
                                    }
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                    }

                    item {
                        // Search Bar

                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                            textStyle = monoStyle.copy(color = Color.White),
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = techYellow) },
                            placeholder = { Text("SEARCH_TARGET_PACKAGE...", style = monoStyle.copy(color = Color.White.copy(alpha=0.24f), fontSize = 12.sp)) },
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedContainerColor = Color.Black.copy(alpha=0.54f),
                                unfocusedContainerColor = Color.Black.copy(alpha=0.54f),
                                focusedBorderColor = techYellow,
                                unfocusedBorderColor = Color.White.copy(alpha=0.24f)
                            ),
                            shape = RoundedCornerShape(0.dp)
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                    }

                    item {
                        Box(modifier = Modifier.fillMaxWidth().background(Color.Black.copy(alpha=0.5f)).padding(horizontal = 16.dp, vertical = 4.dp)) {
                            Text("AVAILABLE TARGETS: ${filteredApps.size}", style = monoStyle.copy(color = Color.White.copy(alpha=0.54f), fontSize = 10.sp))
                        }
                    }

                    if (isLoadingApps) {
                        item { Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = techYellow) } }
                    } else {
                        items(filteredApps) { pkg ->
                            val isSelected = selectedApp == pkg
                            Box(
                                modifier = Modifier
                                    .padding(horizontal = 16.dp, vertical = 2.dp)
                                    .border(1.dp, if (isSelected) techYellow else Color.White.copy(alpha=0.12f))
                                    .background(if (isSelected) techYellow.copy(alpha=0.1f) else Color.Black.copy(alpha=0.3f))
                                    .clickable { selectedApp = pkg }
                                    .padding(8.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(modifier = Modifier.size(40.dp).border(1.dp, Color.White.copy(alpha=0.24f)).padding(2.dp)) {
                                        Icon(Icons.Default.Android, contentDescription = null, tint = Color.White.copy(alpha=0.54f), modifier = Modifier.align(Alignment.Center))
                                    }
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(pkg.split(".").last().uppercase(), style = monoStyle.copy(color = Color.White, fontSize = 14.sp), maxLines = 1)
                                        Text(pkg, style = monoStyle.copy(color = Color.White.copy(alpha=0.38f), fontSize = 10.sp), maxLines = 1)
                                    }
                                    if (isSelected) {
                                        Box(modifier = Modifier.background(techYellow).padding(horizontal = 8.dp, vertical = 2.dp)) {
                                            Text("LOCKED", style = monoStyle.copy(color = Color.Black, fontSize = 10.sp, fontWeight = FontWeight.Bold))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    item { Spacer(modifier = Modifier.height(80.dp)) }
                }
            }
        } else {
            // STANDARD LAYOUT
            Scaffold(
                containerColor = Color.Transparent,
                topBar = {
                    TopAppBar(
                        title = { Text("Raco Slingshot") },
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
                        text = { Text("Start Slingshot") }
                    )
                },
                snackbarHost = { SnackbarHost(snackbarHostState) }
            ) { pd ->
                LazyColumn(modifier = Modifier.fillMaxSize().padding(pd).padding(horizontal = 16.dp)) {
                    item {
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)), modifier = Modifier.fillMaxWidth()) {
                            Text("Preload your app files before launching the app, this may speed up the loading time and improve performance", style = MaterialTheme.typography.bodyMedium, color = Color.White, modifier = Modifier.padding(16.dp))
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
                                androidx.compose.material3.Text("Some games might broken, Some might improve performance, Some might don't even Launch. But don't be afraid to try it first!", style = androidx.compose.material3.MaterialTheme.typography.bodySmall, color = androidx.compose.ui.graphics.Color(0xFFFFB74D))
                            }
                        }
                        androidx.compose.foundation.layout.Spacer(modifier = androidx.compose.ui.Modifier.height(16.dp))

                        var expanded by remember { mutableStateOf(false) }
                        ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = !expanded }) {
                            OutlinedTextField(
                                value = modesMap[selectedMode] ?: "",
                                onValueChange = {}, readOnly = true, label = { Text("Preload Mode") },
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
                            Text("Launch using ANGLE Graphics", modifier = Modifier.weight(1f), color = Color.White)
                            Switch(checked = useAngle, onCheckedChange = { useAngle = it; sharedPrefs.edit().putBoolean("use_angle", it).apply() })
                        }
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                            Text("Use SkiaVK as default Skia backend", modifier = Modifier.weight(1f), color = Color.White)
                            Switch(checked = useSkia, onCheckedChange = { useSkia = it; sharedPrefs.edit().putBoolean("use_skia", it).apply() })
                        }
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                            Text("RiProG Playboost", modifier = Modifier.weight(1f), color = Color.White)
                            Switch(checked = usePlayboost, onCheckedChange = { usePlayboost = it; sharedPrefs.edit().putBoolean("use_playboost", it).apply() })
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                        

                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("Search apps...") },
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) }
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    if (isLoadingApps) {
                        item { Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
                    } else {
                        items(filteredApps) { pkg ->
                            val isSelected = selectedApp == pkg
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp)
                                    .background(if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha=0.2f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha=0.2f), MaterialTheme.shapes.medium)
                                    .border(1.dp, if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent, MaterialTheme.shapes.medium)
                                    .clickable { selectedApp = pkg }
                                    .padding(16.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Android, contentDescription = null, modifier = Modifier.size(32.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(modifier = Modifier.width(16.dp))
                                    Column {
                                        Text(pkg.split(".").last().uppercase(), color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                        Text(pkg, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                    if (isSelected) {
                                        Spacer(modifier = Modifier.weight(1f))
                                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    }
                                }
                            }
                        }
                    }
                    item { Spacer(modifier = Modifier.height(80.dp)) }
                }
            }
        }
    }
    
    Box(modifier = Modifier.fillMaxSize()) {
        scaffoldContent(PaddingValues(0.dp))
    }
}

@Composable
fun EndfieldSwitch(label: String, value: Boolean, onChanged: (Boolean) -> Unit) {
    val techYellow = Color(0xFFFFD700)
    val monoStyle = androidx.compose.ui.text.TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold
    )
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(40.dp)
            .border(1.dp, if (value) techYellow else Color.White.copy(alpha=0.24f))
            .background(if (value) techYellow else Color.Transparent)
            .clickable { onChanged(!value) }
            .padding(horizontal = 16.dp)
    ) {
        Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, style = monoStyle.copy(color = if (value) Color.Black else Color.White.copy(alpha=0.54f), fontSize = 10.sp))
            Box(modifier = Modifier.size(8.dp).background(if (value) Color.Black else Color.White.copy(alpha=0.54f)))
        }
    }
}
