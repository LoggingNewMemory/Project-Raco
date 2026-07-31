package com.kanagawa.yamada.project.raco.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.toArgb

private val DarkColorScheme = darkColorScheme(
    primary = Purple80,
    secondary = PurpleGrey80,
    tertiary = Pink80
)

private val LightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40

    /* Other default colors to override
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = Color(0xFF1C1B1F),
    onSurface = Color(0xFF1C1B1F),
    */
)

@Composable
fun ProjectRacoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    // Dynamic color is available on Android 12+
    dynamicColor: Boolean = true,
    seedColor: androidx.compose.ui.graphics.Color? = null,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        seedColor != null -> {
            val seedArgb = seedColor.toArgb()
            
            // Adjust seed color to guarantee contrast against background
            var adjustedSeedArgb = seedArgb
            if (darkTheme) {
                // For dark theme (black bg), primary needs to be light enough
                while (androidx.core.graphics.ColorUtils.calculateLuminance(adjustedSeedArgb) < 0.2) {
                    adjustedSeedArgb = androidx.core.graphics.ColorUtils.blendARGB(adjustedSeedArgb, android.graphics.Color.WHITE, 0.1f)
                }
            } else {
                // For light theme (white bg), primary needs to be dark enough
                while (androidx.core.graphics.ColorUtils.calculateLuminance(adjustedSeedArgb) > 0.4) {
                    adjustedSeedArgb = androidx.core.graphics.ColorUtils.blendARGB(adjustedSeedArgb, android.graphics.Color.BLACK, 0.1f)
                }
            }
            val adjustedSeed = androidx.compose.ui.graphics.Color(adjustedSeedArgb)
            
            val isLightSeed = androidx.core.graphics.ColorUtils.calculateLuminance(adjustedSeedArgb) > 0.5
            val onSeedColor = if (isLightSeed) androidx.compose.ui.graphics.Color.Black else androidx.compose.ui.graphics.Color.White

            if (darkTheme) {
                darkColorScheme(
                    primary = adjustedSeed,
                    onPrimary = onSeedColor,
                    secondary = adjustedSeed.copy(alpha = 0.8f),
                    onSecondary = onSeedColor,
                    tertiary = adjustedSeed.copy(alpha = 0.6f),
                    onTertiary = onSeedColor,
                    background = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.BLACK, seedArgb, 0.05f)),
                    onBackground = androidx.compose.ui.graphics.Color.White,
                    surface = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.BLACK, seedArgb, 0.1f)),
                    onSurface = androidx.compose.ui.graphics.Color.White,
                    surfaceVariant = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.BLACK, seedArgb, 0.15f)),
                    onSurfaceVariant = androidx.compose.ui.graphics.Color(0xFFDDDDDD)
                )
            } else {
                lightColorScheme(
                    primary = adjustedSeed,
                    onPrimary = onSeedColor,
                    secondary = adjustedSeed.copy(alpha = 0.8f),
                    onSecondary = onSeedColor,
                    tertiary = adjustedSeed.copy(alpha = 0.6f),
                    onTertiary = onSeedColor,
                    background = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.WHITE, seedArgb, 0.05f)),
                    onBackground = androidx.compose.ui.graphics.Color.Black,
                    surface = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.WHITE, seedArgb, 0.1f)),
                    onSurface = androidx.compose.ui.graphics.Color.Black,
                    surfaceVariant = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.WHITE, seedArgb, 0.15f)),
                    onSurfaceVariant = androidx.compose.ui.graphics.Color(0xFF333333)
                )
            }
        }
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}