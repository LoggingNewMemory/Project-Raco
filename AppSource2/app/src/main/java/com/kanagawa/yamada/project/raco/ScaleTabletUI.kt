package com.kanagawa.yamada.project.raco

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

@Composable
fun ScaleTabletUI(content: @Composable () -> Unit) {
    val configuration = LocalConfiguration.current
    // Tablets typically have smallestScreenWidthDp >= 600.
    val isTablet = configuration.smallestScreenWidthDp >= 600

    if (!isTablet) {
        content()
        return
    }

    val currentDensity = LocalDensity.current
    val scaledDensity = Density(
        density = currentDensity.density * 1.5f,
        fontScale = currentDensity.fontScale * 1.5f
    )

    CompositionLocalProvider(LocalDensity provides scaledDensity) {
        content()
    }
}
