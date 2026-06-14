package com.kanagawa.yamada.project.raco

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.LinearLayout
import android.widget.TextView

class ToastOverlayService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val msg = intent?.getStringExtra("msg")
        if (msg != null) {
            showOverlayToast(msg)
        }
        return START_NOT_STICKY
    }

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()

    private fun showOverlayToast(msg: String) {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        params.y = dpToPx(80)

        // Create a premium capsule background
        val backgroundDrawable = GradientDrawable().apply {
            setColor(Color.parseColor("#E6121212")) // Dark translucent glass-like
            cornerRadius = dpToPx(50).toFloat() // Fully rounded ends
            setStroke(dpToPx(1), Color.parseColor("#33FFFFFF")) // Subtle border
        }

        // Layout container
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = backgroundDrawable
            setPadding(dpToPx(20), dpToPx(12), dpToPx(20), dpToPx(12))
            elevation = dpToPx(8).toFloat()
            
            // Initial state for animation
            alpha = 0f
            translationY = dpToPx(30).toFloat()
        }

        // Sleek indicator dot
        val dot = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#00E676")) // Vibrant green accent
            }
            layoutParams = LinearLayout.LayoutParams(dpToPx(8), dpToPx(8)).apply {
                marginEnd = dpToPx(12)
            }
        }
        layout.addView(dot)

        // Text view
        val textView = TextView(this).apply {
            text = msg
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            letterSpacing = 0.02f
        }
        layout.addView(textView)

        try {
            windowManager.addView(layout, params)
        } catch (e: Exception) {
            e.printStackTrace()
            return
        }

        // Entry animation (Slide up & Fade in with Overshoot)
        layout.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(450)
            .setInterpolator(OvershootInterpolator(1.2f))
            .start()

        // Exit animation and removal
        Handler(Looper.getMainLooper()).postDelayed({
            layout.animate()
                .alpha(0f)
                .translationY(dpToPx(20).toFloat())
                .setDuration(350)
                .setInterpolator(AccelerateInterpolator())
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        try {
                            windowManager.removeView(layout)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                })
                .start()
        }, 3000)
    }
}
