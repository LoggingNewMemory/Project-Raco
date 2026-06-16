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
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
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
    perfModeTitle: String,
    perfModeCommand: String,
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
    var downscaleRes by remember { mutableStateOf(sharedPrefs.getString("downscaleRes_str", "1.0") ?: "1.0") }
    
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
                    .verticalScroll(rememberScrollState())
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

                // Kasane Preload
                Box(modifier = Modifier.fillMaxWidth(0.8f)) {
                    CustomDropdown(
                        title = "Kasane Preload",
                        options = listOf(
                            "none" to "None",
                            "n" to "Normal",
                            "d" to "Deep",
                            "x" to "Extreme",
                            "r" to "Recursive"
                        ),
                        selectedKey = selectedMode,
                        onOptionSelected = { 
                            selectedMode = it
                            sharedPrefs.edit().putString("selectedMode", it).apply()
                        },
                        accentColor = accentColor,
                        gilmerBold = gilmerBold
                    )
                }
                
                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    "Game Mode: $perfModeTitle", 
                    color = Color.White, 
                    fontFamily = gilmerBold, 
                    fontSize = 16.sp
                )
                
                Spacer(modifier = Modifier.height(16.dp))

                Box(modifier = Modifier.fillMaxWidth(0.8f)) {
                    CustomDropdown(
                        title = "Downscale Resolution",
                        options = listOf(
                            "1.0" to "Off (100%)",
                            "0.9" to "90%",
                            "0.8" to "80%",
                            "0.7" to "70%",
                            "0.6" to "60%",
                            "0.5" to "50%",
                            "0.4" to "40%",
                            "0.3" to "30%"
                        ),
                        selectedKey = downscaleRes,
                        onOptionSelected = { 
                            downscaleRes = it
                            sharedPrefs.edit().putString("downscaleRes_str", it).apply()
                        },
                        accentColor = accentColor,
                        gilmerBold = gilmerBold
                    )
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
                            enabled = isAngleSupported,
                            checked = useAngle,
                            onCheckedChange = { 
                                useAngle = it
                                sharedPrefs.edit().putBoolean("useAngle", it).apply()
                            },
                            accentColor = accentColor,
                            fontFamilyBold = gilmerBold
                        )
                        
                        OptionToggle(
                            title = "Use SkiaVK",
                            enabled = true,
                            checked = useSkia,
                            onCheckedChange = { 
                                useSkia = it
                                sharedPrefs.edit().putBoolean("useSkia", it).apply()
                            },
                            accentColor = accentColor,
                            fontFamilyBold = gilmerBold
                        )
                        
                        OptionToggle(
                            title = "PlayBoost",
                            enabled = true,
                            checked = enablePlayboost,
                            onCheckedChange = { 
                                enablePlayboost = it
                                sharedPrefs.edit().putBoolean("enablePlayboost", it).apply()
                            },
                            accentColor = accentColor,
                            fontFamilyBold = gilmerBold
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
                                // Free RAM (Equivalent to kill_all)
                                try {
                                    Runtime.getRuntime().exec(arrayOf("su", "-c", "sync; cmd activity kill-all > /dev/null 2>&1; pm trim-caches 100G > /dev/null 2>&1; echo 3 > /proc/sys/vm/drop_caches; logcat -b all -c")).waitFor()
                                } catch (e: Exception) {}

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
                                if (selectedMode != "none") {
                                    Runtime.getRuntime().exec(arrayOf("su", "-c", "/system/bin/linker64 /data/adb/modules/ProjectRaco/Binaries/kasane -a ${game.packageName} -m $selectedMode -l")).waitFor()
                                }

                                if (enablePlayboost) {
                                    launch {
                                        kotlinx.coroutines.delay(3000)
                                        val cmd = "pid=\$(pgrep -f ${game.packageName} | head -n 1); if [ -n \"\$pid\" ]; then for task in /proc/\$pid/task/*; do tid=\$(basename \$task); taskset -p ffffffff \$tid; done; fi"
                                        Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
                                    }
                                }

                                // Android 13+ Game Mode & Downscaling
                                try {
                                    val sysMode = when (perfModeCommand) {
                                        "performance" -> 2
                                        "battery" -> 3
                                        else -> 1
                                    }
                                    
                                    if (downscaleRes != "1.0") {
                                        Runtime.getRuntime().exec(arrayOf("su", "-c", "device_config put game_overlay ${game.packageName} mode=$sysMode,downscaleFactor=$downscaleRes")).waitFor()
                                    } else {
                                        Runtime.getRuntime().exec(arrayOf("su", "-c", "device_config delete game_overlay ${game.packageName}")).waitFor()
                                    }
                                    // Ensure mode is set to the current perfMode so intervention takes effect
                                    Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd game mode $perfModeCommand ${game.packageName}")).waitFor()
                                } catch (e: Exception) {}
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
                                
                                // Direct Daemon Trigger (Bypasses AutoGameMonitorService if it was killed by OEM)
                                try {
                                    val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                                    val mode = prefs.getString("global_perf_mode", "AWAKEN") ?: "AWAKEN"
                                    val socket = android.net.LocalSocket()
                                    val address = android.net.LocalSocketAddress("raco_gameservice", android.net.LocalSocketAddress.Namespace.ABSTRACT)
                                    socket.connect(address)
                                    val payload = "$mode:${game.packageName}"
                                    socket.outputStream.write(payload.toByteArray())
                                    socket.close()
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }
                            
                            onBack()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth(0.6f)
                        .align(Alignment.End)
                        .height(56.dp)
                        .border(2.dp, accentColor, RoundedCornerShape(12.dp)),
                    colors = ButtonDefaults.buttonColors(containerColor = accentColor.copy(alpha = 0.15f)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    if (isLaunching) {
                        CircularProgressIndicator(color = accentColor, modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.width(12.dp))
                        Text("LAUNCHING...", color = Color.White, fontFamily = gilmerBold, fontSize = 18.sp, letterSpacing = 2.sp)
                    } else {
                        Text("LAUNCH", color = Color.White, fontFamily = gilmerBold, fontSize = 18.sp, letterSpacing = 2.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun OptionToggle(
    title: String,
    enabled: Boolean,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    accentColor: Color,
    fontFamilyBold: FontFamily
) {
    val alpha by animateFloatAsState(if (enabled) 1f else 0.5f)
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(40.dp)
            .clickable(enabled = enabled) { onCheckedChange(!checked) }
            .alpha(alpha),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, color = Color.White, fontFamily = fontFamilyBold, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
            modifier = Modifier.scale(0.8f),
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = accentColor,
                uncheckedThumbColor = Color.Gray,
                uncheckedTrackColor = Color.DarkGray
            )
        )
    }
}

@Composable
fun CustomDropdown(
    title: String,
    options: List<Pair<String, String>>,
    selectedKey: String,
    onOptionSelected: (String) -> Unit,
    accentColor: Color,
    gilmerBold: FontFamily
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedTitle = options.find { it.first == selectedKey }?.second ?: "Select"

    Column(modifier = Modifier.fillMaxWidth()) {
        Text(title, color = Color.White, fontFamily = gilmerBold, fontSize = 16.sp)
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .border(1.dp, if (expanded) accentColor else Color.DarkGray, RoundedCornerShape(12.dp))
                .background(if (expanded) accentColor.copy(alpha=0.1f) else Color.Black.copy(alpha=0.3f), RoundedCornerShape(12.dp))
                .clip(RoundedCornerShape(12.dp))
                .clickable { expanded = !expanded }
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(selectedTitle, color = Color.White, fontFamily = gilmerBold, fontSize = 16.sp)
            Icon(Icons.Filled.ArrowDropDown, contentDescription = "Dropdown", tint = if (expanded) accentColor else Color.LightGray)
        }
        
        androidx.compose.animation.AnimatedVisibility(
            visible = expanded,
            enter = androidx.compose.animation.expandVertically(),
            exit = androidx.compose.animation.shrinkVertically()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .border(1.dp, Color.DarkGray.copy(alpha=0.5f), RoundedCornerShape(12.dp))
                    .background(Color(0xFF111111), RoundedCornerShape(12.dp))
                    .clip(RoundedCornerShape(12.dp))
            ) {
                options.forEach { (key, optionTitle) ->
                    val isSelected = selectedKey == key
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(44.dp)
                            .background(if (isSelected) accentColor.copy(alpha=0.15f) else Color.Transparent)
                            .clickable { onOptionSelected(key); expanded = false }
                            .padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(optionTitle, color = if (isSelected) Color.White else Color.LightGray, fontFamily = gilmerBold, fontSize = 15.sp)
                        if (isSelected) Box(modifier = Modifier.size(8.dp).background(accentColor, androidx.compose.foundation.shape.CircleShape))
                    }
                }
            }
        }
    }
}
