package com.kanagawa.yamada.project.raco.screens

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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.rememberAsyncImagePainter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import com.kanagawa.yamada.project.raco.Screen
import java.io.File
import kotlin.random.Random

// Helper for typewriter effect
@Composable
fun MainTypewriterText(
    text: String,
    style: androidx.compose.ui.text.TextStyle,
    typeDuration: Long = 30L
) {
    var displayedText by remember { mutableStateOf("") }
    
    LaunchedEffect(text) {
        displayedText = ""
        for (i in text.indices) {
            displayedText += text[i]
            delay(typeDuration)
        }
    }
    
    Text(text = displayedText, style = style)
}

@Composable
fun MainScreen(onNavigate: (Screen) -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    val endfieldCollabEnabled = sharedPrefs.getBoolean("endfield_collab_enabled", false)
    val bannerImagePath = sharedPrefs.getString("banner_image_path", "")

    var currentMode by remember { mutableStateOf("NONE") }
    var hasRoot by remember { mutableStateOf(false) }
    var checkingRoot by remember { mutableStateOf(true) }
    var isExecuting by remember { mutableStateOf(false) }
    var executingMode by remember { mutableStateOf("") }
    var moduleInstalled by remember { mutableStateOf(false) }
    var moduleVersion by remember { mutableStateOf("Unknown") }
    var isEndfieldEngineRunning by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val configPath = "/data/ProjectRaco/raco.txt"
    val basePath = "/data/adb/modules/ProjectRaco/"

    // Tips rotation
    val tips = listOf(
        "Ensure Project Raco module is flashed correctly.",
        "Performance mode drains battery faster.",
        "Power Save limits background processes.",
        "Use Cooldown if the device is overheating.",
        "Slingshot speeds up app launching.",
        "Endfield Collab enables industrial UI.",
        "Join Telegram for official support."
    )
    var currentTipIndex by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(8000)
            currentTipIndex = (currentTipIndex + 1) % tips.size
        }
    }

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
    
    suspend fun getModuleVersion(): String = withContext(Dispatchers.IO) {
        try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "grep '^version=' " + basePath + "module.prop"))
            val text = process.inputStream.bufferedReader().readText().trim()
            if (text.contains("=")) text.split("=")[1].trim() else "Unknown"
        } catch (e: Exception) { "Unknown" }
    }

    suspend fun fetchActiveMode(): String = withContext(Dispatchers.IO) {
        try {
            val output = withTimeoutOrNull(3000L) {
                val process = ProcessBuilder("su", "-c", "grep '^STATE=' " + configPath + " | cut -d= -f2").redirectErrorStream(true).start()
                val text = process.inputStream.bufferedReader().use { it.readText().trim() }
                process.waitFor()
                text
            } ?: "NONE"
            when (output) {
                "1" -> "PERFORMANCE"
                "2" -> "BALANCED"
                "3" -> "POWER_SAVE"
                "4" -> "GAMING_PRO"
                "5" -> "COOLDOWN"
                "6" -> "NONE" // CLEAR
                else -> "NONE"
            }
        } catch (e: Exception) { "NONE" }
    }

    suspend fun checkEndfieldProcess(): Boolean = withContext(Dispatchers.IO) {
        try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "pgrep -x Endfield"))
            process.waitFor() == 0
        } catch(e: Exception) { false }
    }

    LaunchedEffect(Unit) {
        hasRoot = checkRoot()
        if (hasRoot) {
            moduleInstalled = checkModule()
            if (moduleInstalled) {
                moduleVersion = getModuleVersion()
            }
            currentMode = fetchActiveMode()
            isEndfieldEngineRunning = checkEndfieldProcess()
        }
        checkingRoot = false
    }

    fun executeScript(modeArg: String, modeName: String) {
        if (!hasRoot || isExecuting) return
        isExecuting = true
        executingMode = modeArg
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "sh " + basePath + "Scripts/Raco.sh " + modeArg + " > /dev/null 2>&1"))
                    process.waitFor()
                }
                currentMode = if (modeName == "CLEAR") "NONE" else modeName
            } catch (e: Exception) {
            } finally {
                isExecuting = false
                executingMode = ""
                currentMode = fetchActiveMode()
            }
        }
    }

    val scaffoldContent = @Composable { padding: PaddingValues ->
        if (endfieldCollabEnabled) {
            // ENDFIELD (CROWDED INDUSTRIAL) LAYOUT
            val techYellow = Color(0xFFFFD700)
            val techBlue = Color(0xFF00BFFF)
            val monoStyle = androidx.compose.ui.text.TextStyle(
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.0.sp
            )
            val integrity = remember { 80 + Random.nextInt(21) }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text("TALOS PROTOCOL V2.0", style = monoStyle.copy(color = Color.White.copy(alpha = 0.38f), fontSize = 10.sp))
                        Text("RACO TERMINAL", style = monoStyle.copy(color = techYellow, fontSize = 24.sp, fontWeight = FontWeight.Black))
                        Box(modifier = Modifier.height(2.dp).width(100.dp).background(techYellow))
                    }
                    IconButton(onClick = { onNavigate(Screen.About) }) {
                        Icon(Icons.Default.Info, contentDescription = "About", tint = techBlue)
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))

                // Banner Block
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f/9f)
                        .border(1.dp, techBlue.copy(alpha = 0.5f))
                        .background(Color.Black)
                        .clickable { onNavigate(Screen.Raco) }
                ) {
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
                    // Scanline
                    Box(modifier = Modifier.fillMaxSize().background(
                        Brush.verticalGradient(
                            0.6f to Color.Transparent,
                            1.0f to Color.Black.copy(alpha = 0.8f)
                        )
                    ))
                    // Tech info
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(8.dp)
                            .background(techYellow)
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        val statusStr = if (moduleInstalled) "ONLINE" else "OFFLINE"
                        Text(
                            "SYSTEM STATUS: " + statusStr + " // V:" + moduleVersion,
                            style = monoStyle.copy(color = Color.Black, fontSize = 10.sp, fontWeight = FontWeight.Black)
                        )
                    }
                    Icon(Icons.Default.Nfc, contentDescription = null, tint = Color.White.copy(alpha = 0.54f), modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).size(16.dp))
                }
                Spacer(modifier = Modifier.height(20.dp))

                // Status Grid
                Row(modifier = Modifier.fillMaxWidth()) {
                    Box(modifier = Modifier.weight(1f).border(1.dp, (if (hasRoot) techBlue else Color.Red).copy(alpha = 0.3f)).background((if (hasRoot) techBlue else Color.Red).copy(alpha = 0.05f)).padding(12.dp)) {
                        Column {
                            Text("ROOT_ACCESS", style = monoStyle.copy(fontSize = 10.sp, color = Color.White.copy(alpha = 0.54f)))
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(if (hasRoot) "YES" else "NO", style = monoStyle.copy(fontSize = 16.sp, color = if (hasRoot) techBlue else Color.Red))
                        }
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Box(modifier = Modifier.weight(1f).border(1.dp, (if (isEndfieldEngineRunning) techYellow else Color.White.copy(alpha = 0.54f)).copy(alpha = 0.3f)).background((if (isEndfieldEngineRunning) techYellow else Color.White.copy(alpha = 0.54f)).copy(alpha = 0.05f)).padding(12.dp)) {
                        Column {
                            Text("ENGINE", style = monoStyle.copy(fontSize = 10.sp, color = Color.White.copy(alpha = 0.54f)))
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(if (isEndfieldEngineRunning) "ACTIVE" else "STANDBY", style = monoStyle.copy(fontSize = 16.sp, color = if (isEndfieldEngineRunning) techYellow else Color.White.copy(alpha = 0.54f)))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))

                // Version Ticker
                Row(modifier = Modifier.fillMaxWidth().border(1.dp, Color.White.copy(alpha = 0.24f)).background(Color.Black.copy(alpha = 0.45f)).padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Memory, contentDescription = null, tint = Color.White.copy(alpha = 0.54f), modifier = Modifier.size(14.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("MODULE: " + moduleVersion, style = monoStyle.copy(color = Color.White, fontSize = 12.sp))
                    Spacer(modifier = Modifier.weight(1f))
                    Text("SYS.RDY", style = monoStyle.copy(color = techBlue, fontSize = 12.sp))
                }
                Spacer(modifier = Modifier.height(24.dp))

                // Mode Selector
                Text("PERFORMANCE PROTOCOLS", style = monoStyle.copy(color = Color.White.copy(alpha = 0.54f), fontSize = 12.sp))
                Spacer(modifier = Modifier.height(8.dp))

                val modes = listOf(
                    Triple("POWER SAVE", "3", techBlue),
                    Triple("BALANCED", "2", techBlue),
                    Triple("PERFORMANCE", "1", techYellow),
                    Triple("GAMING PRO", "4", Color.Red),
                    Triple("COOLDOWN", "5", Color.Cyan),
                    Triple("CLEAR", "6", Color.White)
                )

                // Render in a grid
                Column(modifier = Modifier.fillMaxWidth()) {
                    for (i in modes.indices step 2) {
                        Row(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                            val mode1 = modes[i]
                            Box(modifier = Modifier.weight(1f)) {
                                EndfieldModeBtn(mode1.first, mode1.second, mode1.third, currentMode, executingMode, isEndfieldEngineRunning, monoStyle) {
                                    executeScript(mode1.second, mode1.first.replace(" ", "_"))
                                }
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            if (i + 1 < modes.size) {
                                val mode2 = modes[i+1]
                                Box(modifier = Modifier.weight(1f)) {
                                    EndfieldModeBtn(mode2.first, mode2.second, mode2.third, currentMode, executingMode, isEndfieldEngineRunning, monoStyle) {
                                        executeScript(mode2.second, mode2.first.replace(" ", "_"))
                                    }
                                }
                            } else {
                                Box(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))

                // System Logs
                Box(
                    modifier = Modifier.fillMaxWidth().background(Color.Black).border(1.dp, Color.Transparent).padding(start = 4.dp).background(techYellow, RoundedCornerShape(topStart = 4.dp, bottomStart = 4.dp)).padding(start = 4.dp).background(Color.Black).padding(12.dp)
                ) {
                    Column {
                        Text("SYSTEM LOG", style = monoStyle.copy(color = techYellow, fontSize = 10.sp))
                        Spacer(modifier = Modifier.height(4.dp))
                        Box(modifier = Modifier.height(50.dp)) {
                            MainTypewriterText(
                                text = tips[currentTipIndex] + "\nWaiting for input...\nMemory Integrity: " + integrity + "%",
                                style = monoStyle.copy(color = Color.White.copy(alpha = 0.7f), fontSize = 11.sp)
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))

                // Nav
                Text("EXTERNAL MODULES", style = monoStyle.copy(color = Color.White.copy(alpha = 0.54f), fontSize = 12.sp))
                Spacer(modifier = Modifier.height(8.dp))
                EndfieldNavBtn("SLINGSHOT PRELOADER", "EXEC", Icons.Default.RocketLaunch, techBlue, monoStyle) { onNavigate(Screen.Slingshot) }
                Spacer(modifier = Modifier.height(8.dp))
                EndfieldNavBtn("UTILITIES TOOLS", "OPEN", Icons.Default.Build, Color.White, monoStyle) { onNavigate(Screen.Utilities) }
                Spacer(modifier = Modifier.height(8.dp))

                Spacer(modifier = Modifier.height(24.dp))

                Text("ID: 1234-AB-567", style = monoStyle.copy(color = Color.White.copy(alpha = 0.24f), fontSize = 10.sp))
                Spacer(modifier = Modifier.height(40.dp))
            }
        } else {
            // STANDARD LAYOUT
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 16.dp),
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
                            Text(
                                text = "PROJECT RACO",
                                style = MaterialTheme.typography.headlineSmall,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.clickable { onNavigate(Screen.About) }
                            )
                            Text(
                                text = "By Kanagawa Yamada",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                }

                if (checkingRoot) {
                    item {
                        Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                        }
                    }
                } else {
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
                                    if (moduleInstalled) "Project Raco " + moduleVersion else "Project Raco Not Installed"
                                } else "Root Access Required"
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
                                    Icon(Icons.Default.Security, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text("Root Access", style = MaterialTheme.typography.bodySmall)
                                    Text(if (hasRoot) "Yes" else "No", style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = if (hasRoot) Color.Green else MaterialTheme.colorScheme.error)
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
                                    Text("Mode Status", style = MaterialTheme.typography.bodySmall)
                                    Text(if (isEndfieldEngineRunning) "Endfield Engine" else "Manual", style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                    
                    item {
                        // Tips
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp))
                                .padding(horizontal = 16.dp, vertical = 12.dp)
                        ) {
                            Column {
                                Row {
                                    Icon(Icons.Default.Lightbulb, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text("Tip of the day", style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold), color = MaterialTheme.colorScheme.primary)
                                }
                                Spacer(modifier = Modifier.height(6.dp))
                                Box(modifier = Modifier.height(40.dp)) {
                                    MainTypewriterText(tips[currentTipIndex], MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant))
                                }
                            }
                        }
                    }

                    val controlParams = listOf(
                        Triple("Power Save", "Battery optimization", Pair("3", "POWER_SAVE")),
                        Triple("Balanced", "Everyday usage", Pair("2", "BALANCED")),
                        Triple("Performance", "Maximized output", Pair("1", "PERFORMANCE")),
                        Triple("Gaming Pro", "Maximum performance", Pair("4", "GAMING_PRO")),
                        Triple("Cooldown", "Thermal throttle", Pair("5", "COOLDOWN")),
                        Triple("Clear", "Reset state", Pair("6", "CLEAR"))
                    )

                    items(controlParams) { p ->
                        val isCurr = currentMode == p.third.second
                        val isExec = executingMode == p.third.first
                        ControlRow(p.first, p.second, if (isCurr) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant, isExec, isCurr, hasRoot) {
                            executeScript(p.third.first, p.third.second)
                        }
                    }

                    item { Spacer(modifier = Modifier.height(16.dp)) }

                    item {
                        FeatureCard("Slingshot", Icons.Default.RocketLaunch) { onNavigate(Screen.Slingshot) }
                    }
                    item {
                        FeatureCard("Utilities", Icons.Default.Build) { onNavigate(Screen.Utilities) }
                    }
                    item {

                    }

                    item { Spacer(modifier = Modifier.height(24.dp)) }
                }
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        scaffoldContent(padding)
    }
}

@Composable
fun EndfieldModeBtn(label: String, scriptArg: String, color: Color, currentMode: String, executingMode: String, isEndfieldRunning: Boolean, style: androidx.compose.ui.text.TextStyle, onClick: () -> Unit) {
    val modeKey = label.replace(" ", "_")
    val isSelected = currentMode == modeKey
    val isExecuting = executingMode == scriptArg

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) color else Color.White.copy(alpha=0.24f))
            .background(if (isSelected) color.copy(alpha=0.2f) else Color.Black.copy(alpha=0.3f))
            .clickable(enabled = !isEndfieldRunning && !isExecuting) { onClick() }
            .padding(16.dp)
    ) {
        Column {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Icon(Icons.Default.Settings, contentDescription = null, tint = if (isSelected) color else Color.White.copy(alpha=0.54f), modifier = Modifier.size(20.dp))
                if (isExecuting) {
                    CircularProgressIndicator(color = color, modifier = Modifier.size(12.dp), strokeWidth = 2.dp)
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(label, style = style.copy(fontSize = 13.sp, color = Color.White))
            Spacer(modifier = Modifier.height(4.dp))
            Text(if (isSelected) "STATUS: ACTIVE" else "STATUS: READY", style = style.copy(fontSize = 8.sp, color = if (isSelected) color else Color.White.copy(alpha=0.24f)))
        }
    }
}

@Composable
fun EndfieldNavBtn(title: String, tag: String, icon: ImageVector, color: Color, style: androidx.compose.ui.text.TextStyle, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, color.copy(alpha=0.5f))
            .background(color.copy(alpha=0.1f))
            .clickable { onClick() }
            .padding(vertical = 16.dp, horizontal = 12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = color)
            Spacer(modifier = Modifier.width(12.dp))
            Text(title, style = style.copy(fontSize = 16.sp, color = Color.White), modifier = Modifier.weight(1f))
            Text(tag, style = style.copy(fontSize = 12.sp, color = color))
        }
    }
}

@Composable
fun ControlRow(title: String, desc: String, bgColor: Color, isExecuting: Boolean, isCurrent: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = bgColor),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().clickable(enabled = enabled && !isExecuting) { onClick() }
    ) {
        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Settings, contentDescription = null, tint = if (isCurrent) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal, color = if (isCurrent) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface)
                Text(desc, style = MaterialTheme.typography.bodySmall, color = if (isCurrent) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (isExecuting) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
            } else if (isCurrent) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimaryContainer)
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
