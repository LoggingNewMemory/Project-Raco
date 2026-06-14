package com.kanagawa.yamada.project.raco.RacoOverlayTools

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DisplaySettings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kanagawa.yamada.project.raco.RacoRed

@Composable
fun OverlayRefreshRate(
    themeColor: Color = RacoRed,
    currentRate: Float = 0f,
    onClick: () -> Unit
) {
    val isActive = currentRate > 0f

    val animatedBackgroundColor by animateColorAsState(
        targetValue = if (isActive) themeColor else Color.Transparent,
        animationSpec = tween(300),
        label = "bgColorRefresh"
    )

    val animatedIconColor by animateColorAsState(
        targetValue = if (isActive) Color.White else themeColor,
        animationSpec = tween(300),
        label = "iconColorRefresh"
    )

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .background(animatedBackgroundColor, RoundedCornerShape(11.4.dp))
                .border(1.dp, themeColor, RoundedCornerShape(11.4.dp))
                .clip(RoundedCornerShape(11.4.dp))
                .clickable { onClick() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.DisplaySettings,
                contentDescription = "Refresh Rate",
                tint = animatedIconColor,
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = if (isActive) "${currentRate.toInt()}" else "Refresh",
            color = themeColor,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = if (isActive) "Hz" else "Rate",
            color = themeColor,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.offset(y = (-2).dp)
        )
    }
}
