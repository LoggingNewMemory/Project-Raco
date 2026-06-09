package com.kanagawa.yamada.project.raco

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner

class InGameMenuService : Service() {
    private var windowManager: WindowManager? = null
    private var mainComposeView: ComposeView? = null
    private var leftTriggerView: ComposeView? = null
    private var rightTriggerView: ComposeView? = null
    private var lifecycleOwner: MyLifecycleOwner? = null

    private var isLeftOpen = false
    private var isRightOpen = false
    
    // We pass a callback to NubiaOverlay so it can update its own internal state to trigger the animation.
    private var openLeftMenu: (() -> Unit)? = null
    private var openRightMenu: (() -> Unit)? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        lifecycleOwner = MyLifecycleOwner().apply {
            performRestore(null)
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        }
        
        setupMainOverlay()
        setupTriggers()
        
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    private fun setupMainOverlay() {
        mainComposeView = ComposeView(this).apply {
            setContent {
                NubiaOverlay(
                    onStateBind = { openLeft, openRight ->
                        openLeftMenu = openLeft
                        openRightMenu = openRight
                    },
                    onClose = {
                        isLeftOpen = false
                        isRightOpen = false
                        updateMainOverlayTouchable()
                    }
                )
            }
        }

        setupViewTree(mainComposeView!!)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE, // Initially NOT touchable!
            PixelFormat.TRANSLUCENT
        )
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        windowManager?.addView(mainComposeView, params)
    }

    private fun setupTriggers() {
        // Left Trigger
        leftTriggerView = ComposeView(this).apply {
            setContent {
                Box(modifier = Modifier.fillMaxSize().background(Color.Transparent).pointerInput(Unit) {
                    detectHorizontalDragGestures { _, dragAmount ->
                        if (dragAmount > 10 && !isLeftOpen) {
                            isLeftOpen = true
                            updateMainOverlayTouchable()
                            openLeftMenu?.invoke()
                        }
                    }
                }) {
                    Box(modifier = Modifier.fillMaxSize().background(Color.White.copy(alpha=0.1f), RoundedCornerShape(2.dp)))
                }
            }
        }
        setupViewTree(leftTriggerView!!)
        
        val leftParams = WindowManager.LayoutParams(
            32, // width in pixels (will be small)
            400, // height in pixels
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        leftParams.gravity = Gravity.START or Gravity.CENTER_VERTICAL
        windowManager?.addView(leftTriggerView, leftParams)

        // Right Trigger
        rightTriggerView = ComposeView(this).apply {
            setContent {
                Box(modifier = Modifier.fillMaxSize().background(Color.Transparent).pointerInput(Unit) {
                    detectHorizontalDragGestures { _, dragAmount ->
                        if (dragAmount < -10 && !isRightOpen) {
                            isRightOpen = true
                            updateMainOverlayTouchable()
                            openRightMenu?.invoke()
                        }
                    }
                }) {
                    Box(modifier = Modifier.fillMaxSize().background(Color.White.copy(alpha=0.1f), RoundedCornerShape(2.dp)))
                }
            }
        }
        setupViewTree(rightTriggerView!!)
        
        val rightParams = WindowManager.LayoutParams(
            32, // width
            400, // height
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        rightParams.gravity = Gravity.END or Gravity.CENTER_VERTICAL
        windowManager?.addView(rightTriggerView, rightParams)
    }
    
    private fun updateMainOverlayTouchable() {
        val params = mainComposeView?.layoutParams as? WindowManager.LayoutParams ?: return
        if (isLeftOpen || isRightOpen) {
            // Remove FLAG_NOT_TOUCHABLE so it can receive touches (clicks, close swipes)
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            // Add FLAG_NOT_TOUCHABLE so game receives touches
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        windowManager?.updateViewLayout(mainComposeView, params)
    }

    private fun setupViewTree(view: ComposeView) {
        view.setViewTreeLifecycleOwner(lifecycleOwner)
        view.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        val viewModelStore = ViewModelStore()
        view.setViewTreeViewModelStoreOwner(object : ViewModelStoreOwner {
            override val viewModelStore: ViewModelStore get() = viewModelStore
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        mainComposeView?.let { windowManager?.removeView(it) }
        leftTriggerView?.let { windowManager?.removeView(it) }
        rightTriggerView?.let { windowManager?.removeView(it) }
    }
}
