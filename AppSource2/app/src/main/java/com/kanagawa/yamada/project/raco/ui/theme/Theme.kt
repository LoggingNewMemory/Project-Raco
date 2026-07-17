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
            if (darkTheme) {
                darkColorScheme(
                    primary = seedColor,
                    secondary = seedColor.copy(alpha = 0.8f),
                    tertiary = seedColor.copy(alpha = 0.6f),
                    background = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.BLACK, seedArgb, 0.05f)),
                    surface = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.BLACK, seedArgb, 0.1f)),
                    surfaceVariant = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.BLACK, seedArgb, 0.15f))
                )
            } else {
                lightColorScheme(
                    primary = seedColor,
                    secondary = seedColor.copy(alpha = 0.8f),
                    tertiary = seedColor.copy(alpha = 0.6f),
                    background = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.WHITE, seedArgb, 0.05f)),
                    surface = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.WHITE, seedArgb, 0.1f)),
                    surfaceVariant = androidx.compose.ui.graphics.Color(androidx.core.graphics.ColorUtils.blendARGB(android.graphics.Color.WHITE, seedArgb, 0.15f))
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