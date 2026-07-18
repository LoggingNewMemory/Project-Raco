package com.kanagawa.yamada.project.raco

import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.rememberAsyncImagePainter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import com.kanagawa.yamada.project.raco.Screen
import java.io.File
import kotlin.random.Random

@Composable
fun MainScreen(onNavigate: (Screen) -> Unit) {
    val psTitle = stringResource(R.string.power_save)
    val balTitle = stringResource(R.string.balanced)
    val perfTitle = stringResource(R.string.performance)
    val gpTitle = stringResource(R.string.gaming_pro)
    val clrTitle = stringResource(R.string.reset)
    val cdTitle = stringResource(R.string.cooldown_title)
    val cancelTitle = stringResource(R.string.cancel_execution_title)
    val executionCanceledStr = stringResource(R.string.execution_canceled)
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    val bannerImagePath = sharedPrefs.getString("banner_image_path", "")

    var currentMode by remember { mutableStateOf("NONE") }
    var hasRoot by remember { mutableStateOf(false) }
    var gameAssistantEnabled by remember { mutableStateOf(false) }
    var checkingRoot by remember { mutableStateOf(true) }
    var isExecuting by remember { mutableStateOf(false) }
    var executingMode by remember { mutableStateOf("") }
    var executionProgress by remember { mutableFloatStateOf(0f) }
    var moduleInstalled by remember { mutableStateOf(false) }
    var moduleVersion by remember { mutableStateOf("Unknown") }
    var swipeCount by remember { mutableIntStateOf(0) }
    var executionJob: Job? by remember { mutableStateOf(null) }
    var cooldownTimeRemaining by remember { mutableIntStateOf(0) }
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val configPath = "/data/ProjectRaco/raco.txt"
    val basePath = "/data/adb/modules/ProjectRaco/"

    suspend fun checkRoot(): Boolean = withContext(Dispatchers.IO) {
        try {
            withTimeoutOrNull(3000L) {
                val process = ProcessBuilder("su", "-c", "id").redirectErrorStream(true).start()
                val output = process.inputStream.bufferedReader().use { it.readText() }
                process.waitFor()
                output.contains("uid=0")
            } ?: false
        } catch (e: Exception) { false }
    }

    suspend fun checkModule(): Boolean = withContext(Dispatchers.IO) {
        try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "test -d " + basePath + " && echo yes"))
            process.inputStream.bufferedReader().readText().trim() == "yes"
        } catch(e: Exception) { false }
    }
    
    fun getAppVersion(): String {
        return try {
            val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            pInfo.versionName ?: "Unknown"
        } catch (e: Exception) { "Unknown" }
    }

    suspend fun fetchActiveMode(): String = withContext(Dispatchers.IO) {
        try {
            val output = withTimeoutOrNull(3000L) {
                val process = ProcessBuilder("su", "-c", "awk '/^STATE/ {print $2}' " + configPath).redirectErrorStream(true).start()
                val text = process.inputStream.bufferedReader().use { it.readText().trim() }
                process.waitFor()
                text
            } ?: "NONE"
            when (output) {
                "4" -> "PERFORMANCE"
                "1" -> "BALANCED"
                "2" -> "POWER_SAVE"
                "5" -> "GAMING_PRO"
                "6" -> "COOLDOWN"
                "7" -> "NONE"
                else -> "NONE"
            }
        } catch (e: Exception) { "NONE" }
    }

    suspend fun checkGameAssistant(): Boolean = withContext(Dispatchers.IO) {
        try {
            val output = withTimeoutOrNull(3000L) {
                val process = ProcessBuilder("su", "-c", "grep -q '^GAME_ASSISTANT 1' /data/ProjectRaco/raco.txt").redirectErrorStream(true).start()
                process.waitFor()
            } ?: -1
            output == 0
        } catch (e: Exception) { false }
    }


    LaunchedEffect(Unit) {
        hasRoot = checkRoot()
        if (hasRoot) {
            // Auto-grant notifications permission via root for Android 13+
            withContext(Dispatchers.IO) {
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "pm grant com.kanagawa.yamada.project.raco android.permission.POST_NOTIFICATIONS")).waitFor()
                } catch (e: Exception) {}
            }
            moduleInstalled = checkModule()
            if (moduleInstalled) {
                moduleVersion = getAppVersion()
            }
            currentMode = fetchActiveMode()
            gameAssistantEnabled = checkGameAssistant()
        }
        checkingRoot = false
    }

    fun executeScript(modeArg: String, modeName: String) {
        if (!hasRoot || isExecuting) return
        isExecuting = true
        executingMode = modeArg
        executionProgress = 0f
        executionJob = coroutineScope.launch {
            var wasCancelled = false
            try {
                if (modeName == "COOLDOWN") {
                    withContext(Dispatchers.IO) {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco " + modeArg)).waitFor()
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "grep -q '^STATE' $configPath && sed -i 's|^STATE.*|STATE $modeArg|' $configPath || echo 'STATE $modeArg' >> $configPath")).waitFor()
                    }
                    
                    for (i in 120 downTo 1) {
                        cooldownTimeRemaining = i
                        executionProgress = (120 - i) / 120f
                        delay(1000)
                    }
                    cooldownTimeRemaining = 0
                    executionProgress = 1f
                } else {
                    withContext(Dispatchers.IO) {
                        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco " + modeArg))
                        val reader = process.inputStream.bufferedReader()
                        while (true) {
                            val line = reader.readLine() ?: break
                            if (line.startsWith("PROGRESS:")) {
                                line.substringAfter("PROGRESS:").trim().toFloatOrNull()?.let {
                                    val progressVal = it / 100f
                                    // Keep it at 95% until all background tasks and state saving are completely finished
                                    executionProgress = if (progressVal >= 1f) 0.95f else progressVal
                                }
                                if (line.contains("PROGRESS: 100")) {
                                    break
                                }
                            }
                        }
                        
                        if (modeName != "CLEAR") {
                            // Safely wait for state save so UI correctly updates
                            Runtime.getRuntime().exec(arrayOf("su", "-c", "grep -q '^STATE' $configPath && sed -i 's|^STATE.*|STATE $modeArg|' $configPath || echo 'STATE $modeArg' >> $configPath")).waitFor()
                        }
                        executionProgress = 1f
                    }
                }
                currentMode = if (modeName == "CLEAR") "NONE" else modeName
            } catch (e: CancellationException) {
                wasCancelled = true
            } catch (e: Exception) {
            } finally {
                isExecuting = false
                executingMode = ""
                executionProgress = 0f
                currentMode = fetchActiveMode()
                
                if (modeName == "COOLDOWN" && !wasCancelled && cooldownTimeRemaining == 0) {
                    executeScript("1", "BALANCED")
                }
            }
        }
    }

    fun cancelExecution(canceledText: String) {
        if (!hasRoot) return
        executionJob?.cancel()
        executionJob = null
        coroutineScope.launch {
            withContext(Dispatchers.IO) {
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "killall raco")).waitFor()
                } catch (e: Exception) {}
            }
            isExecuting = false
            executingMode = ""
            executionProgress = 0f
            cooldownTimeRemaining = 0
            currentMode = fetchActiveMode()
            snackbarHostState.showSnackbar(canceledText)
        }
    }

    val scaffoldContent = @Composable { padding: PaddingValues ->
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (checkingRoot) 0f else 1f,
            animationSpec = androidx.compose.animation.core.tween(150), label = ""
        )
        LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 16.dp)
                    .alpha(alpha),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(text = stringResource(R.string.app_title),
                                style = MaterialTheme.typography.headlineSmall,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.clickable { onNavigate(Screen.About) }
                            )
                            Text(text = stringResource(R.string.by_kanagawa_yamada),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Box {
                            var languageExpanded by remember { mutableStateOf(false) }
                            IconButton(onClick = { languageExpanded = true }) {
                                Icon(androidx.compose.material.icons.Icons.Default.Language, contentDescription = "Language", tint = MaterialTheme.colorScheme.primary)
                            }
                            androidx.compose.material3.DropdownMenu(
                                expanded = languageExpanded,
                                onDismissRequest = { languageExpanded = false }
                            ) {
                                val setLang = { code: String ->
                                    languageExpanded = false
                                    androidx.appcompat.app.AppCompatDelegate.setApplicationLocales(androidx.core.os.LocaleListCompat.forLanguageTags(code))
                                }
                                androidx.compose.material3.DropdownMenuItem(text = { Text(stringResource(R.string.english)) }, onClick = { setLang("en") })
                                androidx.compose.material3.DropdownMenuItem(text = { Text(stringResource(R.string.espa_ol)) }, onClick = { setLang("es") })
                                androidx.compose.material3.DropdownMenuItem(text = { Text(stringResource(R.string.bahasa_indonesia)) }, onClick = { setLang("in") })
                                androidx.compose.material3.DropdownMenuItem(text = { Text("日本語") }, onClick = { setLang("ja") })
                                androidx.compose.material3.DropdownMenuItem(text = { Text("Русский") }, onClick = { setLang("ru") })
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                }

                    item {
                        // Banner
                        Card(
                            elevation = CardDefaults.cardElevation(2.dp),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth().clickable { onNavigate(Screen.Raco) }
                        ) {
                            Box(modifier = Modifier.fillMaxWidth().aspectRatio(16f/9f)) {
                                val painter = if (bannerImagePath != null && bannerImagePath.isNotEmpty()) {
                                    rememberAsyncImagePainter(File(bannerImagePath))
                                } else {
                                    androidx.compose.ui.res.painterResource(id = com.kanagawa.yamada.project.raco.R.drawable.banner)
                                }
                                Image(
                                    painter = painter,
                                    contentDescription = "Banner",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize()
                                )
                                val bannerText = if (hasRoot) {
                                    if (moduleInstalled) stringResource(R.string.project_raco_version, moduleVersion) else stringResource(R.string.project_raco_not_installed)
                                } else stringResource(R.string.root_access_required)
                                Box(
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .padding(12.dp)
                                        .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
                                        .padding(horizontal = 12.dp, vertical = 6.dp)
                                ) {
                                    Text(bannerText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                }
                            }
                        }
                    }

                    item {
                        // Status Row
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Card(
                                modifier = Modifier.weight(1f),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Icon(Icons.Default.VideogameAsset, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(stringResource(R.string.game_assistant), style = MaterialTheme.typography.bodySmall)
                                    val gaStatusStr = if (gameAssistantEnabled) stringResource(R.string.status_enabled) else stringResource(R.string.status_disabled)
                                    val gaStatusColor = if (gameAssistantEnabled) Color.Green else MaterialTheme.colorScheme.error
                                    Text(gaStatusStr, style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = gaStatusColor)
                                }
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Card(
                                modifier = Modifier.weight(1f),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Icon(Icons.Default.SettingsInputComponent, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(stringResource(R.string.mode_status), style = MaterialTheme.typography.bodySmall)
                                    val manualText = stringResource(R.string.mode_manual)
                                    val modeText = if (gameAssistantEnabled) "$manualText + GameServ" else manualText
                                    Text(modeText, style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                    
                    data class ControlMode(val title: String, val descRes: Int, val modeId: String, val modeName: String, val icon: ImageVector)

                    val controlParams = listOf(
                        ControlMode(psTitle, R.string.power_save_desc, "2", "POWER_SAVE", Icons.Default.BatterySaver),
                        ControlMode(balTitle, R.string.balanced_desc, "1", "BALANCED", Icons.Default.Tune),
                        ControlMode(perfTitle, R.string.performance_desc, "4", "PERFORMANCE", Icons.Default.FlashOn),
                        ControlMode(gpTitle, R.string.gaming_desc, "5", "GAMING_PRO", Icons.Default.RocketLaunch),
                        ControlMode(cdTitle, R.string.cooldown_desc, "6", "COOLDOWN", Icons.Default.AcUnit),
                        ControlMode(clrTitle, R.string.clear_desc, "7", "CLEAR", Icons.Default.Refresh)
                    )

                    item {
                        androidx.compose.material3.Text(
                            text = stringResource(R.string.cancel_execution_desc),
                            style = MaterialTheme.typography.bodySmall,
                            color = androidx.compose.ui.graphics.Color(0xFFFFB74D),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp, top = 8.dp)
                        )
                    }

                    items(controlParams) { p ->
                        val isCurr = currentMode == p.modeName
                        val isExec = executingMode == p.modeId
                        val bgColor = if (isCurr) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
                        
                        val displayTitle = if (p.modeName == "COOLDOWN" && cooldownTimeRemaining > 0) {
                            String.format("%02d:%02d", cooldownTimeRemaining / 60, cooldownTimeRemaining % 60)
                        } else p.title
                        
                        ControlRow(displayTitle, stringResource(p.descRes), p.icon, bgColor, isExec, if(isExec) executionProgress else 0f, isCurr, hasRoot && !isExecuting, onSwipeRight = {
                            swipeCount++
                            if (swipeCount >= 3) {
                                cancelExecution(executionCanceledStr)
                                swipeCount = 0
                            }
                        }) {
                            executeScript(p.modeId, p.modeName)
                        }
                    }

                    item { Spacer(modifier = Modifier.height(16.dp)) }

                    item {
                        FeatureCard(stringResource(R.string.slingshot_title), Icons.Default.RocketLaunch) { onNavigate(Screen.Slingshot) }
                    }
                    item {
                        FeatureCard(stringResource(R.string.kill_all_whitelist), Icons.Default.List) { onNavigate(Screen.Whitelist) }
                    }
                    item {
                        FeatureCard(stringResource(R.string.utilities_title), Icons.Default.Build) { onNavigate(Screen.Utilities) }
                    }
                    item {

                    }
                    item { Spacer(modifier = Modifier.height(24.dp)) }
                }
        }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent
    ) { padding ->
        scaffoldContent(padding)
    }
}

@Composable
fun ControlRow(title: String, desc: String, icon: ImageVector, bgColor: Color, isExecuting: Boolean, progress: Float, isCurrent: Boolean, enabled: Boolean, onSwipeRight: () -> Unit = {}, onClick: () -> Unit) {
    val fillColor = if (isCurrent) MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.3f) else MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)

    // Smooth animation for progress updates
    val animatedProgress by androidx.compose.animation.core.animateFloatAsState(
        targetValue = progress,
        animationSpec = androidx.compose.animation.core.tween(150),
        label = "progressAnim"
    )

    Card(
        colors = CardDefaults.cardColors(containerColor = bgColor),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().pointerInput(Unit) {
            var totalDrag = 0f
            detectHorizontalDragGestures(
                onDragStart = { totalDrag = 0f },
                onDragEnd = {
                    if (totalDrag > 100f) {
                        onSwipeRight()
                    }
                }
            ) { change, dragAmount ->
                totalDrag += dragAmount
                change.consume()
            }
        }.clickable(enabled = enabled) { onClick() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .drawBehind {
                    if (isExecuting) {
                        drawRect(
                            color = fillColor,
                            size = androidx.compose.ui.geometry.Size(size.width * animatedProgress, size.height)
                        )
                    }
                }
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, contentDescription = null, tint = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal, color = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                Text(desc, style = MaterialTheme.typography.bodySmall, color = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (isExecuting) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    strokeWidth = 2.dp,
                    color = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary
                )
            } else if (isCurrent) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary)
            } else {
                Icon(Icons.Default.ChevronRight, contentDescription = null)
            }
        }
    }
}

@Composable
fun FeatureCard(title: String, icon: ImageVector, onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().clickable { onClick() }
    ) {
        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.width(16.dp))
                Text(title)
            }
            Icon(Icons.Default.ChevronRight, contentDescription = null)
        }
    }
}
