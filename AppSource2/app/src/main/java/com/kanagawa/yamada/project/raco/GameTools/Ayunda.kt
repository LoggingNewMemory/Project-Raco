package com.kanagawa.yamada.project.raco.GameTools

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Composable
fun AyundaConfigView(
    currentPackage: String,
    onDismissRequest: () -> Unit,
    themeColor: Color,
    sharedPrefs: android.content.SharedPreferences,
    activeAyundaPresetState: MutableState<String>
) {
    val coroutineScope = rememberCoroutineScope()

    data class PresetData(val title: String, val vals: List<Float>)
    
    val presets = listOf(
        PresetData("Vivid", listOf(1.2f, 1.1f, 1.1f, 1.3f)),
        PresetData("Vivid+", listOf(1.3f, 1.2f, 1.2f, 2.0f)),
        PresetData("B&W", listOf(1.0f, 1.0f, 1.0f, 0.0f)),
        PresetData("Eagle Eye", listOf(1.1f, 1.0f, 0.9f, 1.4f)),
        PresetData("Night Vision", listOf(0.7f, 1.2f, 1.0f, 0.8f)),
        PresetData("Warm", listOf(1.1f, 1.0f, 0.9f, 1.0f)),
        PresetData("Hunter", listOf(0.9f, 1.2f, 0.9f, 1.3f)),
        PresetData("Sniper", listOf(1.1f, 1.1f, 0.9f, 1.2f)),
        PresetData("Ultra-Clear", listOf(1.05f, 1.05f, 1.05f, 1.2f)),
        PresetData("Pure", listOf(1.0f, 1.0f, 1.0f, 0.9f)),
        PresetData("Cyberpunk", listOf(1.2f, 0.9f, 1.3f, 1.5f)),
        PresetData("Instrument", listOf(0.3f, 1.5f, 0.3f, 1.0f)),
        PresetData("Movie", listOf(1.1f, 1.0f, 0.9f, 0.95f)),
        PresetData("Sketch", listOf(1.5f, 1.5f, 1.5f, 0.1f)),
        PresetData("Film", listOf(1.2f, 1.1f, 0.8f, 1.1f)),
        PresetData("Crayon", listOf(1.3f, 1.3f, 1.3f, 1.2f)),
        PresetData("Oil Painting", listOf(1.2f, 1.1f, 0.9f, 1.4f))
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Ayunda Presets", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            IconButton(onClick = onDismissRequest, modifier = Modifier.size(24.dp)) {
                Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = Color.Gray)
            }
        }
        
        Text("Screen Color Modifiers", color = Color.Gray, fontSize = 12.sp, modifier = Modifier.padding(bottom = 12.dp))
        
        val context = androidx.compose.ui.platform.LocalContext.current
        val customPresets = remember {
            val uiPrefs = context.getSharedPreferences("raco_ui_prefs", android.content.Context.MODE_PRIVATE)
            uiPrefs.getStringSet("ayunda_presets", emptySet<String>())?.associate {
                val parts = it.split("::")
                val vals = parts[1].split(",").map { v -> v.toFloat() }
                parts[0] to vals
            } ?: emptyMap()
        }

        @Composable
        fun PresetItem(name: String, vals: List<Float>) {
            val isCurrent = activeAyundaPresetState.value == name
            val bgColor = if (isCurrent) themeColor else Color(0xFF2A2A2A)
            val textColor = if (isCurrent) Color.White else Color.LightGray
            
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(bgColor)
                    .clickable {
                        activeAyundaPresetState.value = name
                        coroutineScope.launch(Dispatchers.IO) {
                            var currentMode = 4
                            try {
                                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /data/ProjectRaco/modes/$currentPackage 2>/dev/null"))
                                val lines = process.inputStream.bufferedReader().readLines()
                                if (lines.isNotEmpty()) currentMode = lines[0].toIntOrNull() ?: 4
                            } catch (e: Exception) {}
                            
                            val newContent = "$currentMode\\n${vals[0]} ${vals[1]} ${vals[2]} ${vals[3]}\\n$name\\n"
                            val cmdStr = """
                                echo -e '$newContent' > /data/ProjectRaco/modes/$currentPackage
                                chmod 666 /data/ProjectRaco/modes/$currentPackage
                                touch /data/ProjectRaco/ayunda_active
                                service call SurfaceFlinger 1015 i32 1 f ${vals[0]} f 0 f 0 f 0 f 0 f ${vals[1]} f 0 f 0 f 0 f 0 f ${vals[2]} f 0 f 0 f 0 f 0 f 1
                                service call SurfaceFlinger 1022 f ${vals[3]}
                            """.trimIndent()
                            Runtime.getRuntime().exec(arrayOf("su", "-c", cmdStr)).waitFor()
                        }
                    }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(name, fontWeight = FontWeight.SemiBold, color = textColor, fontSize = 14.sp)
                }
                if (isCurrent) {
                    Spacer(Modifier.width(12.dp))
                    Icon(Icons.Default.Check, "Active", tint = Color.White)
                }
            }
        }

        @Composable
        fun SectionHeader(title: String) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(modifier = Modifier.weight(1f).height(1.dp).background(Color.Gray.copy(alpha = 0.5f)))
                Text(" $title ", color = Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Box(modifier = Modifier.weight(1f).height(1.dp).background(Color.Gray.copy(alpha = 0.5f)))
            }
        }

        if (customPresets.isNotEmpty()) {
            SectionHeader("Custom Preset")
            customPresets.forEach { (name, vals) ->
                PresetItem(name, vals)
            }
        }

        if (customPresets.isNotEmpty()) {
            SectionHeader("Built-in Preset")
        }

        presets.forEach { preset ->
            PresetItem(preset.title, preset.vals)
        }
    }
}

object AyundaTool {
    fun toggle(
        currentPackage: String,
        activeAyundaPresetState: MutableState<String>,
        sharedPrefs: android.content.SharedPreferences
    ) {
        val isCurrentlyActive = activeAyundaPresetState.value.isNotEmpty()
        var currentMode = 4
        var lastPreset = "Vivid"
        var r = 1.2f; var g = 1.1f; var b = 1.1f; var s = 1.3f
        
        try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /data/ProjectRaco/modes/$currentPackage 2>/dev/null"))
            val lines = process.inputStream.bufferedReader().readLines()
            if (lines.isNotEmpty()) {
                currentMode = lines[0].toIntOrNull() ?: 4
                if (lines.size >= 3) {
                    val rgb = lines[1].split(" ")
                    if (rgb.size >= 4) {
                        r = rgb[0].toFloatOrNull() ?: r
                        g = rgb[1].toFloatOrNull() ?: g
                        b = rgb[2].toFloatOrNull() ?: b
                        s = rgb[3].toFloatOrNull() ?: s
                    }
                    lastPreset = lines[2]
                }
            }
        } catch (e: Exception) {}

        if (isCurrentlyActive) {
            activeAyundaPresetState.value = ""
            val cmdStr = """
                echo -e '$currentMode\\n$r $g $b $s\\n$lastPreset' > /data/ProjectRaco/modes/${currentPackage}.bak
                echo '$currentMode' > /data/ProjectRaco/modes/$currentPackage
                chmod 666 /data/ProjectRaco/modes/${currentPackage}.bak /data/ProjectRaco/modes/$currentPackage
            """.trimIndent()
            Runtime.getRuntime().exec(arrayOf("su", "-c", cmdStr)).waitFor()
            
            // Restore System Ayunda
            Runtime.getRuntime().exec(arrayOf("su", "-c", "rm -f /data/ProjectRaco/ayunda_active ; sh /data/ProjectRaco/AyundaRusdi.sh >/dev/null 2>&1")).waitFor()
        } else {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "cat /data/ProjectRaco/modes/${currentPackage}.bak 2>/dev/null"))
                val lines = process.inputStream.bufferedReader().readLines()
                if (lines.size >= 3) {
                    val rgb = lines[1].split(" ")
                    if (rgb.size >= 4) {
                        r = rgb[0].toFloatOrNull() ?: r
                        g = rgb[1].toFloatOrNull() ?: g
                        b = rgb[2].toFloatOrNull() ?: b
                        s = rgb[3].toFloatOrNull() ?: s
                    }
                    lastPreset = lines[2]
                }
            } catch (e: Exception) {}
            
            activeAyundaPresetState.value = lastPreset
            val newContent = "$currentMode\\n$r $g $b $s\\n$lastPreset\\n"
            val cmd = """
                echo -e '$newContent' > /data/ProjectRaco/modes/$currentPackage
                chmod 666 /data/ProjectRaco/modes/$currentPackage
                touch /data/ProjectRaco/ayunda_active
                service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1
                service call SurfaceFlinger 1022 f $s
            """.trimIndent()
            Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
        }
    }
}
