package com.kanagawa.yamada.project.raco

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
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
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class ToastOverlayService : Service() {

    companion object {
        private var currentToastLayout: LinearLayout? = null
        private var removeRunnable: Runnable? = null
        private val handler = Handler(Looper.getMainLooper())
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val msg = intent?.getStringExtra("msg")
        if (msg != null) {
            val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
            val until = prefs.getLong("entrance_anim_playing_until", 0L)
            val now = System.currentTimeMillis()
            var delayTime = 0L
            if (now < until) {
                delayTime = until - now
            }
            
            if (delayTime > 0) {
                handler.postDelayed({ showOverlayToast(msg) }, delayTime)
            } else {
                showOverlayToast(msg)
            }
        }
        return START_NOT_STICKY
    }

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()

    private fun showOverlayToast(msg: String) {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Remove existing toast if present
        currentToastLayout?.let {
            try {
                it.animate().cancel()
                it.visibility = View.GONE
                windowManager.removeView(it)
            } catch (e: Exception) {
                // Ignore if view was already removed
            }
        }
        removeRunnable?.let { handler.removeCallbacks(it) }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dpToPx(80)
            windowAnimations = 0 // Disable default OS window animations to prevent exit flicker
        }

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
            setPadding(dpToPx(24), dpToPx(12), dpToPx(24), dpToPx(12))
            elevation = dpToPx(8).toFloat()
            
            // Initial state for animation
            alpha = 0f
            translationY = dpToPx(30).toFloat()
        }

        // Text container for fill animation
        val textContainer = FrameLayout(this)

        val baseText = TextView(this).apply {
            text = msg
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            letterSpacing = 0.02f
        }

        // Determine dynamic color based on message content
        val dynamicColorHex = when {
            msg.contains("Awaken", ignoreCase = true) -> "#E53935" // Red
            msg.contains("Balanced", ignoreCase = true) -> "#FFD600" // Yellow
            msg.contains("Eco", ignoreCase = true) || msg.contains("Powersave", ignoreCase = true) -> "#00E676" // Green
            else -> "#FFFFFF" // Default White
        }
        val dynamicColor = Color.parseColor(dynamicColorHex)

        val fillText = TextView(this).apply {
            text = msg
            setTextColor(dynamicColor) // Dynamic color
            textSize = 15f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            letterSpacing = 0.02f
            alpha = 0f // Hidden initially until layout is done
        }

        textContainer.addView(baseText)
        textContainer.addView(fillText)
        layout.addView(textContainer)

        try {
            windowManager.addView(layout, params)
            currentToastLayout = layout
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
            .withEndAction {
                // Start filling animation after layout is shown
                fillText.alpha = 1f
                ValueAnimator.ofFloat(0f, 1f).apply {
                    duration = 600
                    interpolator = DecelerateInterpolator()
                    addUpdateListener { animator ->
                        val progress = animator.animatedValue as Float
                        val rightClip = (fillText.width * progress).toInt()
                        fillText.clipBounds = Rect(0, 0, rightClip, fillText.height)
                    }
                    start()
                }
            }
            .start()

        // Setup removal
        val removalTask = Runnable {
            if (currentToastLayout == layout) {
                // Exit animation: fade out and pull down (reverse of entry)
                layout.animate().cancel()
                layout.animate()
                    .alpha(0f)
                    .translationY(dpToPx(30).toFloat())
                    .setDuration(300)
                    .setInterpolator(AccelerateInterpolator())
                    .withEndAction {
                        if (currentToastLayout == layout) {
                            try {
                                layout.visibility = View.GONE
                                windowManager.removeView(layout)
                                currentToastLayout = null
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                    }
                    .start()
            }
        }
        
        removeRunnable = removalTask
        handler.postDelayed(removalTask, 3000)
    }
}
