package com.kanagawa.yamada.project.raco.RacoGameTools

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

enum class AyundaFilter(val title: String) {
    NORMAL("Normal"),
    VIVID("Vivid"),
    VIVID_MAX("Vivid+"),
    GRAYSCALE("B&W"),
    INVERT("Invert"),
    EAGLE_EYE("Eagle Eye"),
    NIGHT_VISION("Night Vis."),
    WARM("Warm"),
    CINEMATIC("Cinematic")
}

@Composable
fun AyundaMenu(themeColor: Color, onClose: () -> Unit) {
    val context = LocalContext.current
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
    var selectedFilter by remember { 
        mutableStateOf(
            try {
                AyundaFilter.valueOf(prefs.getString("ayunda_filter", AyundaFilter.NORMAL.name) ?: AyundaFilter.NORMAL.name)
            } catch (e: Exception) {
                AyundaFilter.NORMAL
            }
        ) 
    }

    val coroutineScope = rememberCoroutineScope()

    val applyFilter = { filter: AyundaFilter ->
        coroutineScope.launch(Dispatchers.IO) {
            try {
                val cmd = java.lang.StringBuilder()
                cmd.append("settings put secure accessibility_display_inversion_enabled ${if (filter == AyundaFilter.INVERT) 1 else 0}; ")
                cmd.append("settings put secure accessibility_display_daltonizer_enabled 0; ")
                
                val saturation = when(filter) {
                    AyundaFilter.VIVID -> 1.5f
                    AyundaFilter.VIVID_MAX -> 2.0f
                    AyundaFilter.GRAYSCALE -> 0.0f
                    else -> 1.0f
                }
                cmd.append("service call SurfaceFlinger 1022 f $saturation; ")
                
                val matrix = when(filter) {
                    AyundaFilter.EAGLE_EYE -> "f 1.2 f 0.0 f 0.0 f 0.0 f 0.0 f 1.2 f 0.0 f 0.0 f 0.0 f 0.0 f 0.8 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                    AyundaFilter.NIGHT_VISION -> "f 0.3 f 0.0 f 0.0 f 0.0 f 0.0 f 1.5 f 0.0 f 0.0 f 0.0 f 0.0 f 0.3 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                    AyundaFilter.WARM -> "f 1.0 f 0.0 f 0.0 f 0.0 f 0.0 f 0.9 f 0.0 f 0.0 f 0.0 f 0.0 f 0.6 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                    AyundaFilter.CINEMATIC -> "f 0.9 f 0.0 f 0.0 f 0.0 f 0.0 f 0.9 f 0.0 f 0.0 f 0.0 f 0.0 f 1.2 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                    else -> null
                }
                
                if (matrix != null) {
                    cmd.append("service call SurfaceFlinger 1015 i32 1 $matrix")
                } else if (filter != AyundaFilter.INVERT) {
                    cmd.append("service call SurfaceFlinger 1015 i32 0")
                }
                
                Runtime.getRuntime().exec(arrayOf("su", "-c", cmd.toString())).waitFor()
            } catch (e: Exception) {}
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = Color.White,
                modifier = Modifier.size(24.dp).clickable { onClose() }
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("AYUNDA", color = themeColor, fontSize = 16.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        }
        Spacer(modifier = Modifier.height(16.dp))
        
        val filters = AyundaFilter.values()
        Column(
            modifier = Modifier
                .padding(end = 24.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            for (filter in filters) {
                val isSelected = selectedFilter == filter
                Box(
                    modifier = Modifier
                        .widthIn(max = 280.dp)
                        .fillMaxWidth(0.75f)
                        .height(36.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (isSelected) themeColor.copy(alpha=0.3f) else Color.Transparent)
                        .border(1.dp, if (isSelected) themeColor else Color.White.copy(alpha=0.2f), RoundedCornerShape(8.dp))
                        .clickable {
                            selectedFilter = filter
                            prefs.edit().putString("ayunda_filter", filter.name).apply()
                            prefs.edit().putBoolean("is_ayunda_enabled", filter != AyundaFilter.NORMAL).apply()
                            applyFilter(filter)
                        },
                    contentAlignment = Alignment.CenterStart
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 16.dp)) {
                        Text(
                            text = filter.title,
                            color = if (isSelected) themeColor else Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}
