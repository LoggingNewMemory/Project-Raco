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

package com.kanagawa.yamada.project.raco.tools

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.content.ContextCompat
import kotlin.math.roundToInt

/**
 * PixelSleep: keeps a small, evenly spread share of the screen's pixels black.
 * On OLED/AMOLED panels a black pixel emits no light, so those pixels draw (almost) no power.
 *
 * It is a full-screen, non-touchable overlay window that tiles an 8x8 ordered-dither pattern.
 * Settings (amount, pixel size) are edited in the app; the Game Assistant only flips the switch.
 */
object PixelSleepController {
    private const val PREFS = "raco_app_config"
    private const val KEY_ENABLED = "pixelsleep_enabled"
    private const val KEY_PERCENT = "pixelsleep_percent"
    private const val KEY_SIZE = "pixelsleep_size"
    private const val KEY_PREV_UNTRUSTED = "pixelsleep_prev_untrusted"

    const val MIN_PERCENT = 2
    const val MAX_PERCENT = 50

    private val main = Handler(Looper.getMainLooper())
    private var view: PixelSleepView? = null
    private var params: WindowManager.LayoutParams? = null

    private fun prefs(c: Context) = c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(c: Context) = prefs(c).getBoolean(KEY_ENABLED, false)
    fun percent(c: Context) = prefs(c).getInt(KEY_PERCENT, 12).coerceIn(MIN_PERCENT, MAX_PERCENT)
    fun size(c: Context) = prefs(c).getInt(KEY_SIZE, 1).coerceIn(1, 3)

    fun setPercent(c: Context, v: Int) {
        prefs(c).edit().putInt(KEY_PERCENT, v.coerceIn(MIN_PERCENT, MAX_PERCENT)).apply()
        refresh(c)
    }

    fun setSize(c: Context, v: Int) {
        prefs(c).edit().putInt(KEY_SIZE, v.coerceIn(1, 3)).apply()
        refresh(c)
    }

    fun setEnabled(c: Context, on: Boolean) {
        prefs(c).edit().putBoolean(KEY_ENABLED, on).apply()
        refresh(c)
    }

    /** Live preview while a slider is being dragged (does not persist anything). */
    fun preview(percent: Int, size: Int) {
        main.post { view?.setPattern(percent, size) }
    }

    /** Brings the overlay and its service in line with the saved settings. Safe from any thread. */
    fun refresh(context: Context) {
        val app = context.applicationContext
        main.post {
            if (isEnabled(app)) {
                try {
                    ContextCompat.startForegroundService(app, Intent(app, PixelSleepService::class.java))
                } catch (e: Exception) {
                    // Not allowed to start a foreground service right now: the overlay still works while the process lives.
                }
                showOrUpdate(app)
            } else {
                hide(app)
                try { app.stopService(Intent(app, PixelSleepService::class.java)) } catch (e: Exception) {}
            }
        }
    }

    /** Must run on the main thread. */
    internal fun showOrUpdate(app: Context) {
        if (!Settings.canDrawOverlays(app)) return
        val p = percent(app)
        val s = size(app)
        val existing = view
        if (existing != null) {
            existing.setPattern(p, s)
            return
        }
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val v = PixelSleepView(app)
        v.setPattern(p, s)
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            title = "PixelSleep"
            // Android 12+ blocks touches that pass through untrusted overlays more opaque than 0.8,
            // so start at 0.8 (always safe) and only go to 1.0 once that check is verifiably disabled.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) alpha = 0.8f
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            }
        }
        try {
            wm.addView(v, lp)
            view = v
            params = lp
        } catch (e: Exception) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Thread {
                val ok = allowUntrustedTouches(app)
                if (ok) {
                    main.post {
                        val cur = view
                        val curLp = params
                        if (cur != null && curLp != null && cur === v) {
                            curLp.alpha = 1.0f
                            try { wm.updateViewLayout(cur, curLp) } catch (e: Exception) {}
                        }
                    }
                }
            }.start()
        }
    }

    private fun hide(app: Context) {
        val v = view
        view = null
        params = null
        if (v != null) {
            try {
                val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeView(v)
            } catch (e: Exception) {}
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Thread { restoreUntrustedTouches(app) }.start()
        }
    }

    // ---- Android 12+ untrusted touch handling (root) -------------------------------------------------

    private fun su(cmd: String): String = try {
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor()
        out.trim()
    } catch (e: Exception) {
        ""
    }

    /** Returns true only if block_untrusted_touches is verifiably 0, so a fully opaque overlay cannot block touches. */
    private fun allowUntrustedTouches(app: Context): Boolean {
        val cur = su("settings get global block_untrusted_touches")
        if (cur == "0") return true
        val p = prefs(app)
        if (p.getString(KEY_PREV_UNTRUSTED, null) == null) {
            p.edit().putString(KEY_PREV_UNTRUSTED, if (cur.isEmpty()) "null" else cur).apply()
        }
        su("settings put global block_untrusted_touches 0")
        return su("settings get global block_untrusted_touches") == "0"
    }

    private fun restoreUntrustedTouches(app: Context) {
        val p = prefs(app)
        val prev = p.getString(KEY_PREV_UNTRUSTED, null) ?: return
        if (prev == "null") su("settings delete global block_untrusted_touches")
        else if (prev.all { it.isDigit() }) su("settings put global block_untrusted_touches $prev")
        p.edit().remove(KEY_PREV_UNTRUSTED).apply()
    }
}

/** Draws the repeating dither tile; opaque-black cells are the "sleeping" pixels. */
internal class PixelSleepView(context: Context) : View(context) {
    private val paint = Paint().apply {
        isFilterBitmap = false
        isAntiAlias = false
        isDither = false
    }

    fun setPattern(percent: Int, size: Int) {
        val count = (percent / 100f * 64f).roundToInt().coerceIn(1, 40)
        val dim = 8 * size
        val px = IntArray(dim * dim)
        for (y in 0 until dim) {
            for (x in 0 until dim) {
                val rank = BAYER[(y / size) * 8 + (x / size)]
                px[y * dim + x] = if (rank < count) 0xFF000000.toInt() else 0
            }
        }
        val bmp = Bitmap.createBitmap(px, dim, dim, Bitmap.Config.ARGB_8888)
        paint.shader = BitmapShader(bmp, Shader.TileMode.REPEAT, Shader.TileMode.REPEAT)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    private companion object {
        // 8x8 Bayer ordered-dither ranks: the first N ranks are spread evenly over the tile.
        val BAYER = intArrayOf(
            0, 32, 8, 40, 2, 34, 10, 42,
            48, 16, 56, 24, 50, 18, 58, 26,
            12, 44, 4, 36, 14, 46, 6, 38,
            60, 28, 52, 20, 62, 30, 54, 22,
            3, 35, 11, 43, 1, 33, 9, 41,
            51, 19, 59, 27, 49, 17, 57, 25,
            15, 47, 7, 39, 13, 45, 5, 37,
            63, 31, 55, 23, 61, 29, 53, 21
        )
    }
}
