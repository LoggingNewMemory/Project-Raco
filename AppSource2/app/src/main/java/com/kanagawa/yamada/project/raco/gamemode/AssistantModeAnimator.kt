/*
 * Project Raco - Performance and Gaming Optimization Suite
 * Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package com.kanagawa.yamada.project.raco.gamemode

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.WindowManager
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.*
import androidx.savedstate.*
import com.kanagawa.yamada.project.raco.RacoGameAssistant

/**
 * Shows the ECO / BALANCED / AWAKEN animation as a separate full-screen, non-touchable overlay
 * window on top of the running game, whenever the mode is switched from the in-game Game Assistant.
 *
 * Feed it with [onState] using the labels of the Game Assistant selector
 * ("Powersave", "Balanced", "Awaken").
 */
class AssistantModeAnimator(
    private val context: Context,
    private val owner: RacoGameAssistant
) {
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var view: ComposeView? = null
    private val styleState = mutableStateOf<ModeStyle?>(null)
    private val phaseState = mutableStateOf(OverlayResult.APPLYING)
    private var shownAt = 0L
    private var pendingRemove: Runnable? = null

    fun onState(label: String, executing: Boolean) {
        if (executing) start(label) else finish()
    }

    private fun idFor(label: String): String? = when (label) {
        "Powersave" -> "2"
        "Balanced" -> "3"
        "Awaken" -> "4"
        else -> null
    }

    private fun start(label: String) {
        val id = idFor(label) ?: return
        val style = modeStyleFor(id) ?: return
        pendingRemove?.let { handler.removeCallbacks(it) }
        pendingRemove = null
        styleState.value = style
        phaseState.value = OverlayResult.APPLYING
        shownAt = SystemClock.uptimeMillis()
        Ps4Audio.init(context)
        Ps4Audio.playMode(id)
        if (view == null) addView()
    }

    private fun finish() {
        if (view == null) return
        phaseState.value = OverlayResult.DONE
        val elapsed = SystemClock.uptimeMillis() - shownAt
        val wait = (1500L - elapsed).coerceAtLeast(900L)
        pendingRemove?.let { handler.removeCallbacks(it) }
        val r = Runnable {
            pendingRemove = null
            removeView(animated = true)
        }
        pendingRemove = r
        handler.postDelayed(r, wait)
    }

    /** Removes the overlay immediately (assistant hidden / service destroyed). */
    fun dismissNow() {
        pendingRemove?.let { handler.removeCallbacks(it) }
        pendingRemove = null
        removeView(animated = false)
    }

    private fun addView() {
        val cv = ComposeView(context).apply {
            setViewTreeLifecycleOwner(owner)
            setViewTreeViewModelStoreOwner(owner)
            setViewTreeSavedStateRegistryOwner(owner)
            alpha = 0f
            setContent {
                MaterialTheme(colorScheme = darkColorScheme()) {
                    styleState.value?.let { AssistantAnimRoot(it, phaseState.value) }
                }
            }
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            }
        }
        try {
            wm.addView(cv, lp)
            view = cv
            cv.animate().alpha(1f).setDuration(220).start()
        } catch (e: Exception) {
            view = null
        }
    }

    private fun removeView(animated: Boolean) {
        val v = view ?: return
        view = null
        val remove = {
            try { if (v.parent != null) wm.removeView(v) } catch (e: Exception) {}
        }
        if (animated) {
            v.animate().alpha(0f).setDuration(350).withEndAction { remove() }.start()
        } else {
            remove()
        }
    }
}

@Composable
private fun AssistantAnimRoot(style: ModeStyle, result: OverlayResult) {
    // The assistant has no live progress value, so the bar eases towards 92% and
    // jumps to 100% when the switch completes.
    val p = remember { Animatable(0f) }
    LaunchedEffect(Unit) { p.animateTo(0.92f, tween(2600, easing = FastOutSlowInEasing)) }
    ModeOverlayContent(style = style, result = result, rawProgress = p.value, scrimAlpha = 0.74f)
}
