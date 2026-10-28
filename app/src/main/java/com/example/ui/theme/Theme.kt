package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = RamadaGoldLight,
    onPrimary = RamadaBurgundyDark,
    primaryContainer = RamadaBurgundy,
    onPrimaryContainer = RamadaGoldLight,
    secondary = RamadaGold,
    onSecondary = CharcoalDark,
    secondaryContainer = CharcoalSurfaceVariant,
    onSecondaryContainer = RamadaGoldLight,
    tertiary = RamadaBurgundyLight,
    background = CharcoalDark,
    onBackground = Color(0xFFF1F1F4),
    surface = CharcoalSurface,
    onSurface = Color(0xFFF1F1F4),
    surfaceVariant = CharcoalSurfaceVariant,
    onSurfaceVariant = Color(0xFFD4D4DC),
    outline = CharcoalBorder
)

private val LightColorScheme = lightColorScheme(
    primary = RamadaBurgundy,
    onPrimary = Color.White,
    primaryContainer = RamadaBurgundyDark,
    onPrimaryContainer = Color.White,
    secondary = RamadaGold,
    onSecondary = Color.White,
    secondaryContainer = RamadaGoldContainer,
    onSecondaryContainer = RamadaGoldDark,
    tertiary = RamadaBurgundyLight,
    background = CreamBackground,
    onBackground = CharcoalDark,
    surface = WhiteSurface,
    onSurface = CharcoalDark,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = Color(0xFF5A5852),
    outline = BorderLight
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
