package com.kanagawa.yamada.project.raco

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.*
import androidx.savedstate.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import androidx.compose.animation.core.*
import androidx.compose.animation.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.foundation.Image
import android.view.MotionEvent
import com.kanagawa.yamada.project.raco.GameTools.*

class RacoGameAssistant(private val context: Context) : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var composeView: ComposeView? = null
    private var crosshairView: ComposeView? = null
    private var infoView: ComposeView? = null
    val selectedModeState = mutableStateOf("Awaken")
    val isExecutingState = mutableStateOf(false)
    val executingModeState = mutableStateOf("")
    val isCrosshairActiveState = mutableStateOf(false)
    
    private val sharedPrefs = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
    val crosshairTypeState = mutableStateOf(sharedPrefs.getInt("crosshair_type", 1))
    val crosshairSizeState = mutableStateOf(sharedPrefs.getFloat("crosshair_size", 32f))
    val crosshairOpacityState = mutableStateOf(sharedPrefs.getFloat("crosshair_opacity", 1f))
    val crosshairColorState = mutableStateOf(sharedPrefs.getString("crosshair_color", "White") ?: "White")
    val showCrosshairConfigState = mutableStateOf(false)
    val showAyundaConfigState = mutableStateOf(false)
    val activeAyundaPresetState = mutableStateOf("")
    val activeDndState = mutableStateOf(false)
    val isInfoActiveState = mutableStateOf(false)
    
    private var cachedGameIconMaxX = 0
    private var cachedGameIconMaxY = 0

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val store = ViewModelStore()
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = store
    override val savedStateRegistry: SavedStateRegistry get() = savedStateRegistryController.savedStateRegistry

    private var isExpanded by mutableStateOf(false)
    private var buttonX = sharedPrefs.getInt("overlay_x", 0)
    private var buttonY = sharedPrefs.getInt("overlay_y", 300)

    init {
        val metrics = android.util.DisplayMetrics()
        windowManager.defaultDisplay.getRealMetrics(metrics)
        val buttonSizePx = (52 * metrics.density).toInt()
        buttonX = buttonX.coerceIn(0, Math.max(0, metrics.widthPixels - buttonSizePx))
        buttonY = buttonY.coerceIn(0, Math.max(0, metrics.heightPixels - buttonSizePx))
    }

    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = buttonX
        y = buttonY
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }

    init {
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    val currentPackageState = mutableStateOf("")

    fun show(packageName: String) {
        currentPackageState.value = packageName
        selectedModeState.value = sharedPrefs.getString("raco_game_mode_$packageName", "Awaken") ?: "Awaken"
        crosshairTypeState.value = sharedPrefs.getInt("crosshair_type_$packageName", sharedPrefs.getInt("crosshair_type", 1))
        crosshairSizeState.value = sharedPrefs.getFloat("crosshair_size_$packageName", sharedPrefs.getFloat("crosshair_size", 32f))
        crosshairOpacityState.value = sharedPrefs.getFloat("crosshair_opacity_$packageName", sharedPrefs.getFloat("crosshair_opacity", 1f))
        crosshairColorState.value = sharedPrefs.getString("crosshair_color_$packageName", sharedPrefs.getString("crosshair_color", "White")) ?: "White"

        val savedAyundaPreset = sharedPrefs.getString("active_ayunda_preset_$packageName", "") ?: ""
        activeAyundaPresetState.value = savedAyundaPreset
        if (savedAyundaPreset.isNotEmpty()) {
            val r = sharedPrefs.getFloat("RGB_R_$packageName", 1f)
            val g = sharedPrefs.getFloat("RGB_G_$packageName", 1f)
            val b = sharedPrefs.getFloat("RGB_B_$packageName", 1f)
            val s = sharedPrefs.getFloat("RGB_S_$packageName", 1f)
            Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f $s"))
        }

        val savedDndActive = sharedPrefs.getBoolean("dnd_active_$packageName", false)
        activeDndState.value = savedDndActive
        if (savedDndActive) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd notification set_dnd priority"))
        }

        val savedCrosshairActive = sharedPrefs.getBoolean("crosshair_active_$packageName", false)
        if (savedCrosshairActive) {
            if (crosshairView == null) toggleCrosshair(true)
        } else {
            if (crosshairView != null) toggleCrosshair(false)
        }

        val savedInfoActive = sharedPrefs.getBoolean("info_active_$packageName", false)
        if (savedInfoActive) {
            if (infoView == null) toggleInfo(true)
        } else {
            if (infoView != null) toggleInfo(false)
        }

        if (composeView != null) return

        composeView = ComposeView(context).apply {
            setViewTreeLifecycleOwner(this@RacoGameAssistant)
            setViewTreeViewModelStoreOwner(this@RacoGameAssistant)
            setViewTreeSavedStateRegistryOwner(this@RacoGameAssistant)
            
            setContent {
                MaterialTheme(colorScheme = darkColorScheme()) {
                    GameSpaceContent(
                        currentPackage = currentPackageState.value,
                        isExpanded = isExpanded,
                        onExpand = {
                            isExpanded = true
                            updateOverlayLayoutParams()
                        },
                        onCollapse = {
                            isExpanded = false
                            updateOverlayLayoutParams()
                        },
                        onDragStart = {
                            val metrics = android.util.DisplayMetrics()
                            windowManager.defaultDisplay.getRealMetrics(metrics)
                            val buttonSizePx = (52 * metrics.density).toInt()
                            cachedGameIconMaxX = Math.max(0, metrics.widthPixels - buttonSizePx)
                            cachedGameIconMaxY = Math.max(0, metrics.heightPixels - buttonSizePx)
                        },
                        onDrag = { dx, dy ->
                            buttonX += dx.toInt()
                            buttonY += dy.toInt()
                            
                            buttonX = buttonX.coerceIn(0, cachedGameIconMaxX)
                            buttonY = buttonY.coerceIn(0, cachedGameIconMaxY)

                            params.x = buttonX
                            params.y = buttonY
                            windowManager.updateViewLayout(this, params)
                            sharedPrefs.edit().putInt("overlay_x", buttonX).putInt("overlay_y", buttonY).apply()
                        },
                        context = context,
                        selectedModeState = selectedModeState,
                        isExecutingState = isExecutingState,
                        executingModeState = executingModeState,
                        isCrosshairActiveState = isCrosshairActiveState,
                        onToggleCrosshair = { toggleCrosshair() },
                        crosshairTypeState = crosshairTypeState,
                        crosshairSizeState = crosshairSizeState,
                        crosshairOpacityState = crosshairOpacityState,
                        crosshairColorState = crosshairColorState,
                        showCrosshairConfigState = showCrosshairConfigState,
                        showAyundaConfigState = showAyundaConfigState,
                        activeAyundaPresetState = activeAyundaPresetState,
                        activeDndState = activeDndState,
                        isInfoActiveState = isInfoActiveState,
                        onToggleInfo = { toggleInfo() },
                        sharedPrefs = sharedPrefs
                    )
                }
            }
        }
        
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        windowManager.addView(composeView, params)
    }

    fun hide() {
        if (crosshairView != null) {
            windowManager.removeView(crosshairView)
            crosshairView = null
            isCrosshairActiveState.value = false
        }
        if (infoView != null) {
            windowManager.removeView(infoView)
            infoView = null
            isInfoActiveState.value = false
        }
        composeView?.let {
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
            windowManager.removeView(it)
            composeView = null
        }
        
        val pkg = currentPackageState.value
        val savedAyundaPreset = sharedPrefs.getString("active_ayunda_preset_$pkg", "") ?: ""
        if (savedAyundaPreset.isNotEmpty()) {
            val globalPreset = sharedPrefs.getString("active_ayunda_preset", "") ?: ""
            if (globalPreset.isNotEmpty()) {
                val r = sharedPrefs.getFloat("RGB_R", 1f)
                val g = sharedPrefs.getFloat("RGB_G", 1f)
                val b = sharedPrefs.getFloat("RGB_B", 1f)
                val s = sharedPrefs.getFloat("RGB_S", 1f)
                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f $s"))
            } else {
                Runtime.getRuntime().exec(arrayOf("su", "-c", "service call SurfaceFlinger 1015 i32 1 f 1.0 f 0 f 0 f 0 f 0 f 1.0 f 0 f 0 f 0 f 0 f 1.0 f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f 1.0"))
            }
        }
        
        if (activeDndState.value) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd notification set_dnd off"))
        }
        
        isExpanded = false
    }

    private fun toggleCrosshair(forceState: Boolean? = null) {
        Handler(Looper.getMainLooper()).post {
            val pkg = currentPackageState.value
            val targetState = forceState ?: (crosshairView == null)
            if (!targetState && crosshairView != null) {
                windowManager.removeView(crosshairView)
                crosshairView = null
                isCrosshairActiveState.value = false
                if (pkg.isNotEmpty()) sharedPrefs.edit().putBoolean("crosshair_active_$pkg", false).apply()
            } else if (targetState && crosshairView == null) {
                isCrosshairActiveState.value = true
                if (pkg.isNotEmpty()) sharedPrefs.edit().putBoolean("crosshair_active_$pkg", true).apply()
                val metrics = android.util.DisplayMetrics()
                windowManager.defaultDisplay.getRealMetrics(metrics)

                val crosshairParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                }

                crosshairView = ComposeView(context).apply {
                    setViewTreeLifecycleOwner(this@RacoGameAssistant)
                    setViewTreeViewModelStoreOwner(this@RacoGameAssistant)
                    setViewTreeSavedStateRegistryOwner(this@RacoGameAssistant)
                    
                    setContent {
                        val size by crosshairSizeState
                        val opacity by crosshairOpacityState
                        val type by crosshairTypeState
                        val colorStr by crosshairColorState
                        
                        val actualColor = when(colorStr) {
                            "Red" -> Color.Red
                            "Blue" -> Color.Blue
                            "Green" -> Color.Green
                            else -> Color.White
                        }
                        
                        val drawableRes = when(type) {
                            2 -> R.drawable.ic_crosshair_2
                            3 -> R.drawable.ic_crosshair_3
                            4 -> R.drawable.ic_crosshair_4
                            else -> R.drawable.ic_crosshair_1
                        }
                        
                        Image(
                            painter = androidx.compose.ui.res.painterResource(id = drawableRes),
                            contentDescription = "Crosshair",
                            colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(actualColor),
                            modifier = Modifier
                                .size(size.dp)
                                .alpha(opacity)
                        )
                    }
                }
                windowManager.addView(crosshairView, crosshairParams)
            }
        }
    }

    private fun toggleInfo(forceState: Boolean? = null) {
        Handler(Looper.getMainLooper()).post {
            val pkg = currentPackageState.value
            val targetState = forceState ?: (infoView == null)
            if (!targetState && infoView != null) {
                windowManager.removeView(infoView)
                infoView = null
                isInfoActiveState.value = false
                if (pkg.isNotEmpty()) sharedPrefs.edit().putBoolean("info_active_$pkg", false).apply()
            } else if (targetState && infoView == null) {
                isInfoActiveState.value = true
                if (pkg.isNotEmpty()) sharedPrefs.edit().putBoolean("info_active_$pkg", true).apply()
                
                val infoParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.START
                    val savedX = sharedPrefs.getInt("info_x", -1)
                    val savedY = sharedPrefs.getInt("info_y", -1)
                    if (savedX != -1 && savedY != -1) {
                        x = savedX
                        y = savedY
                    } else {
                        val metrics = context.resources.displayMetrics
                        x = metrics.widthPixels / 2 - 200
                        y = 80
                    }
                }

                infoView = ComposeView(context).apply {
                    setViewTreeLifecycleOwner(this@RacoGameAssistant)
                    setViewTreeViewModelStoreOwner(this@RacoGameAssistant)
                    setViewTreeSavedStateRegistryOwner(this@RacoGameAssistant)
                    
                    var initialX = 0
                    var initialY = 0
                    var initialTouchX = 0f
                    var initialTouchY = 0f
                    var isDragging = false

                    var maxX = 0
                    var maxY = 0

                    setOnTouchListener { view, event ->
                        when (event.action) {
                            MotionEvent.ACTION_DOWN -> {
                                initialX = infoParams.x
                                initialY = infoParams.y
                                initialTouchX = event.rawX
                                initialTouchY = event.rawY
                                isDragging = false
                                
                                val metrics = android.util.DisplayMetrics()
                                windowManager.defaultDisplay.getRealMetrics(metrics)
                                maxX = Math.max(0, metrics.widthPixels - view.width)
                                maxY = Math.max(0, metrics.heightPixels - view.height)
                                
                                true
                            }
                            MotionEvent.ACTION_MOVE -> {
                                val dx = event.rawX - initialTouchX
                                val dy = event.rawY - initialTouchY
                                if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                                    isDragging = true
                                }
                                if (isDragging) {
                                    val newX = initialX + dx.toInt()
                                    val newY = initialY + dy.toInt()
                                    infoParams.x = newX.coerceIn(0, maxX)
                                    infoParams.y = newY.coerceIn(0, maxY)
                                    windowManager.updateViewLayout(view, infoParams)
                                }
                                true
                            }
                            MotionEvent.ACTION_UP -> {
                                if (isDragging) {
                                    sharedPrefs.edit().putInt("info_x", infoParams.x).putInt("info_y", infoParams.y).apply()
                                }
                                true
                            }
                            else -> false
                        }
                    }
                    
                    setContent {
                        InfoOverlayView(context, pkg)
                    }
                }
                windowManager.addView(infoView, infoParams)
            }
        }
    }
    
    fun updateOverlayLayoutParams() {
        if (isExpanded) {
            params.width = WindowManager.LayoutParams.MATCH_PARENT
            params.height = WindowManager.LayoutParams.MATCH_PARENT
            params.x = 0
            params.y = 0
        } else {
            params.width = WindowManager.LayoutParams.WRAP_CONTENT
            params.height = WindowManager.LayoutParams.WRAP_CONTENT
            params.x = buttonX
            params.y = buttonY
        }
        composeView?.let { windowManager.updateViewLayout(it, params) }
    }
}

@Composable
fun GameSpaceContent(
    currentPackage: String,
    isExpanded: Boolean,
    onExpand: () -> Unit,
    onCollapse: () -> Unit,
    onDragStart: () -> Unit = {},
    onDrag: (Float, Float) -> Unit,
    context: Context,
    selectedModeState: MutableState<String>,
    isExecutingState: MutableState<Boolean>,
    executingModeState: MutableState<String>,
    isCrosshairActiveState: MutableState<Boolean>,
    onToggleCrosshair: () -> Unit,
    crosshairTypeState: MutableState<Int>,
    crosshairSizeState: MutableState<Float>,
    crosshairOpacityState: MutableState<Float>,
    crosshairColorState: MutableState<String>,
    showCrosshairConfigState: MutableState<Boolean>,
    showAyundaConfigState: MutableState<Boolean>,
    activeAyundaPresetState: MutableState<String>,
    activeDndState: MutableState<Boolean>,
    isInfoActiveState: MutableState<Boolean>,
    onToggleInfo: () -> Unit,
    sharedPrefs: android.content.SharedPreferences
) {
    val themeColor by androidx.compose.animation.animateColorAsState(
        when (selectedModeState.value) {
            "Powersave" -> Color(0xFF4CAF50)
            "Balanced" -> Color(0xFF2196F3)
            "Awaken" -> Color(0xFFFF5722)
            else -> Color(0xFFFF5722)
        }
    )

    if (!isExpanded) {
        var lastInteraction by remember { mutableStateOf(System.currentTimeMillis()) }
        var isIdle by remember { mutableStateOf(false) }

        LaunchedEffect(lastInteraction) {
            isIdle = false
            delay(3000)
            isIdle = true
        }

        val alpha by androidx.compose.animation.core.animateFloatAsState(if (isIdle) 0.4f else 1.0f)

        Box(
            modifier = Modifier
                .size(52.dp)
                .alpha(alpha)
                .background(Color.Transparent)
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { 
                            lastInteraction = System.currentTimeMillis()
                            onDragStart()
                        },
                        onDragEnd = { lastInteraction = System.currentTimeMillis() }
                    ) { change, dragAmount ->
                        change.consume()
                        onDrag(dragAmount.x, dragAmount.y)
                        lastInteraction = System.currentTimeMillis()
                    }
                }
                .padding(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.15f))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), CircleShape)
                    .clickable { 
                        lastInteraction = System.currentTimeMillis()
                        onExpand() 
                    },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.SportsEsports,
                    contentDescription = "Game Space",
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }
        }
    } else {
        GameSpaceDashboard(
            currentPackage = currentPackage,
            onCollapse = onCollapse, 
            context = context, 
            selectedModeState = selectedModeState, 
            isExecutingState = isExecutingState, 
            executingModeState = executingModeState, 
            themeColor = themeColor, 
            isCrosshairActiveState = isCrosshairActiveState, 
            onToggleCrosshair = onToggleCrosshair,
            crosshairTypeState = crosshairTypeState,
            crosshairSizeState = crosshairSizeState,
            crosshairOpacityState = crosshairOpacityState,
            crosshairColorState = crosshairColorState,
            showCrosshairConfigState = showCrosshairConfigState,
            showAyundaConfigState = showAyundaConfigState,
            activeAyundaPresetState = activeAyundaPresetState,
            activeDndState = activeDndState,
            isInfoActiveState = isInfoActiveState,
            onToggleInfo = onToggleInfo,
            sharedPrefs = sharedPrefs
        )
    }
}

@Composable
fun GameSpaceDashboard(
    currentPackage: String,
    onCollapse: () -> Unit, 
    context: Context, 
    selectedModeState: MutableState<String>, 
    isExecutingState: MutableState<Boolean>, 
    executingModeState: MutableState<String>, 
    themeColor: Color, 
    isCrosshairActiveState: MutableState<Boolean>, 
    onToggleCrosshair: () -> Unit,
    crosshairTypeState: MutableState<Int>,
    crosshairSizeState: MutableState<Float>,
    crosshairOpacityState: MutableState<Float>,
    crosshairColorState: MutableState<String>,
    showCrosshairConfigState: MutableState<Boolean>,
    showAyundaConfigState: MutableState<Boolean>,
    activeAyundaPresetState: MutableState<String>,
    activeDndState: MutableState<Boolean>,
    isInfoActiveState: MutableState<Boolean>,
    onToggleInfo: () -> Unit,
    sharedPrefs: android.content.SharedPreferences
) {
    var selectedTab by remember { mutableStateOf("Performance") }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Transparent)
            .clickable(onClick = onCollapse) // Click outside to collapse
    ) {
        Row(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .padding(start = 16.dp)
                .width(360.dp)
                .height(300.dp)
                .clickable(enabled = false) {} // Prevent click-through
        ) {
            // Sidebar
            Column(
                modifier = Modifier
                    .width(70.dp)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(topStart = 20.dp, bottomStart = 20.dp))
                    .background(Color(0xFF1E1E1E).copy(alpha = 0.95f))
                    .padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(32.dp)
            ) {
                SidebarItem(
                    icon = Icons.Default.Speed,
                    label = "Performance",
                    isSelected = selectedTab == "Performance" && !showCrosshairConfigState.value && !showAyundaConfigState.value,
                    themeColor = themeColor,
                    onClick = { 
                        selectedTab = "Performance"
                        showCrosshairConfigState.value = false
                        showAyundaConfigState.value = false
                    }
                )
                SidebarItem(
                    icon = Icons.Default.Widgets,
                    label = "Tools",
                    isSelected = selectedTab == "Tools" || showCrosshairConfigState.value || showAyundaConfigState.value,
                    themeColor = themeColor,
                    onClick = { 
                        selectedTab = "Tools"
                        showCrosshairConfigState.value = false
                        showAyundaConfigState.value = false
                    }
                )
            }
            
            // Content Area
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(topEnd = 20.dp, bottomEnd = 20.dp))
                    .background(Color(0xFF121212).copy(alpha = 0.95f))
                    .padding(12.dp)
            ) {
                AnimatedContent(
                    targetState = when {
                        showCrosshairConfigState.value -> 2
                        showAyundaConfigState.value -> 3
                        selectedTab == "Performance" -> 0
                        else -> 1
                    },
                    transitionSpec = {
                        fadeIn().togetherWith(fadeOut()).using(
                            SizeTransform(clip = false)
                        )
                    },
                    label = "tabAnimation"
                ) { targetState ->
                    when (targetState) {
                        2 -> {
                            CrosshairConfigView(
                                currentPackage = currentPackage,
                                onDismissRequest = { showCrosshairConfigState.value = false },
                                crosshairTypeState = crosshairTypeState,
                                crosshairSizeState = crosshairSizeState,
                                crosshairOpacityState = crosshairOpacityState,
                                crosshairColorState = crosshairColorState,
                                themeColor = themeColor,
                                sharedPrefs = sharedPrefs
                            )
                        }
                        0 -> {
                            PerformanceTab(context, currentPackage, selectedModeState, isExecutingState, executingModeState, themeColor, sharedPrefs)
                        }
                        1 -> {
                            ToolsTab(
                                context = context,
                                currentPackage = currentPackage,
                                isCrosshairActiveState = isCrosshairActiveState, 
                                onToggleCrosshair = onToggleCrosshair, 
                                themeColor = themeColor,
                                showCrosshairConfigState = showCrosshairConfigState,
                                showAyundaConfigState = showAyundaConfigState,
                                activeAyundaPresetState = activeAyundaPresetState,
                                activeDndState = activeDndState,
                                isInfoActiveState = isInfoActiveState,
                                onToggleInfo = onToggleInfo,
                                sharedPrefs = sharedPrefs,
                                onCollapse = onCollapse
                            )
                        }
                        3 -> {
                            AyundaConfigView(
                                currentPackage = currentPackage,
                                onDismissRequest = { showAyundaConfigState.value = false },
                                themeColor = themeColor,
                                sharedPrefs = sharedPrefs,
                                activeAyundaPresetState = activeAyundaPresetState
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SidebarItem(icon: ImageVector, label: String, isSelected: Boolean, themeColor: Color, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable(onClick = onClick)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = if (isSelected) themeColor else Color.Gray,
            modifier = Modifier.size(28.dp)
        )
    }
}

@Composable
fun PerformanceTab(context: Context, currentPackage: String, selectedModeState: MutableState<String>, isExecutingState: MutableState<Boolean>, executingModeState: MutableState<String>, themeColor: Color, sharedPrefs: android.content.SharedPreferences) {
    var batteryLevel by remember { mutableStateOf("--") }
    var cpuUsage by remember { mutableStateOf("--") }
    var maxCpuFreq by remember { mutableStateOf(1000L) }

    DisposableEffect(context) {
        val receiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                    val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                    if (level >= 0 && scale > 0) {
                        batteryLevel = ((level * 100) / scale).toString()
                    }
                }
            }
        }
        val initialIntent = context.registerReceiver(receiver, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        if (initialIntent != null) {
            val level = initialIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = initialIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            if (level >= 0 && scale > 0) {
                batteryLevel = ((level * 100) / scale).toString()
            }
        }
        onDispose {
            context.unregisterReceiver(receiver)
        }
    }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            while (isActive) {
                try {
                    val cpufreqDir = java.io.File("/sys/devices/system/cpu/cpufreq")
                    val highestPolicy = cpufreqDir.listFiles { file -> 
                        file.isDirectory && file.name.startsWith("policy") 
                    }?.maxByOrNull { it.name.removePrefix("policy").toIntOrNull() ?: -1 }
                    
                    if (highestPolicy != null) {
                        val maxFreqFile = java.io.File(highestPolicy, "cpuinfo_max_freq")
                        if (maxFreqFile.exists()) {
                            try {
                                maxCpuFreq = maxFreqFile.readText().trim().toLong() / 1000
                            } catch(e: Exception){}
                        }

                        val freqFile = java.io.File(highestPolicy, "scaling_cur_freq")
                        if (freqFile.exists()) {
                            val freqStr = freqFile.readText().trim()
                            if (freqStr.isNotBlank()) {
                                try {
                                    val freqMhz = freqStr.toLong() / 1000
                                    cpuUsage = freqMhz.toString()
                                } catch(e: Exception){}
                            }
                        }
                    }
                } catch(e: Exception){}
                
                delay(1000)
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Raco Game Assistant",
            color = Color.Gray,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.align(Alignment.CenterHorizontally)
        )
        Spacer(modifier = Modifier.height(16.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            val cpuProg = (cpuUsage.toLongOrNull() ?: 0L).toFloat() / maxCpuFreq.toFloat().coerceAtLeast(1f)
            StatCircle(title = "CPU", value = cpuUsage, unit = "MHz", progress = cpuProg, highlight = true, themeColor = themeColor)
            val batProg = (batteryLevel.toIntOrNull() ?: 0).toFloat() / 100f
            StatCircle(title = "Battery", value = batteryLevel, unit = "%", progress = batProg, highlight = false, themeColor = themeColor)
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Mode Selector
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(Color(0xFF222222))
                .padding(4.dp)
        ) {
            val modes = listOf(
                Triple("Powersave", "2", Color(0xFF4CAF50)),
                Triple("Balanced", "1", Color(0xFF2196F3)),
                Triple("Awaken", "4", Color(0xFFFF5722))
            )
            
            val oldIndex = modes.indexOfFirst { it.first == selectedModeState.value }.coerceAtLeast(0)
            val newIndex = if (isExecutingState.value) {
                modes.indexOfFirst { it.first == executingModeState.value }.coerceAtLeast(0)
            } else {
                oldIndex
            }

            val leftIndex = minOf(oldIndex, newIndex)
            val rightIndex = maxOf(oldIndex, newIndex)

            val blockWidth = maxWidth / modes.size
            val targetOffset = blockWidth * leftIndex
            val targetWidth = blockWidth * (rightIndex - leftIndex + 1)

            val animatedOffset by animateDpAsState(
                targetValue = targetOffset,
                animationSpec = tween(400, easing = FastOutSlowInEasing),
                label = "sliderOffset"
            )
            val animatedWidth by animateDpAsState(
                targetValue = targetWidth,
                animationSpec = tween(400, easing = FastOutSlowInEasing),
                label = "sliderWidth"
            )

            val currentBrush = Brush.horizontalGradient(
                colors = listOf(modes[leftIndex].third, modes[rightIndex].third)
            )

            // The sliding block background
            Box(
                modifier = Modifier
                    .offset(x = animatedOffset)
                    .width(animatedWidth)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(18.dp))
                    .background(currentBrush),
                contentAlignment = Alignment.Center
            ) {
                androidx.compose.animation.AnimatedVisibility(
                    visible = isExecutingState.value,
                    enter = androidx.compose.animation.fadeIn(tween(300)),
                    exit = androidx.compose.animation.fadeOut(tween(300))
                ) {
                    Text(
                        text = "Switching Profiles...",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // The texts on top
            Row(
                modifier = Modifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                modes.forEachIndexed { index, (modeLabel, cmdMode, _) ->
                    val isHidden = isExecutingState.value && index in leftIndex..rightIndex
                    val textAlpha by animateFloatAsState(if (isHidden) 0f else 1f, animationSpec = tween(300), label = "textAlpha")
                    val isSelected = !isExecutingState.value && selectedModeState.value == modeLabel
                    val textColor by androidx.compose.animation.animateColorAsState(if (isSelected) Color.White else Color.LightGray)

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .clickable(enabled = !isExecutingState.value) { 
                                if (selectedModeState.value == modeLabel) return@clickable
                                executingModeState.value = modeLabel
                                isExecutingState.value = true
                                kotlinx.coroutines.CoroutineScope(Dispatchers.IO).launch {
                                    try {
                                        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco $cmdMode"))
                                        val reader = process.inputStream.bufferedReader()
                                        while (isActive) {
                                            val line = reader.readLine() ?: break
                                            if (line.contains("PROGRESS: 100")) {
                                                break
                                            }
                                        }
                                        process.waitFor()
                                    } catch(e: Exception){}
                                    finally {
                                        withContext(Dispatchers.Main) {
                                            selectedModeState.value = modeLabel
                                            executingModeState.value = ""
                                            isExecutingState.value = false
                                            if (currentPackage.isNotEmpty()) {
                                                sharedPrefs.edit().putString("raco_game_mode_$currentPackage", modeLabel).apply()
                                            }
                                        }
                                    }
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = modeLabel,
                            color = textColor.copy(alpha = textAlpha),
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal
                        )
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Touch response",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 14.sp
        )
        Text(
            text = "May increase the device's power consumption and temperature.",
            color = Color.Gray,
            fontSize = 10.sp
        )
        Spacer(modifier = Modifier.height(8.dp))
        var isUltraTouch by remember { mutableStateOf(sharedPrefs.getBoolean("ultra_touch_$currentPackage", false)) }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .border(if (!isUltraTouch) 1.dp else 0.dp, if (!isUltraTouch) themeColor else Color.Transparent, RoundedCornerShape(12.dp))
                    .background(if (!isUltraTouch) Color(0xFF1E1E1E) else Color(0xFF2A2A2A))
                    .clickable { 
                        if (!isUltraTouch) return@clickable
                        isUltraTouch = false
                        if (currentPackage.isNotEmpty()) sharedPrefs.edit().putBoolean("ultra_touch_$currentPackage", false).apply()
                        kotlinx.coroutines.CoroutineScope(Dispatchers.IO).launch {
                            try {
                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings delete system pointer_speed; resetprop --delete windowsmgr.max_events_per_sec")).waitFor()
                            } catch(e: Exception){}
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text("Standard", color = if (!isUltraTouch) themeColor else Color.Gray, fontSize = 12.sp)
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .border(if (isUltraTouch) 1.dp else 0.dp, if (isUltraTouch) themeColor else Color.Transparent, RoundedCornerShape(12.dp))
                    .background(if (isUltraTouch) Color(0xFF1E1E1E) else Color(0xFF2A2A2A))
                    .clickable { 
                        if (isUltraTouch) return@clickable
                        isUltraTouch = true
                        if (currentPackage.isNotEmpty()) sharedPrefs.edit().putBoolean("ultra_touch_$currentPackage", true).apply()
                        kotlinx.coroutines.CoroutineScope(Dispatchers.IO).launch {
                            try {
                                Runtime.getRuntime().exec(arrayOf("su", "-c", "settings put system pointer_speed 7; setprop windowsmgr.max_events_per_sec 300")).waitFor()
                            } catch(e: Exception){}
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Text("Enhanced", color = if (isUltraTouch) themeColor else Color.Gray, fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun StatCircle(title: String, value: String, unit: String, progress: Float, highlight: Boolean, themeColor: Color) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "progressAnim"
    )

    Box(
        modifier = Modifier.size(72.dp),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
            // Background track
            drawArc(
                color = Color(0xFF333333),
                startAngle = 135f,
                sweepAngle = 270f,
                useCenter = false,
                style = androidx.compose.ui.graphics.drawscope.Stroke(
                    width = 4.dp.toPx(),
                    cap = androidx.compose.ui.graphics.StrokeCap.Round
                )
            )
            // Foreground scaler
            if (animatedProgress > 0f) {
                drawArc(
                    color = if (highlight) themeColor else themeColor.copy(alpha = 0.8f),
                    startAngle = 135f,
                    sweepAngle = 270f * animatedProgress,
                    useCenter = false,
                    style = androidx.compose.ui.graphics.drawscope.Stroke(
                        width = 4.dp.toPx(),
                        cap = androidx.compose.ui.graphics.StrokeCap.Round
                    )
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, color = Color.Gray, fontSize = 8.sp)
            Text(value, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(unit, color = Color.Gray, fontSize = 8.sp)
        }
    }
}

data class ToolData(val title: String, val iconRes: Int?, val iconVector: ImageVector?, val action: suspend () -> String?, val onLongClick: (() -> Unit)? = null)

@Composable
fun ToolsTab(context: Context, currentPackage: String, isCrosshairActiveState: MutableState<Boolean>, onToggleCrosshair: () -> Unit, themeColor: Color, showCrosshairConfigState: MutableState<Boolean>, showAyundaConfigState: MutableState<Boolean>, activeAyundaPresetState: MutableState<String>, activeDndState: MutableState<Boolean>, isInfoActiveState: MutableState<Boolean>, onToggleInfo: () -> Unit, sharedPrefs: android.content.SharedPreferences, onCollapse: () -> Unit) {
    val coroutineScope = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        // Initialization if needed
    }

    val tools = listOf(
        ToolData("Crosshair", R.drawable.ic_crosshair_1, null, { onToggleCrosshair(); null }, onLongClick = { showCrosshairConfigState.value = true }),
        ToolData("Cleanup", null, Icons.Default.CleaningServices, { CleanupTool.execute() }),
        ToolData("Screenshot", null, Icons.Default.CameraAlt, { 
            ScreenshotTool.execute(context, onCollapse)
            null
        }),
        ToolData("Dnd", null, Icons.Default.DoNotDisturbOn, {
            DndTool.toggle(currentPackage, activeDndState, sharedPrefs)
            null
        }),
        ToolData("Ayunda", null, Icons.Default.Palette, {
            AyundaTool.toggle(currentPackage, activeAyundaPresetState, sharedPrefs)
            null
        }, onLongClick = { showAyundaConfigState.value = true }),
        ToolData("Device Info", null, Icons.Default.DeveloperBoard, { onToggleInfo(); null })
    )
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Game Tools",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        
        // Grid
        for (row in 0 until 2) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                for (col in 0 until 3) {
                    val index = row * 3 + col
                    if (index < tools.size) {
                        val tool = tools[index]
                        val isCrosshairActive = tool.title == "Crosshair" && isCrosshairActiveState.value
                        val isDndCurrentlyActive = tool.title.equals("Dnd", ignoreCase = true) && activeDndState.value
                        val isAyundaCurrentlyActive = tool.title == "Ayunda" && activeAyundaPresetState.value.isNotEmpty()
                        val isInfoCurrentlyActive = tool.title == "Device Info" && isInfoActiveState.value
                        ToolItem(
                            title = tool.title, 
                            iconRes = tool.iconRes, 
                            icon = tool.iconVector, 
                            modifier = Modifier.weight(1f),
                            isActive = isCrosshairActive || isDndCurrentlyActive || isAyundaCurrentlyActive || isInfoCurrentlyActive,
                            themeColor = themeColor,
                            onLongClick = tool.onLongClick,
                            onClick = tool.action
                        )
                    } else {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun ToolItem(title: String, iconRes: Int? = null, icon: ImageVector? = null, modifier: Modifier = Modifier, isActive: Boolean = false, themeColor: Color = Color.White, onLongClick: (() -> Unit)? = null, onClick: suspend () -> String?) {
    val coroutineScope = rememberCoroutineScope()
    var isProcessing by remember { mutableStateOf(false) }
    var showSuccess by remember { mutableStateOf(false) }
    var successMsg by remember { mutableStateOf("") }
    
    val infiniteTransition = rememberInfiniteTransition()
    val shimmerAnim by infiniteTransition.animateFloat(
        initialValue = -1000f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(3500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmer"
    )

    val contentAlpha by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (showSuccess) 0f else 1f,
        animationSpec = tween(400)
    )

    val successAlpha by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (showSuccess) 1f else 0f,
        animationSpec = tween(400)
    )

    val displayTitle = if ((isProcessing || showSuccess) && title == "Cleanup") {
        "Cleaning..."
    } else title

    val bgColor by androidx.compose.animation.animateColorAsState(
        targetValue = if (isActive) Color(0xFFE0E0E0) else Color(0xFF2A2A2A),
        animationSpec = tween(300),
        label = "bgColorAnim"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .then(
                if (isProcessing) Modifier.background(
                    Brush.linearGradient(
                        colors = listOf(Color(0xFF2A2A2A), Color(0xFF888888), Color(0xFF2A2A2A)),
                        start = Offset(shimmerAnim, shimmerAnim),
                        end = Offset(shimmerAnim + 400f, shimmerAnim + 400f)
                    )
                ) else Modifier.background(bgColor)
            )
            .combinedClickable(
                onClick = {
                    if (isProcessing) return@combinedClickable
                    coroutineScope.launch(Dispatchers.IO) {
                        try {
                            if (title == "Cleanup") {
                                isProcessing = true
                            }
                            val msg = onClick()
                            if (title == "Cleanup") {
                                isProcessing = false
                                if (msg != null) successMsg = msg
                                showSuccess = true
                                delay(1500)
                                showSuccess = false
                            }
                        } catch (e: Exception) {
                            isProcessing = false
                        }
                    }
                },
                onLongClick = onLongClick
            )
            .padding(vertical = 14.dp, horizontal = 4.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.alpha(contentAlpha)
            ) {
                val iconTint = if (isActive) Color.Black else Color.White
                if (iconRes != null) {
                    Icon(
                        painter = androidx.compose.ui.res.painterResource(id = iconRes),
                        contentDescription = title,
                        tint = iconTint,
                        modifier = Modifier.size(24.dp)
                    )
                } else if (icon != null) {
                    Icon(
                        imageVector = icon,
                        contentDescription = title,
                        tint = iconTint,
                        modifier = Modifier.size(24.dp)
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = displayTitle,
                    color = if (isActive) Color.Black else Color.LightGray,
                    fontSize = 10.sp,
                    maxLines = 1,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }

            Text(
                text = if (successMsg.isNotEmpty()) successMsg else { if (title == "Screenshot") "Captured!" else "Cleaned!" },
                color = Color.White,
                fontSize = 10.sp,
                maxLines = 2,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                modifier = Modifier.alpha(successAlpha)
            )
        }
    }
}


