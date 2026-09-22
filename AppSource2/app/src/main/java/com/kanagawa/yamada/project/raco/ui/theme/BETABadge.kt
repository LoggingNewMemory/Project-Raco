package com.kanagawa.yamada.project.raco.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun BetaBadge(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(Color(0xFFFFB74D).copy(alpha = 0.2f), RoundedCornerShape(4.dp))
            .border(1.dp, Color(0xFFFFB74D), RoundedCornerShape(4.dp))
            .padding(horizontal = 4.dp, vertical = 2.dp)
    ) {
        Text(
            text = "BETA",
            color = Color(0xFFFFB74D),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
