package com.kanagawa.yamada.project.raco

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun Credits(
    accentColor: Color,
    gilmerBold: FontFamily,
    gilmerRegular: FontFamily,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? Activity

    DisposableEffect(Unit) {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        onDispose {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE
        }
    }

    val contributors = listOf(
        "Rem01 Gaming", "MiAzami", "Kazuyoo", "RiProG",
        "HoyoSlave", "Koneko_dev", "Not_ValentineSTCV",
        "Andreyka4_45", "Zexshia", "kaminarich",
        "fuckyoustan", "Xyanz_25", "hirauki", "KanaDev_IS",
        "And all testers"
    )

    var deviceInfo by remember { mutableStateOf<Map<String, String>>(emptyMap()) }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            val model = android.os.Build.MODEL
            val cpu = android.os.Build.HARDWARE
            val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val memInfo = android.app.ActivityManager.MemoryInfo()
            actManager.getMemoryInfo(memInfo)
            val ramGb = kotlin.math.ceil(memInfo.totalMem.toDouble() / (1024 * 1024 * 1024)).toInt()
            val statFs = android.os.StatFs(android.os.Environment.getDataDirectory().path)
            val totalStorageGb = statFs.totalBytes.toDouble() / (1024 * 1024 * 1024)
            val storageText = when {
                totalStorageGb > 500 -> "1 TB"
                totalStorageGb > 240 -> "512 GB"
                totalStorageGb > 200 -> "256 GB"
                totalStorageGb > 100 -> "128 GB"
                totalStorageGb > 50 -> "64 GB"
                else -> "${totalStorageGb.toInt()} GB"
            }
            var batteryText = "Unknown"
            try {
                val powerProfileClass = Class.forName("com.android.internal.os.PowerProfile")
                val powerProfile = powerProfileClass.getConstructor(Context::class.java).newInstance(context)
                val batteryCapacity = powerProfileClass.getMethod("getBatteryCapacity").invoke(powerProfile) as Double
                if (batteryCapacity > 0) {
                    batteryText = "${batteryCapacity.toInt()} mAh"
                }
            } catch (e: Exception) {}

            deviceInfo = mapOf(
                "Device" to model,
                "CPU" to cpu,
                "RAM" to "$ramGb GB",
                "Storage" to storageText,
                "Battery" to batteryText
            )
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A)) // Solid background, acting as a page
            .systemBarsPadding() // Keep clear of notches
    ) {
        // Back Button
        Box(
            modifier = Modifier
                .padding(16.dp)
                .size(48.dp)
                .background(Color.White.copy(alpha = 0.1f), androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                .clickable { onClose() }
                .align(Alignment.TopStart),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 80.dp, start = 24.dp, end = 24.dp, bottom = 24.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Device Info Block
            if (deviceInfo.isNotEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.End
                ) {
                    val infoOrder = listOf("Device", "CPU", "RAM", "Storage", "Battery")
                    infoOrder.forEachIndexed { index, label ->
                        val value = deviceInfo[label] ?: ""
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(vertical = 12.dp)
                        ) {
                            Text(value, color = Color.White, fontFamily = gilmerBold, fontSize = 16.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(label, color = Color.Gray, fontFamily = gilmerRegular, fontSize = 14.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            if (index == 0) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color.Gray) // Just a visual chevron
                            } else {
                                Text("|", color = accentColor, fontSize = 16.sp)
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Credits Title
            Text(
                "Thank you to everyone who supported the project",
                color = Color.White,
                fontFamily = gilmerBold,
                fontSize = 20.sp,
                textDecoration = TextDecoration.Underline,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Contributors
            contributors.forEach { contributor ->
                Text(
                    "• $contributor",
                    color = Color.White,
                    fontFamily = gilmerRegular,
                    fontSize = 16.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            Text(
                "\"We Are Project Raco\"",
                color = accentColor,
                fontFamily = gilmerBold,
                fontSize = 16.sp,
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(48.dp))
        }
    }
}
