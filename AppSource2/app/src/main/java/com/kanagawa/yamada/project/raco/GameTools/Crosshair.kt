package com.kanagawa.yamada.project.raco.GameTools

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kanagawa.yamada.project.raco.R

@Composable
fun CrosshairConfigView(
    currentPackage: String,
    onDismissRequest: () -> Unit,
    crosshairTypeState: MutableState<Int>,
    crosshairSizeState: MutableState<Float>,
    crosshairOpacityState: MutableState<Float>,
    crosshairColorState: MutableState<String>,
    themeColor: Color,
    sharedPrefs: android.content.SharedPreferences
) {
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
            Text("Crosshair Settings", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            IconButton(onClick = onDismissRequest, modifier = Modifier.size(24.dp)) {
                Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = Color.Gray)
            }
        }
        
        Text("Style", color = Color.Gray, fontSize = 12.sp)
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            for (i in 1..4) {
                val drawableRes = when(i) {
                    2 -> R.drawable.ic_crosshair_2
                    3 -> R.drawable.ic_crosshair_3
                    4 -> R.drawable.ic_crosshair_4
                    else -> R.drawable.ic_crosshair_1
                }
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (crosshairTypeState.value == i) themeColor else Color(0xFF2A2A2A))
                        .clickable { 
                            crosshairTypeState.value = i 
                            sharedPrefs.edit().putInt("crosshair_type", i).apply()
                            if (currentPackage.isNotEmpty()) sharedPrefs.edit().putInt("crosshair_type_$currentPackage", i).apply()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        painter = androidx.compose.ui.res.painterResource(id = drawableRes),
                        contentDescription = "Crosshair $i",
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text("Color", color = Color.Gray, fontSize = 12.sp)
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            val colors = listOf("White" to Color.White, "Red" to Color.Red, "Blue" to Color.Blue, "Green" to Color.Green)
            for ((colorName, colorValue) in colors) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (crosshairColorState.value == colorName) themeColor else Color(0xFF2A2A2A))
                        .clickable { 
                            crosshairColorState.value = colorName 
                            sharedPrefs.edit().putString("crosshair_color", colorName).apply()
                            if (currentPackage.isNotEmpty()) sharedPrefs.edit().putString("crosshair_color_$currentPackage", colorName).apply()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Box(modifier = Modifier.size(24.dp).clip(CircleShape).background(colorValue).border(1.dp, Color.Gray, CircleShape))
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text("Size", color = Color.Gray, fontSize = 12.sp)
        Slider(
            value = crosshairSizeState.value,
            onValueChange = { 
                crosshairSizeState.value = it 
                sharedPrefs.edit().putFloat("crosshair_size", it).apply()
                if (currentPackage.isNotEmpty()) sharedPrefs.edit().putFloat("crosshair_size_$currentPackage", it).apply()
            },
            valueRange = 16f..128f
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text("Opacity", color = Color.Gray, fontSize = 12.sp)
        Slider(
            value = crosshairOpacityState.value,
            onValueChange = { 
                crosshairOpacityState.value = it 
                sharedPrefs.edit().putFloat("crosshair_opacity", it).apply()
                if (currentPackage.isNotEmpty()) sharedPrefs.edit().putFloat("crosshair_opacity_$currentPackage", it).apply()
            },
            valueRange = 0.1f..1f
        )
    }
}
