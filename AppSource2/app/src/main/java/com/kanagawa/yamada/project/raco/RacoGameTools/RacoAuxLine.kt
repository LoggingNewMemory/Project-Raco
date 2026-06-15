package com.kanagawa.yamada.project.raco.RacoGameTools

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.WindowManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.kanagawa.yamada.project.raco.MyLifecycleOwner

class GameAuxLineService : Service() {
    private var windowManager: WindowManager? = null
    private var auxLineView: ComposeView? = null
    private var lifecycleOwner: MyLifecycleOwner? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        lifecycleOwner = MyLifecycleOwner().apply {
            performRestore(null)
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        }

        auxLineView = ComposeView(this).apply {
            setContent {
                val prefs = getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
                var preset by remember { mutableStateOf(prefs.getInt("auxline_preset", 0)) }
                var width by remember { mutableStateOf(prefs.getFloat("auxline_${preset}_width", 200f)) }
                var height by remember { mutableStateOf(prefs.getFloat("auxline_${preset}_height", 200f)) }
                var opacity by remember { mutableStateOf(prefs.getFloat("auxline_${preset}_opacity", 1f)) }
                var colorIndex by remember { mutableStateOf(prefs.getInt("auxline_${preset}_color", 0)) }

                DisposableEffect(Unit) {
                    val listener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
                        if (key != null && (key == "auxline_preset" || key.startsWith("auxline_"))) {
                            val p = sharedPreferences.getInt("auxline_preset", 0)
                            preset = p
                            width = sharedPreferences.getFloat("auxline_${p}_width", 200f)
                            height = sharedPreferences.getFloat("auxline_${p}_height", 200f)
                            opacity = sharedPreferences.getFloat("auxline_${p}_opacity", 1f)
                            colorIndex = sharedPreferences.getInt("auxline_${p}_color", 0)
                        }
                    }
                    prefs.registerOnSharedPreferenceChangeListener(listener)
                    onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
                }

                val colorOptions = listOf(Color.White, Color.Red, Color.Green, Color.Blue)
                val activeColor = colorOptions.getOrElse(colorIndex) { Color.White }

                Box(contentAlignment = Alignment.Center) {
                    Canvas(modifier = Modifier.size(width.dp, height.dp)) {
                        drawOval(
                            color = activeColor.copy(alpha = opacity),
                            style = Stroke(width = 3f.dp.toPx())
                        )
                    }
                }
            }
        }

        auxLineView?.setViewTreeLifecycleOwner(lifecycleOwner)
        auxLineView?.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        val viewModelStore = ViewModelStore()
        auxLineView?.setViewTreeViewModelStoreOwner(object : ViewModelStoreOwner {
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

        windowManager?.addView(auxLineView, params)
        
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleOwner?.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        auxLineView?.let { windowManager?.removeView(it) }
    }
}

@Composable
fun AuxLineMenu(themeColor: Color, onClose: () -> Unit) {
    val context = LocalContext.current
    val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)

    var currentPreset by remember { mutableStateOf(prefs.getInt("auxline_preset", 0)) }
    
    var width by remember(currentPreset) { mutableStateOf(prefs.getFloat("auxline_${currentPreset}_width", 200f)) }
    var height by remember(currentPreset) { mutableStateOf(prefs.getFloat("auxline_${currentPreset}_height", 200f)) }
    var opacity by remember(currentPreset) { mutableStateOf(prefs.getFloat("auxline_${currentPreset}_opacity", 1f)) }
    var selectedColorIndex by remember(currentPreset) { mutableStateOf(prefs.getInt("auxline_${currentPreset}_color", 0)) }

    fun updatePref(keySuffix: String, value: Any) {
        val editor = prefs.edit()
        val key = "auxline_${currentPreset}_$keySuffix"
        when (value) {
            is Float -> editor.putFloat(key, value)
            is Int -> editor.putInt(key, value)
        }
        editor.apply()
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = Color.White,
                modifier = Modifier.size(24.dp).clickable { onClose() }
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("AUX LINE", color = themeColor, fontSize = 18.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
        }
        Spacer(modifier = Modifier.height(8.dp))

        Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
            // Presets
            Text("PRESET", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
            Spacer(modifier = Modifier.height(4.dp))
            Row(modifier = Modifier.fillMaxWidth(0.7f), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in 0..2) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(28.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (currentPreset == i) themeColor.copy(alpha=0.3f) else Color.Transparent)
                            .border(1.dp, if (currentPreset == i) themeColor else Color.White.copy(alpha=0.2f), RoundedCornerShape(8.dp))
                            .clickable {
                                currentPreset = i
                                prefs.edit().putInt("auxline_preset", i).apply()
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text("P${i + 1}", color = if (currentPreset == i) themeColor else Color.White, fontSize = 12.sp)
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))

            Text("WIDTH", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
            Slider(
                value = width,
                onValueChange = { 
                    width = it
                    updatePref("width", it)
                },
                valueRange = 20f..800f,
                colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = themeColor),
                modifier = Modifier.fillMaxWidth(0.95f).height(32.dp).padding(end = 16.dp)
            )

            Text("HEIGHT", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
            Slider(
                value = height,
                onValueChange = { 
                    height = it
                    updatePref("height", it)
                },
                valueRange = 20f..800f,
                colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = themeColor),
                modifier = Modifier.fillMaxWidth(0.95f).height(32.dp).padding(end = 16.dp)
            )



            Text("OPACITY", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
            Slider(
                value = opacity,
                onValueChange = { 
                    opacity = it
                    updatePref("opacity", it)
                },
                valueRange = 0.1f..1f,
                colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = themeColor),
                modifier = Modifier.fillMaxWidth(0.95f).height(32.dp).padding(end = 16.dp)
            )
            
            Spacer(modifier = Modifier.height(4.dp))
            Text("COLOR", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Light)
            Spacer(modifier = Modifier.height(4.dp))
            val colorOptions = listOf(Color.White, Color.Red, Color.Green, Color.Blue)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                colorOptions.forEachIndexed { index, color ->
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(RoundedCornerShape(13.dp))
                            .background(color)
                            .border(
                                2.dp, 
                                if (selectedColorIndex == index) themeColor else Color.Transparent, 
                                RoundedCornerShape(13.dp)
                            )
                            .clickable {
                                selectedColorIndex = index
                                updatePref("color", index)
                            }
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            Box(
                modifier = Modifier
                    .width(134.dp)
                    .height(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.White.copy(alpha=0.1f))
                    .border(1.dp, Color.White.copy(alpha=0.2f), RoundedCornerShape(8.dp))
                    .clickable {
                        width = 200f
                        height = 200f
                        opacity = 1f
                        selectedColorIndex = 0
                        
                        updatePref("width", 200f)
                        updatePref("height", 200f)
                        updatePref("opacity", 1f)
                        updatePref("color", 0)
                    },
                contentAlignment = Alignment.Center
            ) {
                Text("RESET", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
