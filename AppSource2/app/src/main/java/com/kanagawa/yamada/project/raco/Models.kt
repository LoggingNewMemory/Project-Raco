package com.kanagawa.yamada.project.raco

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap

enum class PerfMode(val color: Color, val title: String) {
    AWAKEN(Color(0xFFE53935), "Awaken"),
    BALANCED(Color(0xFFFFD600), "Balanced"),
    POWERSAVE(Color(0xFF00E676), "Powersave")
}

data class Game(
    val name: String,
    val packageName: String,
    val durationPlayed: String,
    val icon: ImageBitmap?,
    val lastTimeUsed: Long = 0L
)
