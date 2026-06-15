package com.kanagawa.yamada.project.raco.RacoGameTools

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun CrosshairMenu(themeColor: Color, onClose: () -> Unit) {
    val context = LocalContext.current
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)

    var size by remember { mutableStateOf(prefs.getFloat("crosshair_size", 50f)) }
    var opacity by remember { mutableStateOf(prefs.getFloat("crosshair_opacity", 1f)) }
    var selectedStyle by remember { mutableStateOf(prefs.getInt("crosshair_style", 0)) }
    var selectedColorIndex by remember { mutableStateOf(prefs.getInt("crosshair_color_index", 0)) }

    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val isTablet = configuration.smallestScreenWidthDp >= 600
    val topSpacerHeight = if (isTablet) 48.dp else 0.dp

    Column(modifier = Modifier.fillMaxSize()) {
        Spacer(modifier = Modifier.height(topSpacerHeight))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = Color.White,
                modifier = Modifier.size(24.dp).clickable { onClose() }
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("CROSSHAIR", color = themeColor, fontSize = 18.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        }
        Spacer(modifier = Modifier.height(8.dp))

        Text("SIZE", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
        Slider(
            value = size,
            onValueChange = { 
                size = it
                prefs.edit().putFloat("crosshair_size", it).apply()
            },
            valueRange = 20f..150f,
            colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = themeColor),
            modifier = Modifier.height(32.dp)
        )

        Text("OPACITY", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
        Slider(
            value = opacity,
            onValueChange = { 
                opacity = it
                prefs.edit().putFloat("crosshair_opacity", it).apply()
            },
            valueRange = 0.1f..1f,
            colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = themeColor),
            modifier = Modifier.height(32.dp)
        )
        
        Spacer(modifier = Modifier.height(4.dp))
        Text("STYLE", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
        Spacer(modifier = Modifier.height(4.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (i in 0..3) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (selectedStyle == i) themeColor.copy(alpha=0.3f) else Color.Transparent)
                        .border(1.dp, if (selectedStyle == i) themeColor else Color.White.copy(alpha=0.2f), RoundedCornerShape(8.dp))
                        .clickable {
                            selectedStyle = i
                            prefs.edit().putInt("crosshair_style", i).apply()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = CrosshairData.getCrosshair(i),
                        contentDescription = "Style ${i+1}",
                        tint = if (selectedStyle == i) themeColor else Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        Text("COLOR", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
        Spacer(modifier = Modifier.height(4.dp))
        val colorOptions = listOf(Color.White, Color.Red, Color.Green, Color.Blue, Color.Yellow)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            colorOptions.forEachIndexed { index, color ->
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(color)
                        .border(
                            2.dp, 
                            if (selectedColorIndex == index) themeColor else Color.Transparent, 
                            RoundedCornerShape(13.dp)
                        )
                        .clickable {
                            selectedColorIndex = index
                            prefs.edit().putInt("crosshair_color_index", index).apply()
                        }
                )
            }
        }
    }
}
