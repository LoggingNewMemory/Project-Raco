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
    
    var selectedCategory by remember { mutableStateOf("Modules Configuration") }

    val categories = remember {
        mapOf(
            "Modules Configuration" to listOf(
                "INCLUDE_KOBO" to "Include Kobo Kanaeru module",
                "INCLUDE_SANDEV" to "Include Sandevistan module",
                "INCLUDE_ZETAMIN" to "Include Zetamin module"
            ),
            "Assistant & System" to listOf(
                "ANYA" to "Enable ANYA assistant",
                "DND" to "Enable Do Not Disturb",
                "DEVICE_MITIGATION" to "Enable Device Mitigation"
            ),
            "Notifications" to listOf(
                "LEGACY_NOTIF" to "Use Legacy Notifications",
                "SILENT_NOTIF" to "Use Silent Notifications"
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
                process.waitFor()
            } catch (e: Exception) {
                e.printStackTrace()
            }
            isLoading = false
        }
    }

    fun updateConfig(key: String, value: String) {
        configState[key] = value
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
                        Text(
                            "Configure /data/ProjectRaco/raco.txt",
                            color = Color.LightGray,
                            fontFamily = gilmerRegular,
                            fontSize = 14.sp
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
                            .weight(0.4f)
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
                            .weight(0.6f)
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
                            items.forEach { (key, desc) ->
                                val isChecked = configState[key] == "1"
                                OptionToggle(
                                    title = key,
                                    enabled = true,
                                    checked = isChecked,
                                    onCheckedChange = { checked ->
                                        updateConfig(key, if (checked) "1" else "0")
                                    },
                                    accentColor = accentColor,
                                    fontFamilyBold = gilmerBold
                                )
                                Text(
                                    desc,
                                    color = Color.Gray,
                                    fontFamily = gilmerRegular,
                                    fontSize = 12.sp,
                                    modifier = Modifier.padding(bottom = 12.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
