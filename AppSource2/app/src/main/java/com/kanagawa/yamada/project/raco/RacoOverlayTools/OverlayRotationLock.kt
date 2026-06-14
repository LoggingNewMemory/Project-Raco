package com.kanagawa.yamada.project.raco.RacoOverlayTools

import android.provider.Settings
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ScreenLockRotation
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

@Composable
fun OverlayRotationLock(themeColor: Color) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", android.content.Context.MODE_PRIVATE)
    var isLocked by remember { mutableStateOf(prefs.getBoolean("is_rotation_locked", false)) }

    val animatedBackgroundColor by animateColorAsState(
        targetValue = if (isLocked) themeColor else Color.Transparent,
        animationSpec = tween(durationMillis = 300)
    )
    val animatedIconColor by animateColorAsState(
        targetValue = if (isLocked) Color.White else themeColor,
        animationSpec = tween(durationMillis = 300)
    )

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .background(animatedBackgroundColor, RoundedCornerShape(11.4.dp))
                .border(1.dp, themeColor, RoundedCornerShape(11.4.dp))
                .clip(RoundedCornerShape(11.4.dp))
                .clickable {
                    isLocked = !isLocked
                    prefs.edit().putBoolean("is_rotation_locked", isLocked).apply()
                    val intent = android.content.Intent(context, com.kanagawa.yamada.project.raco.RotationLockService::class.java)
                    if (isLocked) {
                        context.startService(intent)
                    } else {
                        context.stopService(intent)
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.ScreenLockRotation,
                contentDescription = "Rotation Lock",
                tint = animatedIconColor,
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Rotation",
            color = themeColor,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "Lock",
            color = themeColor,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.offset(y = (-2).dp)
        )
    }
}
