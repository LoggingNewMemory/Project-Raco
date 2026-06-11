package com.kanagawa.yamada.project.raco

import android.content.Context
import android.content.Intent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader

@Composable
fun SlingshotScreen(
    game: Game,
    accentColor: Color,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val sharedPrefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
    
    val gilmerBold = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerBold.otf")))
    }
    val gilmerRegular = remember {
        FontFamily(androidx.compose.ui.text.font.Typeface(android.graphics.Typeface.createFromAsset(context.assets, "GilmerRegular.otf")))
    }

    var selectedMode by remember { mutableStateOf(sharedPrefs.getString("selectedMode", "n") ?: "n") }
    var useAngle by remember { mutableStateOf(sharedPrefs.getBoolean("useAngle", false)) }
    var useSkia by remember { mutableStateOf(sharedPrefs.getBoolean("useSkia", false)) }
    var enablePlayboost by remember { mutableStateOf(sharedPrefs.getBoolean("enablePlayboost", false)) }
    
    var isAngleSupported by remember { mutableStateOf(false) }
    var isLaunching by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("getprop", "ro.gfx.angle.supported"))
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val output = reader.readLine()
                isAngleSupported = output == "true"
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A))
    ) {
        // Subtle background gradient
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(accentColor.copy(alpha = 0.15f), Color.Transparent),
                        radius = 1000f
                    )
                )
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .displayCutoutPadding()
                .padding(24.dp),
            horizontalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // LEFT COLUMN
            Column(
                modifier = Modifier
                    .weight(0.45f)
                    .fillMaxHeight()
            ) {
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
                            "SLINGSHOT", 
                            color = accentColor, 
                            fontFamily = gilmerBold, 
                            fontSize = 24.sp, 
                            letterSpacing = 2.sp
                        )
                        Text(
                            "Preload Configuration", 
                            color = Color.LightGray, 
                            fontFamily = gilmerRegular, 
                            fontSize = 14.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Kasane Mode
                Text("Kasane Mode", color = Color.White, fontFamily = gilmerBold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val modes = listOf(
                        "n" to "Normal",
                        "d" to "Deep",
                        "x" to "Extreme",
                        "r" to "Recursive"
                    )
                    modes.forEach { (mode, title) ->
                        val isSelected = selectedMode == mode
                        Row(
                            modifier = Modifier
                                .fillMaxWidth(0.8f)
                                .height(48.dp) // Slightly smaller since there's no description
                                .border(
                                    if (isSelected) 2.dp else 1.dp,
                                    if (isSelected) accentColor else Color.DarkGray,
                                    RoundedCornerShape(12.dp)
                                )
                                .background(
                                    if (isSelected) accentColor.copy(alpha = 0.15f) else Color.Black.copy(alpha = 0.3f),
                                    RoundedCornerShape(12.dp)
                                )
                                .clickable { 
                                    selectedMode = mode
                                    sharedPrefs.edit().putString("selectedMode", mode).apply()
                                }
                                .padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(title, color = if (isSelected) Color.White else Color.LightGray, fontFamily = gilmerBold, fontSize = 16.sp)
                        }
                    }
                }
            }

            // RIGHT COLUMN
            Column(
                modifier = Modifier
                    .weight(0.55f)
                    .fillMaxHeight()
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .border(1.dp, Color.DarkGray, RoundedCornerShape(16.dp))
                        .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                        .padding(16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                    ) {
                        
                        OptionToggle(
                            title = "Use ANGLE Driver",
                            subtitle = if (isAngleSupported) "Force ANGLE renderer for OpenGL" else "Not supported on this device",
                            enabled = isAngleSupported,
                            checked = useAngle,
                            onCheckedChange = { 
                                useAngle = it
                                sharedPrefs.edit().putBoolean("useAngle", it).apply()
                            },
                            accentColor = accentColor,
                            fontFamilyBold = gilmerBold,
                            fontFamilyReg = gilmerRegular
                        )
                        
                        Spacer(modifier = Modifier.height(8.dp))
                        
                        OptionToggle(
                            title = "Use SkiaVK",
                            subtitle = "Force Skia Vulkan renderer",
                            enabled = true,
                            checked = useSkia,
                            onCheckedChange = { 
                                useSkia = it
                                sharedPrefs.edit().putBoolean("useSkia", it).apply()
                            },
                            accentColor = accentColor,
                            fontFamilyBold = gilmerBold,
                            fontFamilyReg = gilmerRegular
                        )
                        
                        Spacer(modifier = Modifier.height(8.dp))
                        
                        OptionToggle(
                            title = "PlayBoost",
                            subtitle = "Optimize thread affinity",
                            enabled = true,
                            checked = enablePlayboost,
                            onCheckedChange = { 
                                enablePlayboost = it
                                sharedPrefs.edit().putBoolean("enablePlayboost", it).apply()
                            },
                            accentColor = accentColor,
                            fontFamilyBold = gilmerBold,
                            fontFamilyReg = gilmerRegular
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Launch Button
                Button(
                    onClick = {
                        if (isLaunching) return@Button
                        isLaunching = true
                        coroutineScope.launch {
                            withContext(Dispatchers.IO) {
                                // Cleanup first
                                try {
                                    Runtime.getRuntime().exec(arrayOf("su", "-c", "settings delete global angle_debug_package; settings delete global angle_gl_driver_all_angle; settings delete global angle_gl_driver_selection_pkgs; settings delete global angle_gl_driver_selection_values; setprop debug.hwui.renderer none")).waitFor()
                                } catch (e: Exception) {}

                                if (useSkia) {
                                    Runtime.getRuntime().exec(arrayOf("su", "-c", "setprop debug.hwui.renderer skiavk")).waitFor()
                                }
                                if (useAngle && isAngleSupported) {
                                    Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put global angle_gl_driver_selection_pkgs ${game.packageName} && settings put global angle_gl_driver_selection_values angle")).waitFor()
                                }

                                // Run Kasane
                                Runtime.getRuntime().exec(arrayOf("su", "-c", "/data/adb/modules/ProjectRaco/Binaries/kasane -a ${game.packageName} -m $selectedMode -l")).waitFor()

                                if (enablePlayboost) {
                                    launch {
                                        kotlinx.coroutines.delay(3000)
                                        val cmd = "pid=\$(pgrep -f ${game.packageName} | head -n 1); if [ -n \"\$pid\" ]; then for task in /proc/\$pid/task/*; do tid=\$(basename \$task); taskset -p ffffffff \$tid; done; fi"
                                        Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
                                    }
                                }
                            }

                            // Launch Game
                            val intent = context.packageManager.getLaunchIntentForPackage(game.packageName)
                            if (intent != null) {
                                GameManager.setGameLastPlayed(context, game.packageName, System.currentTimeMillis())
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                context.startActivity(intent)

                                // Start the overlay service
                                val serviceIntent = Intent(context, GameOverlayService::class.java)
                                context.startService(serviceIntent)

                                // Start the persistent in-game menu service
                                val inGameIntent = Intent(context, InGameMenuService::class.java).apply {
                                    putExtra("package_name", game.packageName)
                                }
                                context.startService(inGameIntent)
                            }
                            
                            onBack()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .border(2.dp, accentColor, RoundedCornerShape(12.dp)),
                    colors = ButtonDefaults.buttonColors(containerColor = accentColor.copy(alpha = 0.15f)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    if (isLaunching) {
                        CircularProgressIndicator(color = accentColor, modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.width(12.dp))
                        Text("PRELOADING...", color = Color.White, fontFamily = gilmerBold, fontSize = 18.sp, letterSpacing = 2.sp)
                    } else {
                        Text("PRELOAD & LAUNCH", color = Color.White, fontFamily = gilmerBold, fontSize = 18.sp, letterSpacing = 2.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun OptionToggle(
    title: String,
    subtitle: String,
    enabled: Boolean,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    accentColor: Color,
    fontFamilyBold: FontFamily,
    fontFamilyReg: FontFamily
) {
    val alpha by animateFloatAsState(if (enabled) 1f else 0.5f)
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .clickable(enabled = enabled) { onCheckedChange(!checked) }
            .padding(12.dp)
            .alpha(alpha),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = Color.White, fontFamily = fontFamilyBold, fontSize = 15.sp)
            Spacer(modifier = Modifier.height(2.dp))
            Text(subtitle, color = Color.Gray, fontFamily = fontFamilyReg, fontSize = 12.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = accentColor,
                uncheckedThumbColor = Color.Gray,
                uncheckedTrackColor = Color.DarkGray
            )
        )
    }
}
