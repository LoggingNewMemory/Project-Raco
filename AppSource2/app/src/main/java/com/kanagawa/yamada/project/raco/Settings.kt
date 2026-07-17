package com.kanagawa.yamada.project.raco
import androidx.compose.ui.res.stringResource
import com.kanagawa.yamada.project.raco.R

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.zIndex
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.FastOutSlowInEasing
import kotlinx.coroutines.delay
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.getValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

@Composable
fun SettingsScreen(
    accentColor: Color,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    val gilmerBold = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerBold.otf")))
    }
    val gilmerRegular = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerRegular.otf")))
    }

    val configState = remember { mutableStateMapOf<String, String>() }
    var isLoading by remember { mutableStateOf(true) }
    var availableGovernors by remember { mutableStateOf(listOf("schedutil", "performance", "powersave")) }
    
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    var hasCustomBackground by remember { mutableStateOf(sharedPrefs.getBoolean("HAS_CUSTOM_BACKGROUND", false)) }
    
    var selectedCategory by remember { mutableStateOf(R.string.modules) }
    var pendingCropUri by remember { mutableStateOf<android.net.Uri?>(null) }
    
    // Fake Toast State
    var toastMessage by remember { mutableStateOf<String?>(null) }
    var lastToastMessage by remember { mutableStateOf("") }
    var toastTrigger by remember { mutableStateOf(0) }

    LaunchedEffect(toastMessage) {
        if (toastMessage != null) lastToastMessage = toastMessage!!
    }

    LaunchedEffect(toastTrigger) {
        if (toastTrigger > 0) {
            delay(2500)
            toastMessage = null
        }
    }
    
    val cropImage = androidx.activity.compose.rememberLauncherForActivityResult(com.canhub.cropper.CropImageContract()) { result ->
        if (result.isSuccessful) {
            val uriContent = result.uriContent
            if (uriContent != null) {
                try {
                    val inputStream = context.contentResolver.openInputStream(uriContent)
                    val outFile = java.io.File(context.filesDir, "custom_background.png")
                    val outputStream = java.io.FileOutputStream(outFile)
                    inputStream?.copyTo(outputStream)
                    inputStream?.close()
                    outputStream.close()
                    sharedPrefs.edit()
                        .putBoolean("HAS_CUSTOM_BACKGROUND", true)
                        .putLong("CUSTOM_BG_TS", System.currentTimeMillis())
                        .apply()
                    hasCustomBackground = true
                    android.widget.Toast.makeText(context, context.getString(R.string.custom_background_set), android.widget.Toast.LENGTH_SHORT).show()
                } catch (e: Exception) { 
                    e.printStackTrace()
                    android.widget.Toast.makeText(context, context.getString(R.string.file_save_failed) + ": ${e.message}", android.widget.Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    val pickMedia = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            cropImage.launch(
                com.canhub.cropper.CropImageContractOptions(
                    uri = uri,
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

    val categories = remember {
        mapOf(
            R.string.modules to listOf(
                Triple("ANYA", R.string.anya_thermal, R.string.enable_anya_thermal_flowstate),
                Triple("INCLUDE_KOBO", R.string.kobo_fast_charge, R.string.fast_charge_module),
                Triple("INCLUDE_SANDEV", R.string.sandevistan_boot, R.string.make_init_boot_faster),
                Triple("INCLUDE_ZETAMIN", R.string.zetamin, R.string.all_in_one_screen_tweaks)
            ),
            R.string.system to listOf(
                Triple("DEVICE_MITIGATION", R.string.device_mitigation, R.string.enable_device_mitigation),
                Triple("GOV", R.string.custom_gov, R.string.your_default_gov_will_applied_after_you_close_the_game),
                Triple("ALTER_CPU_METHOD", R.string.alternative_cpu_method, R.string.set_governor_only_leave_cpufreq_untoched_enable_this_if_your_cpu_can_t_set_frequecny_correctly)
            ),
            R.string.notifications to listOf(
                Triple("LEGACY_NOTIF", R.string.legacy_notifications, R.string.use_legacy_notifications),
                Triple("SILENT_NOTIF", R.string.silent_notifications, R.string.use_silent_notifications)
            ),
            R.string.customization to listOf(
                Triple("CUSTOM_BACKGROUND", R.string.set_custom_background, R.string.empty_string),
                Triple("ENABLE_BACKGROUND", R.string.enable_background, R.string.empty_string),
                Triple("BLUR_BACKGROUND", R.string.blur_background, R.string.empty_string),
                Triple("BLUR_RADIUS", R.string.blur_radius, R.string.empty_string),
                Triple("DIM_BACKGROUND", R.string.dim_background, R.string.empty_string),
                Triple("DIM_OPACITY", R.string.dim_opacity, R.string.empty_string)
            )
        )
    }

    // Read config
    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /data/ProjectRaco/raco.txt"))
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    val parts = line!!.trim().split(Regex("\\s+"))
                    if (parts.size >= 2) {
                        configState[parts[0]] = parts[1]
                    }
                }
                configState["ENABLE_BACKGROUND"] = if (sharedPrefs.getBoolean("ENABLE_BACKGROUND", true)) "1" else "0"
                configState["BLUR_BACKGROUND"] = if (sharedPrefs.getBoolean("BLUR_BACKGROUND", false)) "1" else "0"
                configState["BLUR_RADIUS"] = sharedPrefs.getFloat("BLUR_RADIUS", 24f).toString()
                configState["DIM_BACKGROUND"] = if (sharedPrefs.getBoolean("DIM_BACKGROUND", false)) "1" else "0"
                configState["DIM_OPACITY"] = sharedPrefs.getFloat("DIM_OPACITY", 0.5f).toString()
                process.waitFor()
                
                try {
                    val govProcess = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"))
                    val govReader = BufferedReader(InputStreamReader(govProcess.inputStream))
                    val govs = govReader.readLine()?.split(Regex("\\s+"))?.filter { it.isNotBlank() }
                    if (!govs.isNullOrEmpty()) {
                        availableGovernors = govs
                    }
                    govProcess.waitFor()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                
            } catch (e: Exception) {
                e.printStackTrace()
            }
            isLoading = false
        }
    }

    fun updateConfig(key: String, value: String) {
        configState[key] = value
        if (key in listOf("ENABLE_BACKGROUND", "BLUR_BACKGROUND", "DIM_BACKGROUND")) {
            sharedPrefs.edit().putBoolean(key, value == "1").apply()
            return
        }
        if (key in listOf("BLUR_RADIUS", "DIM_OPACITY")) {
            sharedPrefs.edit().putFloat(key, value.toFloatOrNull() ?: 0f).apply()
            return
        }
        
        if (key in listOf("INCLUDE_KOBO", "INCLUDE_SANDEV", "INCLUDE_ZETAMIN")) {
            toastMessage = "Please reboot the device"
            toastTrigger++
        }
        
        coroutineScope.launch(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /data/ProjectRaco/raco.txt"))
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val lines = mutableListOf<String>()
                var line: String?
                var found = false
                while (reader.readLine().also { line = it } != null) {
                    val l = line!!
                    val parts = l.trim().split(Regex("\\s+"))
                    if (parts.isNotEmpty() && parts[0] == key) {
                        lines.add("$key $value")
                        found = true
                    } else {
                        lines.add(l)
                    }
                }
                if (!found) {
                    lines.add("$key $value")
                }
                process.waitFor()

                val tempDir = context.cacheDir
                val tempFile = File(tempDir, "raco_temp.txt")
                tempFile.writeText(lines.joinToString("\n") + "\n")
                Runtime.getRuntime().exec(arrayOf("su", "-c", "cp ${tempFile.absolutePath} /data/ProjectRaco/raco.txt")).waitFor()
                tempFile.delete()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A))
            .padding(24.dp)
            .displayCutoutPadding()
    ) {
        if (isLoading) {
            Text(stringResource(R.string.loading), color = Color.White, modifier = Modifier.align(Alignment.Center))
        } else {
            Column(modifier = Modifier.fillMaxSize()) {
                // Header
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White.copy(alpha = 0.1f))
                            .clickable { onBack() },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                    Spacer(modifier = Modifier.width(16.dp))
                    Column {
                        Text(stringResource(R.string.settings),
                            color = accentColor,
                            fontFamily = gilmerBold,
                            fontSize = 24.sp,
                            letterSpacing = 2.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                Row(
                    modifier = Modifier.fillMaxWidth().weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    // LEFT COLUMN: Categories
                    Column(
                        modifier = Modifier
                            .weight(0.25f)
                            .fillMaxHeight()
                    ) {
                        categories.keys.forEach { cat ->
                            val isSelected = selectedCategory == cat
                            val animatedColor by androidx.compose.animation.animateColorAsState(
                                targetValue = if (isSelected) accentColor else Color.White,
                                animationSpec = androidx.compose.animation.core.tween(150),
                                label = "CatColor"
                            )
                            val animatedOffsetX by androidx.compose.animation.core.animateDpAsState(
                                targetValue = if (isSelected) 12.dp else 0.dp,
                                animationSpec = androidx.compose.animation.core.tween(150),
                                label = "CatOffset"
                            )
                            Text(
                                stringResource(cat),
                                color = animatedColor,
                                fontFamily = if (isSelected) gilmerBold else gilmerRegular,
                                fontSize = 20.sp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .offset(x = animatedOffsetX)
                                    .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) {
                                        selectedCategory = cat
                                    }
                                    .padding(vertical = 12.dp)
                            )
                        }
                    }

                    // RIGHT COLUMN: Content
                    Box(
                        modifier = Modifier
                            .weight(0.75f)
                            .fillMaxHeight()
                            .border(1.dp, Color.DarkGray, RoundedCornerShape(16.dp))
                            .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                            .padding(16.dp)
                    ) {
                        androidx.compose.animation.AnimatedContent(
                            targetState = selectedCategory,
                            transitionSpec = {
                                (androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(150)) + androidx.compose.animation.slideInVertically(androidx.compose.animation.core.tween(150)) { 40 }).togetherWith(
                                    androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(150)) + androidx.compose.animation.slideOutVertically(androidx.compose.animation.core.tween(150)) { -40 }
                                ).using(androidx.compose.animation.SizeTransform(clip = false))
                            },
                            label = "CategoryTransition"
                        ) { cat ->
                            Column(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .verticalScroll(rememberScrollState())
                            ) {
                                val items = categories[cat] ?: emptyList()
                                items.forEach { (key, title, desc) ->
                                    if (key == "BLUR_RADIUS" && configState["BLUR_BACKGROUND"] != "1") return@forEach
                                    if (key == "DIM_OPACITY" && configState["DIM_BACKGROUND"] != "1") return@forEach
                                    val isChecked = configState[key] == "1"
                                    val vPadding = if (cat == R.string.customization) 8.dp else if (desc == R.string.empty_string) 4.dp else 12.dp
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = vPadding),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Text(
                                            text = stringResource(title),
                                            color = Color.White,
                                            fontFamily = gilmerBold,
                                            fontSize = 16.sp
                                        )
                                        if (desc != R.string.empty_string) {
                                            Text(
                                                text = stringResource(desc),
                                                color = Color.Gray,
                                                fontFamily = gilmerRegular,
                                                fontSize = 9.sp,
                                                modifier = Modifier.padding(top = 4.dp)
                                            )
                                        }
                                    }
                                    Spacer(modifier = Modifier.width(16.dp))
                                    if (key == "CUSTOM_BACKGROUND") {
                                        Row {
                                            if (hasCustomBackground) {
                                                androidx.compose.material3.Button(
                                                    onClick = {
                                                        sharedPrefs.edit()
                                                            .putBoolean("HAS_CUSTOM_BACKGROUND", false)
                                                            .putLong("CUSTOM_BG_TS", System.currentTimeMillis())
                                                            .apply()
                                                        hasCustomBackground = false
                                                        val outFile = java.io.File(context.filesDir, "custom_background.png")
                                                        if (outFile.exists()) outFile.delete()
                                                        android.widget.Toast.makeText(context, context.getString(R.string.background_reset), android.widget.Toast.LENGTH_SHORT).show()
                                                    },
                                                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = Color.DarkGray),
                                                    modifier = Modifier.padding(end = 8.dp)
                                                ) {
                                                    Text(stringResource(R.string.reset), color = Color.White)
                                                }
                                            }
                                            androidx.compose.material3.Button(
                                                onClick = {
                                                    pickMedia.launch(androidx.activity.result.PickVisualMediaRequest(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageOnly))
                                                },
                                                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = accentColor)
                                            ) {
                                                Text(stringResource(R.string.set), color = Color.White)
                                            }
                                        }
                                    } else if (key == "BLUR_RADIUS") {
                                        androidx.compose.material3.Slider(
                                            value = configState[key]?.toFloatOrNull() ?: 24f,
                                            onValueChange = { updateConfig(key, it.toString()) },
                                            valueRange = 0f..100f,
                                            colors = androidx.compose.material3.SliderDefaults.colors(
                                                thumbColor = Color.White,
                                                activeTrackColor = accentColor,
                                                inactiveTrackColor = Color.DarkGray
                                            ),
                                            modifier = Modifier.width(300.dp)
                                        )
                                    } else if (key == "DIM_OPACITY") {
                                        androidx.compose.material3.Slider(
                                            value = configState[key]?.toFloatOrNull() ?: 0.5f,
                                            onValueChange = { updateConfig(key, it.toString()) },
                                            valueRange = 0f..1f,
                                            colors = androidx.compose.material3.SliderDefaults.colors(
                                                thumbColor = Color.White,
                                                activeTrackColor = accentColor,
                                                inactiveTrackColor = Color.DarkGray
                                            ),
                                            modifier = Modifier.width(300.dp)
                                        )
                                    } else if (key == "GOV") {
                                        var expanded by remember { mutableStateOf(false) }
                                        Box {
                                            Row(
                                                modifier = Modifier
                                                    .background(Color.DarkGray, RoundedCornerShape(8.dp))
                                                    .clickable { expanded = true }
                                                    .padding(horizontal = 12.dp, vertical = 8.dp),
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Text(
                                                    text = configState[key]?.takeIf { it.isNotBlank() } ?: "Select",
                                                    color = Color.White,
                                                    fontFamily = gilmerRegular,
                                                    fontSize = 14.sp
                                                )
                                            }
                                            androidx.compose.material3.DropdownMenu(
                                                expanded = expanded,
                                                onDismissRequest = { expanded = false },
                                                modifier = Modifier.background(Color.DarkGray)
                                            ) {
                                                availableGovernors.forEach { gov ->
                                                    androidx.compose.material3.DropdownMenuItem(
                                                        text = { Text(gov, color = Color.White, fontFamily = gilmerRegular) },
                                                        onClick = {
                                                            updateConfig(key, gov)
                                                            expanded = false
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    } else {
                                        Box(
                                            modifier = Modifier
                                                .width(52.dp)
                                                .height(28.dp)
                                                .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) {
                                                    updateConfig(key, if (isChecked) "0" else "1")
                                                }
                                                .background(if (isChecked) accentColor else Color.DarkGray, androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                                                .padding(4.dp),
                                            contentAlignment = if (isChecked) Alignment.CenterEnd else Alignment.CenterStart
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .size(20.dp)
                                                    .background(if (isChecked) Color.White else Color.Gray, androidx.compose.foundation.shape.CircleShape)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // FAKE TOAST
        AnimatedVisibility(
            visible = toastMessage != null,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 64.dp).zIndex(50f)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color(0xCC000000))
                    .border(1.dp, accentColor.copy(alpha=0.5f), RoundedCornerShape(24.dp))
                    .padding(horizontal = 24.dp, vertical = 12.dp)
            ) {
                Box {
                    Text(
                        text = lastToastMessage,
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Medium
                    )
                }
            }
        }
    }
}
}
