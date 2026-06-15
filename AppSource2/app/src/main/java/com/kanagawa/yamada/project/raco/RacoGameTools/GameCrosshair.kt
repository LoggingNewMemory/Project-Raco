package com.kanagawa.yamada.project.raco.RacoGameTools

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.WindowManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.graphics.SolidColor
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.kanagawa.yamada.project.raco.MyLifecycleOwner

object CrosshairData {
    fun getCrosshair(index: Int): ImageVector {
        return when (index) {
            0 -> ImageVector.Builder(
                name = "crosshair_1", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 32f, viewportHeight = 32f
            ).apply {
                addPath(
                    pathData = addPathNodes("M30 15.25h-3.326c-0.385-5.319-4.605-9.539-9.889-9.922l-0.035-0.002v-3.326c0-0.414-0.336-0.75-0.75-0.75s-0.75 0.336-0.75 0.75v0 3.326c-5.319 0.385-9.539 4.605-9.922 9.889l-0.002 0.035h-3.326c-0.414 0-0.75 0.336-0.75 0.75s0.336 0.75 0.75 0.75v0h3.326c0.385 5.319 4.605 9.539 9.889 9.922l0.035 0.002v3.326c0 0.414 0.336 0.75 0.75 0.75s0.75-0.336 0.75-0.75v0-3.326c5.319-0.385 9.539-4.605 9.922-9.889l0.002-0.035h3.326c0.414 0 0.75-0.336 0.75-0.75s-0.336-0.75-0.75-0.75v0zM16.75 25.174v-3.174c0-0.414-0.336-0.75-0.75-0.75s-0.75 0.336-0.75 0.75v0 3.174c-4.492-0.378-8.046-3.932-8.422-8.39l-0.002-0.034h3.174c0.414 0 0.75-0.336 0.75-0.75s-0.336-0.75-0.75-0.75v0h-3.174c0.378-4.492 3.932-8.046 8.39-8.422l0.034-0.002v3.174c0 0.414 0.336 0.75 0.75 0.75s0.75-0.336 0.75-0.75v0-3.174c4.492 0.378 8.046 3.932 8.422 8.39l0.002 0.034h-3.174c-0.414 0-0.75 0.336-0.75 0.75s0.336 0.75 0.75 0.75v0h3.174c-0.379 4.492-3.932 8.045-8.39 8.422l-0.034 0.002z"),
                    fill = SolidColor(Color.White)
                )
            }.build()
            1 -> ImageVector.Builder(
                name = "crosshair_2", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 256f, viewportHeight = 256f
            ).apply {
                addPath(
                    pathData = addPathNodes("M128,32a96,96,0,1,0,96,96A96.10874,96.10874,0,0,0,128,32Zm4,183.90527V180a4,4,0,0,0-8,0v35.90527A88.1149,88.1149,0,0,1,40.09473,132H76a4,4,0,0,0,0-8H40.09473A88.1149,88.1149,0,0,1,124,40.09473V76a4,4,0,0,0,8,0V40.09473A88.1149,88.1149,0,0,1,215.90527,124H180a4,4,0,0,0,0,8h35.90527A88.1149,88.1149,0,0,1,132,215.90527Z"),
                    fill = SolidColor(Color.White)
                )
            }.build()
            2 -> ImageVector.Builder(
                name = "crosshair_3", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 256f, viewportHeight = 256f
            ).apply {
                addPath(
                    pathData = addPathNodes("M236,124H219.90771A92.11679,92.11679,0,0,0,132,36.09229V20a4,4,0,0,0-8,0V36.09229A92.11679,92.11679,0,0,0,36.09229,124H20a4,4,0,0,0,0,8H36.09229A92.11679,92.11679,0,0,0,124,219.90771V236a4,4,0,0,0,8,0V219.90771A92.11679,92.11679,0,0,0,219.90771,132H236a4,4,0,0,0,0-8ZM132,211.89844V196a4,4,0,0,0-8,0v15.89844A84.10665,84.10665,0,0,1,44.10156,132H60a4,4,0,0,0,0-8H44.10156A84.10665,84.10665,0,0,1,124,44.10156V60a4,4,0,0,0,8,0V44.10156A84.10666,84.10666,0,0,1,211.89844,124H196a4,4,0,0,0,0,8h15.89844A84.10666,84.10666,0,0,1,132,211.89844ZM128,92a36,36,0,1,0,36,36A36.04061,36.04061,0,0,0,128,92Zm0,64a28,28,0,1,1,28-28A28.03146,28.03146,0,0,1,128,156Z"),
                    fill = SolidColor(Color.White)
                )
            }.build()
            3 -> ImageVector.Builder(
                name = "crosshair_4", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 512f, viewportHeight = 512f
            ).apply {
                addPath(
                    pathData = addPathNodes("M247 32v23.21C143.25 59.8 59.798 143.25 55.21 247H32v18h23.21C59.8 368.75 143.25 452.202 247 456.79V480h18v-23.21C368.75 452.2 452.202 368.75 456.79 265H480v-18h-23.21C452.2 143.25 368.75 59.798 265 55.21V32h-18zm0 41.223V128h18V73.223C359 77.76 434.24 153 438.777 247H384v18h54.777C434.24 359 359 434.24 265 438.777V384h-18v54.777C153 434.24 77.76 359 73.223 265H128v-18H73.223C77.76 153 153 77.76 247 73.223zM247 224v23h-23v18h23v23h18v-23h23v-18h-23v-23h-18z"),
                    fill = SolidColor(Color.White)
                )
            }.build()
            else -> getCrosshair(0)
        }
    }
}

class GameCrosshairService : Service() {
    private var windowManager: WindowManager? = null
    private var crosshairView: ComposeView? = null
    private var lifecycleOwner: MyLifecycleOwner? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        lifecycleOwner = MyLifecycleOwner().apply {
            performRestore(null)
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        }

        crosshairView = ComposeView(this).apply {
            setContent {
                com.kanagawa.yamada.project.raco.ScaleTabletUI {
                    val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                    var size by remember { mutableStateOf(prefs.getFloat("crosshair_size", 50f)) }
                    var opacity by remember { mutableStateOf(prefs.getFloat("crosshair_opacity", 1f)) }
                    var selectedStyle by remember { mutableStateOf(prefs.getInt("crosshair_style", 0)) }
                    var selectedColorIndex by remember { mutableStateOf(prefs.getInt("crosshair_color_index", 0)) }

                    DisposableEffect(Unit) {
                        val listener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
                            if (key == "crosshair_size") size = sharedPreferences.getFloat(key, 50f)
                            if (key == "crosshair_opacity") opacity = sharedPreferences.getFloat(key, 1f)
                            if (key == "crosshair_style") selectedStyle = sharedPreferences.getInt(key, 0)
                            if (key == "crosshair_color_index") selectedColorIndex = sharedPreferences.getInt(key, 0)
                        }
                        prefs.registerOnSharedPreferenceChangeListener(listener)
                        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
                    }

                    val colorOptions = listOf(Color.White, Color.Red, Color.Green, Color.Blue, Color.Yellow)
                    val activeColor = colorOptions.getOrElse(selectedColorIndex) { Color.White }

                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = CrosshairData.getCrosshair(selectedStyle),
                            contentDescription = "Crosshair",
                            tint = activeColor.copy(alpha = opacity),
                            modifier = Modifier.size(size.dp)
                        )
                    }
                }
            }
        }

        crosshairView?.setViewTreeLifecycleOwner(lifecycleOwner)
        crosshairView?.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        val viewModelStore = ViewModelStore()
        crosshairView?.setViewTreeViewModelStoreOwner(object : ViewModelStoreOwner {
            override val viewModelStore: ViewModelStore get() = viewModelStore
        })

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        params.gravity = android.view.Gravity.CENTER

        windowManager?.addView(crosshairView, params)
        
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        crosshairView?.let { windowManager?.removeView(it) }
    }
}
