package com.kanagawa.yamada.project.raco

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
    
    val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)
    var hasCustomBackground by remember { mutableStateOf(sharedPrefs.getBoolean("HAS_CUSTOM_BACKGROUND", false)) }
    
    var selectedCategory by remember { mutableStateOf("Modules") }
    var pendingCropUri by remember { mutableStateOf<android.net.Uri?>(null) }
    
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
                    android.widget.Toast.makeText(context, "Custom Background Set!", android.widget.Toast.LENGTH_SHORT).show()
                } catch (e: Exception) { 
                    e.printStackTrace()
                    android.widget.Toast.makeText(context, "Failed to save: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
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
            "Modules" to listOf(
                Triple("ANYA", "Anya Thermal", "Enable Anya Thermal Flowstate"),
                Triple("INCLUDE_KOBO", "Kobo Fast Charge", "Fast Charge Module"),
                Triple("INCLUDE_SANDEV", "Sandevistan Boot", "Make init boot faster"),
                Triple("INCLUDE_ZETAMIN", "Zetamin", "All in one Screen Tweaks")
            ),
            "System" to listOf(
                Triple("DEVICE_MITIGATION", "Device Mitigation", "Enable Device Mitigation")
            ),
            "Notifications" to listOf(
                Triple("LEGACY_NOTIF", "Legacy Notifications", "Use Legacy Notifications"),
                Triple("SILENT_NOTIF", "Silent Notifications", "Use Silent Notifications")
            ),
            "Customization" to listOf(
                Triple("CUSTOM_BACKGROUND", "Set Custom Background", ""),
                Triple("ENABLE_BACKGROUND", "Enable Background", ""),
                Triple("BLUR_BACKGROUND", "Blur Background", ""),
                Triple("BLUR_RADIUS", "Blur Radius", ""),
                Triple("DIM_BACKGROUND", "Dim Background", ""),
                Triple("DIM_OPACITY", "Dim Opacity", "")
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
            Text("Loading...", color = Color.White, modifier = Modifier.align(Alignment.Center))
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
                        Text(
                            "SETTINGS",
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
                            Text(
                                cat,
                                color = if (isSelected) accentColor else Color.White,
                                fontFamily = if (isSelected) gilmerBold else gilmerRegular,
                                fontSize = 20.sp,
                                modifier = Modifier
                                    .fillMaxWidth()
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
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                        ) {
                            val items = categories[selectedCategory] ?: emptyList()
                            items.forEach { (key, title, desc) ->
                                if (key == "BLUR_RADIUS" && configState["BLUR_BACKGROUND"] != "1") return@forEach
                                if (key == "DIM_OPACITY" && configState["DIM_BACKGROUND"] != "1") return@forEach
                                val isChecked = configState[key] == "1"
                                val vPadding = if (desc.isEmpty()) 4.dp else 12.dp
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
                                            text = title,
                                            color = Color.White,
                                            fontFamily = gilmerBold,
                                            fontSize = 16.sp
                                        )
                                        if (desc.isNotEmpty()) {
                                            Text(
                                                text = desc,
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
                                                        android.widget.Toast.makeText(context, "Background Reset!", android.widget.Toast.LENGTH_SHORT).show()
                                                    },
                                                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = Color.DarkGray),
                                                    modifier = Modifier.padding(end = 8.dp)
                                                ) {
                                                    Text("Reset", color = Color.White)
                                                }
                                            }
                                            androidx.compose.material3.Button(
                                                onClick = {
                                                    pickMedia.launch(androidx.activity.result.PickVisualMediaRequest(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageOnly))
                                                },
                                                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = accentColor)
                                            ) {
                                                Text("Set", color = Color.White)
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
                                    } else {
                                        Switch(
                                            checked = isChecked,
                                            onCheckedChange = { checked ->
                                                updateConfig(key, if (checked) "1" else "0")
                                            },
                                            colors = SwitchDefaults.colors(
                                                checkedThumbColor = Color.White,
                                                checkedTrackColor = accentColor,
                                                uncheckedThumbColor = Color.Gray,
                                                uncheckedTrackColor = Color.DarkGray
                                            )
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
}
