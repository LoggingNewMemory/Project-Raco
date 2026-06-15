package com.kanagawa.yamada.project.raco.RacoGameTools

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
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
    GRAYSCALE("B&W"),
    INVERT("Invert")
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
                when (filter) {
                    AyundaFilter.NORMAL -> {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.0")).waitFor()
                    }
                    AyundaFilter.VIVID -> {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.5")).waitFor()
                    }
                    AyundaFilter.GRAYSCALE -> {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 0")).waitFor()
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 0.0")).waitFor()
                    }
                    AyundaFilter.INVERT -> {
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1022 f 1.0")).waitFor()
                        Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put secure accessibility_display_inversion_enabled 1")).waitFor()
                    }
                }
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
            modifier = Modifier.padding(end = 24.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            for (filter in filters) {
                val isSelected = selectedFilter == filter
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.75f)
                        .height(36.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (isSelected) themeColor.copy(alpha=0.3f) else Color.Transparent)
                        .border(1.dp, if (isSelected) themeColor else Color.White.copy(alpha=0.2f), RoundedCornerShape(8.dp))
                        .clickable {
                            selectedFilter = filter
                            prefs.edit().putString("ayunda_filter", filter.name).apply()
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
