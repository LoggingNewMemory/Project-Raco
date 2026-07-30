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

    data class PresetData(val title: String, val desc: String, val vals: List<Float>)
    
    val presets = listOf(
        PresetData("Hunter", "Help observe grass fields.", listOf(0.9f, 1.2f, 0.9f, 1.3f)),
        PresetData("Night Vision", "Better environment for scene exploration.", listOf(0.7f, 1.2f, 1.0f, 0.8f)),
        PresetData("Eagle Eye", "Aid in enemy recognition.", listOf(1.1f, 1.0f, 0.9f, 1.4f)),
        PresetData("Ultra-Clear", "Provide an improved visual experience.", listOf(1.05f, 1.05f, 1.05f, 1.2f)),
        PresetData("Pure", "Reduces stray colors for clarity.", listOf(1.0f, 1.0f, 1.0f, 0.9f)),
        PresetData("Cyberpunk", "Enhances colors to improve picture impact.", listOf(1.2f, 0.9f, 1.3f, 1.5f)),
        PresetData("Instrument", "Simulates night vision device effects.", listOf(0.3f, 1.5f, 0.3f, 1.0f)),
        PresetData("Movie", "Transforms the game style into a movie-like experience.", listOf(1.1f, 1.0f, 0.9f, 0.95f)),
        PresetData("Sketch", "Transforms the game style into a sketch drawing.", listOf(1.5f, 1.5f, 1.5f, 0.1f)),
        PresetData("Film", "Transforms the game style into a Lomo film.", listOf(1.2f, 1.1f, 0.8f, 1.1f)),
        PresetData("Crayon", "Transforms the game style into a crayon drawing.", listOf(1.3f, 1.3f, 1.3f, 1.2f)),
        PresetData("Oil Painting", "Transforms the game style into an oil painting.", listOf(1.2f, 1.1f, 0.9f, 1.4f))
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
        
        presets.forEach { preset ->
            val name = preset.title
            val desc = preset.desc
            val vals = preset.vals
            
            val isCurrent = activeAyundaPresetState.value == name
            val bgColor = if (isCurrent) themeColor else Color(0xFF2A2A2A)
            val textColor = if (isCurrent) Color.White else Color.LightGray
            val descColor = if (isCurrent) Color.White.copy(alpha = 0.7f) else Color.Gray
            
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(bgColor)
                    .clickable {
                        activeAyundaPresetState.value = name
                        coroutineScope.launch(Dispatchers.IO) {
                            sharedPrefs.edit().apply {
                                putFloat("RGB_R_$currentPackage", vals[0])
                                putFloat("RGB_G_$currentPackage", vals[1])
                                putFloat("RGB_B_$currentPackage", vals[2])
                                putFloat("RGB_S_$currentPackage", vals[3])
                                putString("active_ayunda_preset_$currentPackage", name)
                                apply()
                            }
                            Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1015 i32 1 f ${vals[0]} f 0 f 0 f 0 f 0 f ${vals[1]} f 0 f 0 f 0 f 0 f ${vals[2]} f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f ${vals[3]}")).waitFor()
                        }
                    }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(name, fontWeight = FontWeight.SemiBold, color = textColor, fontSize = 14.sp)
                    Spacer(Modifier.height(4.dp))
                    Text(desc, color = descColor, fontSize = 10.sp, maxLines = 2)
                }
                if (isCurrent) {
                    Spacer(Modifier.width(12.dp))
                    Icon(Icons.Default.Check, "Active", tint = Color.White)
                }
            }
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
        if (isCurrentlyActive) {
            activeAyundaPresetState.value = ""
            sharedPrefs.edit().putString("active_ayunda_preset_$currentPackage", "").apply()
            val globalPreset = sharedPrefs.getString("active_ayunda_preset", "") ?: ""
            if (globalPreset.isNotEmpty()) {
                val r = sharedPrefs.getFloat("RGB_R", 1f)
                val g = sharedPrefs.getFloat("RGB_G", 1f)
                val b = sharedPrefs.getFloat("RGB_B", 1f)
                val s = sharedPrefs.getFloat("RGB_S", 1f)
                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f $s")).waitFor()
                val cmd = "service call SurfaceFlinger 1015 i32 1 f 1.0 f 0 f 0 f 0 f 0 f 1.0 f 0 f 0 f 0 f 0 f 1.0 f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f 1.0"
                Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
            }
        } else {
            var lastPreset = sharedPrefs.getString("active_ayunda_preset_$currentPackage", "") ?: ""
            if (lastPreset.isEmpty()) {
                lastPreset = "Hunter" // Default for new games
                sharedPrefs.edit().putString("active_ayunda_preset_$currentPackage", lastPreset).apply()
                sharedPrefs.edit().apply {
                    putFloat("RGB_R_$currentPackage", 0.9f)
                    putFloat("RGB_G_$currentPackage", 1.2f)
                    putFloat("RGB_B_$currentPackage", 0.9f)
                    putFloat("RGB_S_$currentPackage", 1.3f)
                    apply()
                }
            }
            activeAyundaPresetState.value = lastPreset
            val r = sharedPrefs.getFloat("RGB_R_$currentPackage", 1f)
            val g = sharedPrefs.getFloat("RGB_G_$currentPackage", 1f)
            val b = sharedPrefs.getFloat("RGB_B_$currentPackage", 1f)
            val s = sharedPrefs.getFloat("RGB_S_$currentPackage", 1f)
            val cmd = "service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f $s"
            Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
        }
    }
}
