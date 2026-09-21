package com.kanagawa.yamada.project.raco.UtilitiesPages

import com.kanagawa.yamada.project.raco.ui.theme.GlassCard

import androidx.compose.ui.draw.alpha

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.animation.AnimatedVisibility
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
        val idx = line.indexOf(' ')
        if (idx > 0) {
            map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim()
        }
    }
    map
}

private suspend fun writeAppearanceKey(key: String, value: String) = withContext(Dispatchers.IO) {
    try {
        val cmd = "grep -q '^$key ' $APPEARANCE_CONFIG_PATH && sed -i 's|^$key .*|$key $value|' $APPEARANCE_CONFIG_PATH || echo '$key $value' >> $APPEARANCE_CONFIG_PATH"
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
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
    var bgExists by remember { mutableStateOf(false) }
    var bgOpacity by remember { mutableFloatStateOf(0.3f) }
    var bgBlur by remember { mutableFloatStateOf(10f) }
    var isBusy by remember { mutableStateOf(false) }
    var isInstallingBanner by remember { mutableStateOf(false) }
    var isInstallingBg by remember { mutableStateOf(false) }
    var adaptiveColorBg by remember { mutableStateOf(false) }
    var meshHue by remember { mutableFloatStateOf(260f) }
    var meshSat by remember { mutableFloatStateOf(0.6f) }
    var meshVal by remember { mutableFloatStateOf(0.96f) }
    var meshEnabled by remember { mutableStateOf(true) }

    val bannerCropLauncher = rememberLauncherForActivityResult(com.canhub.cropper.CropImageContract()) { result ->
        if (result.isSuccessful) {
            val uriContent = result.uriContent
            if (uriContent != null) {
                isInstallingBanner = true
                scope.launch {
                    try {
                        val destFile = File(context.filesDir, "custom_banner.png")
                        withContext(Dispatchers.IO) {
                            context.contentResolver.openInputStream(uriContent)?.use { input ->
                                destFile.outputStream().use { output -> input.copyTo(output) }
                            }
                        }
                        context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                            .edit()
                            .putString("banner_image_path", destFile.absolutePath)
                            .putLong("banner_update_timestamp", System.currentTimeMillis())
                            .apply()
                        bannerExists = true
                        snackbarHostState.showSnackbar(context.getString(R.string.banner_installed_successfully))
                    } catch (e: Exception) {
                        snackbarHostState.showSnackbar(context.getString(R.string.failed_to_install_banner))
                    }
                    isInstallingBanner = false
                }
            }
        }
    }

    val bannerPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        uri?.let {
            bannerCropLauncher.launch(
                com.canhub.cropper.CropImageContractOptions(
                    uri = it,
                    cropImageOptions = com.canhub.cropper.CropImageOptions(
                        aspectRatioX = 16,
                        aspectRatioY = 9,
                        fixAspectRatio = true,
                        activityBackgroundColor = android.graphics.Color.BLACK,
                        toolbarColor = android.graphics.Color.parseColor("#111111"),
                        activityMenuIconColor = android.graphics.Color.WHITE,
                        toolbarTitleColor = android.graphics.Color.WHITE
                    )
                )
            )
        }
    }

    val bgPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            isInstallingBg = true
            scope.launch {
                try {
                    val destFile = File(context.filesDir, "custom_background.png")
                    withContext(Dispatchers.IO) {
                        context.contentResolver.openInputStream(uri)?.use { input ->
                            destFile.outputStream().use { output -> input.copyTo(output) }
                        }
                    }
                    context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                        .edit().putString("background_image_path", destFile.absolutePath).apply()
                    bgExists = true
                    snackbarHostState.showSnackbar("Background installed successfully")
                } catch (e: Exception) {
                    snackbarHostState.showSnackbar("Failed to install background")
                }
                isInstallingBg = false
            }
        }
    }

        LaunchedEffect(Unit) {
            val config = parseAppearanceConfig()
            bgOpacity = config["BG_OPACITY"]?.toFloatOrNull() ?: 0.3f
            bgBlur = config["BG_BLUR"]?.toFloatOrNull() ?: 10f
            val brightnessRaw = config["SCREEN_BRIGHTNESS"]?.toFloatOrNull() ?: -1f
            val sharedPrefs = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
            val path = sharedPrefs.getString("banner_image_path", "")
            bannerExists = !path.isNullOrEmpty() && File(path).exists()
            val bgPath = sharedPrefs.getString("background_image_path", "")
            bgExists = !bgPath.isNullOrEmpty() && File(bgPath).exists()
            adaptiveColorBg = sharedPrefs.getBoolean("adaptive_color_enabled", false)
            meshHue = sharedPrefs.getFloat("mesh_hue", 260f)
            meshSat = sharedPrefs.getFloat("mesh_sat", 0.6f)
            meshVal = sharedPrefs.getFloat("mesh_val", 0.96f)
            meshEnabled = sharedPrefs.getBoolean("mesh_enabled", true)
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
            containerColor = Color.Transparent
        ) { padding ->
            val alpha by androidx.compose.animation.core.animateFloatAsState(
                targetValue = if (isLoading) 0f else 1f,
                animationSpec = androidx.compose.animation.core.tween(150), label = ""
            )
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 12.dp)
                    .alpha(alpha),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp)
            ) {

            // Banner Image Card
            item {
                AppearanceCard(stringResource(R.string.banner_settings_title)) {
                    Text(stringResource(R.string.set_a_custom_background_banner_image_for_the_app_supported_format_png),
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
                            text = if (bannerExists) stringResource(R.string.banner_installed) else stringResource(R.string.no_banner_set),
                            modifier = Modifier.weight(1f),
                            color = if (bannerExists) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = if (bannerExists) FontWeight.Bold else FontWeight.Normal
                        )
                    }

                    Spacer(Modifier.height(12.dp))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { bannerPickerLauncher.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                            modifier = Modifier.weight(1f),
                            enabled = !isInstallingBanner
                        ) {
                                Icon(Icons.Default.Upload, null)
                        }
                        if (bannerExists) {
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        val path = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE).getString("banner_image_path", "")
                                        if (!path.isNullOrEmpty()) { File(path).delete() }
                                        context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE).edit().remove("banner_image_path").apply()
                                        bannerExists = false; snackbarHostState.showSnackbar(context.getString(R.string.banner_removed))
                                    }
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Icon(Icons.Default.Delete, null)
                            }
                        }
                    }
                    
                    Spacer(Modifier.height(16.dp))

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Adaptive Color Background",
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Switch(
                            checked = adaptiveColorBg,
                            onCheckedChange = {
                                adaptiveColorBg = it
                                context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                    .edit().putBoolean("adaptive_color_enabled", it).apply()
                            }
                        )
                    }
                }
            }

            // Background Opacity Card
            item {
                AppearanceCard(stringResource(R.string.background_settings_title)) {
                    Text(stringResource(R.string.controls_how_the_banner_image_appears_lower_opacity_more_transparent_higher_blur_softer),
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(Modifier.height(12.dp))

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(
                            imageVector = if (bgExists) Icons.Default.CheckCircle else Icons.Default.Image,
                            contentDescription = null,
                            tint = if (bgExists) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = if (bgExists) "Background Set" else "No Background Set",
                            modifier = Modifier.weight(1f),
                            color = if (bgExists) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = if (bgExists) FontWeight.Bold else FontWeight.Normal
                        )
                    }

                    Spacer(Modifier.height(12.dp))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { bgPickerLauncher.launch("image/png") },
                            modifier = Modifier.weight(1f),
                            enabled = !isInstallingBg
                        ) {
                                Icon(Icons.Default.Upload, null)
                        }
                        if (bgExists) {
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        val path = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE).getString("background_image_path", "")
                                        if (!path.isNullOrEmpty()) { File(path).delete() }
                                        context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE).edit().remove("background_image_path").apply()
                                        bgExists = false; snackbarHostState.showSnackbar("Background removed")
                                    }
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Icon(Icons.Default.Delete, null)
                            }
                        }
                    }

                    Spacer(Modifier.height(16.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Opacity, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("${stringResource(R.string.opacity_slider_label)}: ${(bgOpacity * 100).toInt()}%", modifier = Modifier.weight(1f))
                    }
                    Slider(
                        value = bgOpacity,
                        onValueChange = { 
                            bgOpacity = it 
                            context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                .edit().putFloat("bg_opacity", it).apply()
                        },
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
                        Text("${stringResource(R.string.blur_slider_label)}: ${bgBlur.toInt()} px", modifier = Modifier.weight(1f))
                    }
                    Slider(
                        value = bgBlur,
                        onValueChange = { 
                            bgBlur = it 
                            context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                .edit().putFloat("bg_blur", it).apply()
                        },
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

            // Glass Modifier Card
            item {
                AppearanceCard(stringResource(R.string.glass_modifier_title)) {
                    AnimatedVisibility(visible = meshEnabled) {
                        Column {
                            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Column(
                                    modifier = Modifier.weight(1f),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    HueColorWheel(
                                        hue = meshHue,
                                        sat = meshSat,
                                        value = meshVal,
                                        onHueChange = { 
                                            meshHue = it 
                                            meshEnabled = true
                                            context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                                .edit().putFloat("mesh_hue", it).putBoolean("mesh_enabled", true).apply()
                                        }
                                    )
                                }
                                
                                Spacer(Modifier.width(16.dp))
                                
                                Column(
                                    modifier = Modifier.weight(0.6f),
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    val presets = listOf(
                                        Triple(stringResource(R.string.color_purple), 260f, Pair(0.6f, 0.96f)),
                                        Triple(stringResource(R.string.color_red), 0f, Pair(0.6f, 0.96f)),
                                        Triple("White", 0f, Pair(0.0f, 1.0f)),
                                        Triple("Grey", 0f, Pair(0.0f, 0.5f)),
                                        Triple(stringResource(R.string.color_brown), 30f, Pair(0.8f, 0.4f))
                                    )
                                    presets.forEach { (name, hue, satVal) ->
                                        Button(
                                            onClick = { 
                                                meshHue = hue
                                                meshSat = satVal.first
                                                meshVal = satVal.second
                                                meshEnabled = true
                                                context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                                    .edit()
                                                    .putFloat("mesh_hue", hue)
                                                    .putFloat("mesh_sat", meshSat)
                                                    .putFloat("mesh_val", meshVal)
                                                    .putBoolean("mesh_enabled", true)
                                                    .apply()
                                            },
                                            modifier = Modifier.fillMaxWidth().height(36.dp),
                                            shape = RoundedCornerShape(12.dp),
                                            contentPadding = PaddingValues(0.dp)
                                        ) {
                                            Text(name, style = MaterialTheme.typography.labelLarge)
                                        }
                                    }
                                }
                            }

                            Spacer(Modifier.height(16.dp))

                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Saturation: ${(meshSat * 100).toInt()}%", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                            }
                            Slider(
                                value = meshSat,
                                onValueChange = { 
                                    meshSat = it 
                                    context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                        .edit().putFloat("mesh_sat", it).apply()
                                },
                                onValueChangeFinished = {},
                                valueRange = 0f..1f
                            )

                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Brightness: ${(meshVal * 100).toInt()}%", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                            }
                            Slider(
                                value = meshVal,
                                onValueChange = { 
                                    meshVal = it 
                                    context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                        .edit().putFloat("mesh_val", it).apply()
                                },
                                onValueChangeFinished = {},
                                valueRange = 0f..1f
                            )
                            
                            Spacer(Modifier.height(16.dp))

                            Button(
                                onClick = { 
                                    meshHue = 260f
                                    meshSat = 0.6f
                                    meshVal = 0.96f
                                    meshEnabled = true
                                    context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                        .edit()
                                        .putFloat("mesh_hue", 260f)
                                        .putFloat("mesh_sat", 0.6f)
                                        .putFloat("mesh_val", 0.96f)
                                        .putBoolean("mesh_enabled", true)
                                        .apply()
                                },
                                modifier = Modifier.fillMaxWidth().height(48.dp),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text("Reset to Default", style = MaterialTheme.typography.labelLarge)
                            }

                            Spacer(Modifier.height(8.dp))
                        }
                    }

                    Button(
                        onClick = { 
                            meshEnabled = !meshEnabled
                            context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
                                .edit().putBoolean("mesh_enabled", meshEnabled).apply()
                        },
                        modifier = Modifier.fillMaxWidth().height(48.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = if (meshEnabled) {
                            androidx.compose.material3.ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        } else {
                            androidx.compose.material3.ButtonDefaults.buttonColors()
                        },
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text(if (meshEnabled) stringResource(R.string.disable_color_hue) else "Enable Color Hue", style = MaterialTheme.typography.labelLarge)
                    }
                }
            }


        }
    }
}

@Composable
private fun AppearanceCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    GlassCard(
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
