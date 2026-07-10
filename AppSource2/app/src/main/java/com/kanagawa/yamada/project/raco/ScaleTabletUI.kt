package com.kanagawa.yamada.project.raco

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

@Composable
fun ScaleTabletUI(content: @Composable () -> Unit) {
    // Android natively handles DPI scaling through LocalDensity. 
    // Artificially multiplying density by 1.5x when smallestScreenWidthDp >= 600
    // breaks the layout on devices with custom high-DPI settings (since they want things smaller, not bigger).
    content()
}
