package com.kanagawa.yamada.project.raco

import android.content.Context
import android.content.Intent
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
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
import com.kanagawa.yamada.project.raco.RacoRed
import kotlin.math.roundToInt

@Composable
fun RefreshRateMenu(
    themeColor: Color = RacoRed,
    onClose: () -> Unit,
    onRateSelected: (Float) -> Unit
) {
    val context = LocalContext.current
    val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)

    var currentSelectedRate by remember { 
        mutableStateOf(prefs.getFloat("override_refresh_rate", 0f))
    }

    val displayModes = remember {
        windowManager.defaultDisplay.supportedModes
    }

    val availableRates = remember(displayModes) {
        displayModes.map { it.refreshRate.roundToInt() }
            .distinct()
            .sorted()
    }

    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val isTablet = configuration.smallestScreenWidthDp >= 600
    val topSpacerHeight = if (isTablet) 48.dp else 0.dp

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .wrapContentHeight()
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.End
    ) {
        Spacer(modifier = Modifier.height(topSpacerHeight))
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.End,
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        ) {
            Text(
                text = "REFRESH\nRATE",
                color = themeColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 1.sp,
                textAlign = androidx.compose.ui.text.style.TextAlign.End
            )
            Spacer(modifier = Modifier.width(16.dp))
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .background(Color.White.copy(alpha = 0.2f), androidx.compose.foundation.shape.RoundedCornerShape(6.dp))
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(6.dp))
                    .clickable { onClose() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Close Menu",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        // Options
        val options = listOf("Default") + availableRates.map { "$it Hz" }
        val optionValues = listOf(0f) + availableRates.map { it.toFloat() }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.End
        ) {
            options.forEachIndexed { index, optionLabel ->
                val value = optionValues[index]
                val isSelected = (currentSelectedRate == value)

                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.7f)
                        .background(
                            if (isSelected) themeColor else Color.Black.copy(alpha = 0.6f),
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp)
                        )
                        .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                        .clickable {
                            currentSelectedRate = value
                            onRateSelected(value)
                            prefs.edit().putFloat("override_refresh_rate", value).apply()
                            
                            val intent = Intent(context, RefreshRateService::class.java)
                            if (value == 0f) {
                                context.stopService(intent)
                                Thread {
                                    try {
                                        val cmd = "settings delete system min_refresh_rate; settings delete system peak_refresh_rate; settings delete system user_refresh_rate"
                                        Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
                                    } catch (e: Exception) {}
                                }.start()
                            } else {
                                intent.putExtra("refresh_rate", value)
                                context.startService(intent)
                                Thread {
                                    try {
                                        val cmd = "settings put system min_refresh_rate ${value}; settings put system peak_refresh_rate ${value}; settings put secure min_refresh_rate ${value}; settings put secure peak_refresh_rate ${value}; settings put system user_refresh_rate ${value.toInt()}; settings put global oneplus_screen_refresh_rate ${if (value == 120f) 2 else if (value == 90f) 1 else 0}; service call SurfaceFlinger 1035 i32 0; resetprop persist.graphics.game_default_frame_rate.enabled false; resetprop debug.graphics.game_default_frame_rate.disabled true"
                                        Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
                                    } catch (e: Exception) {}
                                }.start()
                            }
                        }
                        .padding(vertical = 12.dp, horizontal = 16.dp),
                    contentAlignment = Alignment.CenterEnd
                ) {
                    Text(
                        text = optionLabel,
                        color = if (isSelected) Color.Black else Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 0.5.sp
                    )
                }
            }
        }
    }
}
