package com.kanagawa.yamada.project.raco.ui.theme

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CardColors
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CardElevation
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(16.dp),
    colors: CardColors = CardDefaults.cardColors(
        containerColor = Color.White.copy(alpha = 0.15f),
        contentColor = Color.White
    ),
    elevation: CardElevation = CardDefaults.cardElevation(0.dp),
    applyAlpha: Boolean = true,
    border: BorderStroke? = BorderStroke(1.dp, Color.White.copy(alpha = 0.2f)),
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val baseColor = colors.containerColor
    val finalBgColor = if (applyAlpha && baseColor.alpha > 0.5f) baseColor.copy(alpha = 0.15f) else baseColor

    val darkTheme = isSystemInDarkTheme()
    val borderColor = if (darkTheme) Color.White.copy(alpha = 0.1f) else Color.White.copy(alpha = 0.4f)
    
    val actualBorder = border ?: BorderStroke(1.dp, borderColor)

    val cardModifier = if (onClick != null) {
        modifier.clip(shape).clickable(onClick = onClick)
    } else {
        modifier.clip(shape)
    }

    Surface(
        modifier = cardModifier,
        shape = shape,
        color = finalBgColor,
        contentColor = colors.contentColor,
        border = actualBorder,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp
    ) {
        Box(
            modifier = Modifier.background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.1f),
                        Color.Transparent
                    )
                )
            )
        ) {
            Column(content = content)
        }
    }
}
