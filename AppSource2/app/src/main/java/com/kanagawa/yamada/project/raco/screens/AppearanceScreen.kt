package com.kanagawa.yamada.project.raco.screens

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private const val APPEARANCE_CONFIG_PATH = "/data/ProjectRaco/raco.txt"
private const val BANNER_DEST_PATH = "/data/ProjectRaco/banner.png"

private suspend fun runAppearanceRoot(cmd: String): String = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor(); out
    } catch (e: Exception) { "" }
}

private suspend fun parseAppearanceConfig(): Map<String, String> = withContext(Dispatchers.IO) {
    val content = try {
        val p = ProcessBuilder("su", "-c", "cat $APPEARANCE_CONFIG_PATH").redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor(); out
    } catch (e: Exception) { return@withContext emptyMap() }

    val map = mutableMapOf<String, String>()
    content.lines().forEach { line ->
        val idx = line.indexOf('=')
        if (idx > 0) {
            map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim()
        }
    }
    map
}

private suspend fun writeAppearanceKey(key: String, value: String) = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", "sed -i 's|^$key=.*|$key=$value|' $APPEARANCE_CONFIG_PATH").redirectErrorStream(true).start()
        p.outputStream.close(); p.inputStream.bufferedReader().use { it.readText() }; p.waitFor()
    } catch (e: Exception) {}
}

private suspend fun installBannerImage(context: Context, uri: Uri) = withContext(Dispatchers.IO) {
    try {
        // Copy to app cache first, then push with su
        val cacheFile = File(context.cacheDir, "tmp_banner.png")
        context.contentResolver.openInputStream(uri)?.use { input ->
            cacheFile.outputStream().use { output -> input.copyTo(output) }
        }
        val p = ProcessBuilder("su", "-c", "cp '${cacheFile.absolutePath}' $BANNER_DEST_PATH && chmod 644 $BANNER_DEST_PATH")
            .redirectErrorStream(true).start()
        p.outputStream.close(); p.inputStream.bufferedReader().use { it.readText() }
        val exit = p.waitFor()
        cacheFile.delete()
        exit == 0
    } catch (e: Exception) { false }
}

private suspend fun clearBannerImage() = withContext(Dispatchers.IO) {
    try {
        val p = ProcessBuilder("su", "-c", "rm -f $BANNER_DEST_PATH").redirectErrorStream(true).start()
        p.outputStream.close(); p.inputStream.bufferedReader().use { it.readText() }; p.waitFor()
        true
    } catch (e: Exception) { false }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppearanceScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    var isLoading by remember { mutableStateOf(true) }
    var bannerExists by remember { mutableStateOf(false) }
    var bgOpacity by remember { mutableFloatStateOf(0.3f) }
    var bgBlur by remember { mutableFloatStateOf(10f) }
    var screenBrightness by remember { mutableFloatStateOf(-1f) }
    var rgbR by remember { mutableFloatStateOf(1f) }
    var rgbG by remember { mutableFloatStateOf(1f) }
    var rgbB by remember { mutableFloatStateOf(1f) }
    var isBusy by remember { mutableStateOf(false) }
    var isInstallingBanner by remember { mutableStateOf(false) }

    // Image picker launcher
    val bannerPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            isInstallingBanner = true
            scope.launch {
                try {
                    val destFile = File(context.filesDir, "custom_banner.png")
                    withContext(Dispatchers.IO) {
                        context.contentResolver.openInputStream(uri)?.use { input ->
                            destFile.outputStream().use { output -> input.copyTo(output) }
                        }
                    }
                    context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                        .edit().putString("banner_image_path", destFile.absolutePath).apply()
                    bannerExists = true
                    snackbarHostState.showSnackbar("Banner installed successfully!")
                } catch (e: Exception) {
                    snackbarHostState.showSnackbar("Failed to install banner.")
                }
                isInstallingBanner = false
            }
        }
    }

        LaunchedEffect(Unit) {
            val config = parseAppearanceConfig()
            bgOpacity = config["BG_OPACITY"]?.toFloatOrNull() ?: 0.3f
            bgBlur = config["BG_BLUR"]?.toFloatOrNull() ?: 10f
            val brightnessRaw = config["SCREEN_BRIGHTNESS"]?.toFloatOrNull() ?: -1f
            screenBrightness = brightnessRaw
            rgbR = config["RGB_R"]?.toFloatOrNull() ?: 1f
            rgbG = config["RGB_G"]?.toFloatOrNull() ?: 1f
            rgbB = config["RGB_B"]?.toFloatOrNull() ?: 1f
            val sharedPrefs = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
            val path = sharedPrefs.getString("banner_image_path", "")
            bannerExists = !path.isNullOrEmpty() && File(path).exists()
            isLoading = false
        }

        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.appearance_title)) },
                    navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null) } },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        titleContentColor = MaterialTheme.colorScheme.primary,
                        navigationIconContentColor = MaterialTheme.colorScheme.primary
                    )
                )
            },
            snackbarHost = { SnackbarHost(snackbarHostState) },
            containerColor = MaterialTheme.colorScheme.background
        ) { padding ->
            if (isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    contentAlignment = Alignment.Center
                ) { CircularProgressIndicator() }
                return@Scaffold
            }

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
            ) {

            // Banner Image Card
            item {
                AppearanceCard("Background Banner") {
                    Text(
                        "Set a custom background banner image for the app. Supported format: PNG.",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(Modifier.height(12.dp))

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(
                            imageVector = if (bannerExists) Icons.Default.CheckCircle else Icons.Default.Image,
                            contentDescription = null,
                            tint = if (bannerExists) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = if (bannerExists) "Banner installed" else "No banner set",
                            modifier = Modifier.weight(1f),
                            color = if (bannerExists) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = if (bannerExists) FontWeight.Bold else FontWeight.Normal
                        )
                    }

                    Spacer(Modifier.height(12.dp))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { bannerPickerLauncher.launch("image/png") },
                            modifier = Modifier.weight(1f),
                            enabled = !isInstallingBanner
                        ) {
                            if (isInstallingBanner) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = Color.White)
                                Spacer(Modifier.width(8.dp))
                            } else {
                                Icon(Icons.Default.Upload, null)
                                Spacer(Modifier.width(8.dp))
                            }
                            Text(stringResource(R.string.select_image))
                        }
                        if (bannerExists) {
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        val path = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE).getString("banner_image_path", "")
                                        if (!path.isNullOrEmpty()) { File(path).delete() }
                                        context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE).edit().remove("banner_image_path").apply()
                                        bannerExists = false; snackbarHostState.showSnackbar("Banner removed.")
                                    }
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Icon(Icons.Default.Delete, null)
                                Spacer(Modifier.width(8.dp))
                                Text(stringResource(R.string.remove))
                            }
                        }
                    }
                }
            }

            // Background Opacity Card
            item {
                AppearanceCard("Background Opacity & Blur") {
                    Text(
                        "Controls how the banner image appears. Lower opacity = more transparent. Higher blur = softer.",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(Modifier.height(16.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Opacity, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Opacity: ${(bgOpacity * 100).toInt()}%", modifier = Modifier.weight(1f))
                        if (isBusy) CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    }
                    Slider(
                        value = bgOpacity,
                        onValueChange = { bgOpacity = it },
                        onValueChangeFinished = {
                            scope.launch {
                                writeAppearanceKey("BG_OPACITY", bgOpacity.toString())
                            }
                        },
                        valueRange = 0f..1f,
                        steps = 9
                    )

                    Spacer(Modifier.height(8.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.BlurOn, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Blur: ${bgBlur.toInt()}px", modifier = Modifier.weight(1f))
                    }
                    Slider(
                        value = bgBlur,
                        onValueChange = { bgBlur = it },
                        onValueChangeFinished = {
                            scope.launch {
                                writeAppearanceKey("BG_BLUR", bgBlur.toString())
                            }
                        },
                        valueRange = 0f..30f,
                        steps = 5
                    )
                }
            }

            // Screen Color Modifiers Card
            item {
                AppearanceCard("Screen Color Modifiers") {
                    Text(
                        "Adjust the RGB color multipliers applied globally. 1.0 = no change.",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(Modifier.height(12.dp))

                    listOf(
                        Triple(stringResource(R.string.screen_modifier_red), rgbR, Color(0xFFEF5350)),
                        Triple(stringResource(R.string.screen_modifier_green), rgbG, Color(0xFF66BB6A)),
                        Triple(stringResource(R.string.screen_modifier_blue), rgbB, Color(0xFF42A5F5)),
                    ).forEachIndexed { idx, (label, value, color) ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = label,
                                color = color,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.width(50.dp)
                            )
                            Slider(
                                value = value,
                                onValueChange = { newVal ->
                                    when (idx) {
                                        0 -> rgbR = newVal
                                        1 -> rgbG = newVal
                                        2 -> rgbB = newVal
                                    }
                                },
                                onValueChangeFinished = {
                                    scope.launch {
                                        when (idx) {
                                            0 -> writeAppearanceKey("RGB_R", rgbR.toString())
                                            1 -> writeAppearanceKey("RGB_G", rgbG.toString())
                                            2 -> writeAppearanceKey("RGB_B", rgbB.toString())
                                        }
                                    }
                                },
                                valueRange = 0f..2f,
                                modifier = Modifier.weight(1f),
                                colors = SliderDefaults.colors(thumbColor = color, activeTrackColor = color)
                            )
                            Text(
                                text = String.format("%.2f", value),
                                modifier = Modifier.width(40.dp),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }

                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = {
                            rgbR = 1f; rgbG = 1f; rgbB = 1f
                            scope.launch {
                                writeAppearanceKey("RGB_R", "1.0")
                                writeAppearanceKey("RGB_G", "1.0")
                                writeAppearanceKey("RGB_B", "1.0")
                                snackbarHostState.showSnackbar("Colors reset to default.")
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.RestartAlt, null)
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.reset_to_default))
                    }
                }
            }

            // Screen Brightness Card
            item {
                AppearanceCard("Screen Brightness") {
                    Text(
                        "Override screen brightness (0-255). Set to -1 for automatic.",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(Modifier.height(16.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.Brightness4,
                            null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = if (screenBrightness < 0) "Auto" else "Brightness: ${screenBrightness.toInt()}",
                            modifier = Modifier.weight(1f)
                        )
                    }
                    Slider(
                        value = (screenBrightness + 1f).coerceIn(0f, 256f),
                        onValueChange = { screenBrightness = it - 1f },
                        onValueChangeFinished = {
                            scope.launch {
                                writeAppearanceKey("SCREEN_BRIGHTNESS", screenBrightness.toInt().toString())
                            }
                        },
                        valueRange = 0f..256f,
                        steps = 0
                    )
                }
            }
        }
    }
}

@Composable
private fun AppearanceCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            content()
        }
    }
}
