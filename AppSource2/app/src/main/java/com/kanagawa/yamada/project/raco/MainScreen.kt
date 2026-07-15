package com.kanagawa.yamada.project.raco

import androidx.compose.ui.draw.alpha

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

@Composable
fun MainScreen(onNavigate: (Screen) -> Unit) {
    val psTitle = stringResource(R.string.power_save)
    val balTitle = stringResource(R.string.balanced)
    val perfTitle = stringResource(R.string.performance)
    val gpTitle = stringResource(R.string.gaming_pro)
    val clrTitle = stringResource(R.string.reset)
    val cdTitle = stringResource(R.string.cooldown_title)
    val context = androidx.compose.ui.platform.LocalContext.current
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    val bannerImagePath = sharedPrefs.getString("banner_image_path", "")

    var currentMode by remember { mutableStateOf("NONE") }
    var hasRoot by remember { mutableStateOf(false) }
    var checkingRoot by remember { mutableStateOf(true) }
    var isExecuting by remember { mutableStateOf(false) }
    var executingMode by remember { mutableStateOf("") }
    var moduleInstalled by remember { mutableStateOf(false) }
    var moduleVersion by remember { mutableStateOf("Unknown") }
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


    LaunchedEffect(Unit) {
        hasRoot = checkRoot()
        if (hasRoot) {
            moduleInstalled = checkModule()
            if (moduleInstalled) {
                moduleVersion = getAppVersion()
            }
            currentMode = fetchActiveMode()
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
        val alpha by androidx.compose.animation.core.animateFloatAsState(
            targetValue = if (checkingRoot) 0f else 1f,
            animationSpec = androidx.compose.animation.core.tween(500), label = ""
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
                                    Icon(Icons.Default.Security, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(stringResource(R.string.root_access_1), style = MaterialTheme.typography.bodySmall)
                                    Text(if (hasRoot) stringResource(R.string.yes) else stringResource(R.string.no), style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = if (hasRoot) Color.Green else MaterialTheme.colorScheme.error)
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
                                    Text(stringResource(R.string.mode_manual), style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold), color = MaterialTheme.colorScheme.primary)
                                }
                            }
                        }
                    }
                    
                    data class ControlMode(val title: String, val descRes: Int, val modeId: String, val modeName: String, val icon: ImageVector)

                    val controlParams = listOf(
                        ControlMode(psTitle, R.string.power_save_desc, "3", "POWER_SAVE", Icons.Default.BatterySaver),
                        ControlMode(balTitle, R.string.balanced_desc, "2", "BALANCED", Icons.Default.Tune),
                        ControlMode(perfTitle, R.string.performance_desc, "1", "PERFORMANCE", Icons.Default.FlashOn),
                        ControlMode(gpTitle, R.string.gaming_desc, "4", "GAMING_PRO", Icons.Default.RocketLaunch),
                        ControlMode(cdTitle, R.string.cooldown_desc, "5", "COOLDOWN", Icons.Default.AcUnit),
                        ControlMode(clrTitle, R.string.clear_desc, "6", "CLEAR", Icons.Default.Refresh)
                    )

                    items(controlParams) { p ->
                        val isCurr = currentMode == p.modeName
                        val isExec = executingMode == p.modeId
                        ControlRow(p.title, stringResource(p.descRes), p.icon, if (isCurr) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant, isExec, isCurr, hasRoot) {
                            executeScript(p.modeId, p.modeName)
                        }
                    }

                    item { Spacer(modifier = Modifier.height(16.dp)) }

                    item {
                        FeatureCard(stringResource(R.string.slingshot_title), Icons.Default.RocketLaunch) { onNavigate(Screen.Slingshot) }
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
fun ControlRow(title: String, desc: String, icon: ImageVector, bgColor: Color, isExecuting: Boolean, isCurrent: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = bgColor),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().clickable(enabled = enabled && !isExecuting) { onClick() }
    ) {
        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal, color = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                Text(desc, style = MaterialTheme.typography.bodySmall, color = if (isCurrent) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (isCurrent) {
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
