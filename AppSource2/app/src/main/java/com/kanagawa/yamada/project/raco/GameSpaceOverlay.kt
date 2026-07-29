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

class GameSpaceOverlay(private val context: Context) : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var composeView: ComposeView? = null
    private var crosshairView: ComposeView? = null
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

        val savedCrosshairActive = sharedPrefs.getBoolean("crosshair_active_$packageName", false)
        if (savedCrosshairActive) {
            if (crosshairView == null) toggleCrosshair(true)
        } else {
            if (crosshairView != null) toggleCrosshair(false)
        }

        if (composeView != null) return

        composeView = ComposeView(context).apply {
            setViewTreeLifecycleOwner(this@GameSpaceOverlay)
            setViewTreeViewModelStoreOwner(this@GameSpaceOverlay)
            setViewTreeSavedStateRegistryOwner(this@GameSpaceOverlay)
            
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
                        onDrag = { dx, dy ->
                            buttonX += dx.toInt()
                            buttonY += dy.toInt()
                            
                            val metrics = android.util.DisplayMetrics()
                            windowManager.defaultDisplay.getRealMetrics(metrics)
                            val buttonSizePx = (52 * metrics.density).toInt()
                            buttonX = buttonX.coerceIn(0, Math.max(0, metrics.widthPixels - buttonSizePx))
                            buttonY = buttonY.coerceIn(0, Math.max(0, metrics.heightPixels - buttonSizePx))

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
        composeView?.let {
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
            windowManager.removeView(it)
            composeView = null
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
                val sizePx = (32 * metrics.density).toInt()

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
                    setViewTreeLifecycleOwner(this@GameSpaceOverlay)
                    setViewTreeViewModelStoreOwner(this@GameSpaceOverlay)
                    setViewTreeSavedStateRegistryOwner(this@GameSpaceOverlay)
                    
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
                        
                        Box(modifier = Modifier.size(size.dp), contentAlignment = Alignment.Center) {
                            Icon(
                                painter = androidx.compose.ui.res.painterResource(id = drawableRes),
                                contentDescription = "Crosshair",
                                tint = actualColor.copy(alpha = opacity),
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
                windowManager.addView(crosshairView, crosshairParams)
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
                        onDragStart = { lastInteraction = System.currentTimeMillis() },
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
                    isSelected = selectedTab == "Performance" && !showCrosshairConfigState.value,
                    themeColor = themeColor,
                    onClick = { 
                        selectedTab = "Performance"
                        showCrosshairConfigState.value = false
                    }
                )
                SidebarItem(
                    icon = Icons.Default.Widgets,
                    label = "Tools",
                    isSelected = selectedTab == "Tools" || showCrosshairConfigState.value,
                    themeColor = themeColor,
                    onClick = { 
                        selectedTab = "Tools"
                        showCrosshairConfigState.value = false
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
                                isCrosshairActiveState = isCrosshairActiveState, 
                                onToggleCrosshair = onToggleCrosshair, 
                                themeColor = themeColor,
                                showCrosshairConfigState = showCrosshairConfigState
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

data class ToolData(val title: String, val iconRes: Int?, val iconVector: ImageVector?, val action: () -> Unit, val onLongClick: (() -> Unit)? = null)

@Composable
fun ToolsTab(isCrosshairActiveState: MutableState<Boolean>, onToggleCrosshair: () -> Unit, themeColor: Color, showCrosshairConfigState: MutableState<Boolean>) {
    val coroutineScope = rememberCoroutineScope()
    val tools = listOf(
        ToolData("Crosshair", R.drawable.ic_crosshair_1, null, { onToggleCrosshair() }, onLongClick = { showCrosshairConfigState.value = true }),
        ToolData("Cleanup", null, Icons.Default.CleaningServices, { 
            Runtime.getRuntime().exec(arrayOf("su", "-c", "am kill-all; echo 3 > /proc/sys/vm/drop_caches; echo 1 > /proc/sys/vm/compact_memory"))
        }),
        ToolData("Screenshot", null, Icons.Default.CameraAlt, { 
            Runtime.getRuntime().exec(arrayOf("su", "-c", "input keyevent 120"))
        })
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
                        ToolItem(
                            title = tool.title, 
                            iconRes = tool.iconRes,
                            icon = tool.iconVector, 
                            modifier = Modifier.weight(1f),
                            isActive = isCrosshairActive,
                            themeColor = themeColor,
                            onLongClick = tool.onLongClick
                        ) {
                            coroutineScope.launch(Dispatchers.IO) {
                                try {
                                    tool.action.invoke()
                                } catch (e: Exception) {}
                            }
                        }
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
fun ToolItem(title: String, iconRes: Int? = null, icon: ImageVector? = null, modifier: Modifier = Modifier, isActive: Boolean = false, themeColor: Color = Color.White, onLongClick: (() -> Unit)? = null, onClick: () -> Unit) {
    val coroutineScope = rememberCoroutineScope()
    var showSuccess by remember { mutableStateOf(false) }
    
    val displayTitle = if (showSuccess) {
        when (title) {
            "Cleanup" -> "Cleaned!"
            "Screenshot" -> "Captured!"
            else -> title
        }
    } else title

    val bgColor by androidx.compose.animation.animateColorAsState(
        targetValue = if (isActive || showSuccess) Color(0xFFE0E0E0) else Color(0xFF2A2A2A),
        animationSpec = tween(300),
        label = "bgColorAnim"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .combinedClickable(
                onClick = {
                    onClick()
                    if (title == "Cleanup" || title == "Screenshot") {
                        coroutineScope.launch {
                            showSuccess = true
                            delay(1500)
                            showSuccess = false
                        }
                    }
                },
                onLongClick = onLongClick
            )
            .padding(vertical = 14.dp, horizontal = 4.dp)
    ) {
        val iconTint = if (isActive || showSuccess) Color.Black else Color.White
        if (iconRes != null) {
            Icon(
                painter = androidx.compose.ui.res.painterResource(id = iconRes),
                contentDescription = displayTitle,
                tint = iconTint,
                modifier = Modifier.size(24.dp)
            )
        } else if (icon != null) {
            Icon(
                imageVector = if (showSuccess) Icons.Default.Check else icon,
                contentDescription = displayTitle,
                tint = iconTint,
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = displayTitle,
            color = if (isActive || showSuccess) Color.Black else Color.LightGray,
            fontSize = 10.sp,
            maxLines = 1
        )
    }
}

@Composable
fun CrosshairConfigView(
    currentPackage: String,
    onDismissRequest: () -> Unit,
    crosshairTypeState: MutableState<Int>,
    crosshairSizeState: MutableState<Float>,
    crosshairOpacityState: MutableState<Float>,
    crosshairColorState: MutableState<String>,
    themeColor: Color,
    sharedPrefs: android.content.SharedPreferences
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Crosshair Settings", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            IconButton(onClick = onDismissRequest, modifier = Modifier.size(24.dp)) {
                Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = Color.Gray)
            }
        }
        
        Text("Style", color = Color.Gray, fontSize = 12.sp)
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            for (i in 1..4) {
                val drawableRes = when(i) {
                    2 -> R.drawable.ic_crosshair_2
                    3 -> R.drawable.ic_crosshair_3
                    4 -> R.drawable.ic_crosshair_4
                    else -> R.drawable.ic_crosshair_1
                }
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (crosshairTypeState.value == i) themeColor else Color(0xFF2A2A2A))
                        .clickable { 
                            crosshairTypeState.value = i 
                            sharedPrefs.edit().putInt("crosshair_type", i).apply()
                            if (currentPackage.isNotEmpty()) sharedPrefs.edit().putInt("crosshair_type_$currentPackage", i).apply()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        painter = androidx.compose.ui.res.painterResource(id = drawableRes),
                        contentDescription = "Crosshair $i",
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text("Color", color = Color.Gray, fontSize = 12.sp)
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            val colors = listOf("White" to Color.White, "Red" to Color.Red, "Blue" to Color.Blue, "Green" to Color.Green)
            for ((colorName, colorValue) in colors) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (crosshairColorState.value == colorName) themeColor else Color(0xFF2A2A2A))
                        .clickable { 
                            crosshairColorState.value = colorName 
                            sharedPrefs.edit().putString("crosshair_color", colorName).apply()
                            if (currentPackage.isNotEmpty()) sharedPrefs.edit().putString("crosshair_color_$currentPackage", colorName).apply()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Box(modifier = Modifier.size(24.dp).clip(CircleShape).background(colorValue).border(1.dp, Color.Gray, CircleShape))
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text("Size", color = Color.Gray, fontSize = 12.sp)
        Slider(
            value = crosshairSizeState.value,
            onValueChange = { 
                crosshairSizeState.value = it 
                sharedPrefs.edit().putFloat("crosshair_size", it).apply()
                if (currentPackage.isNotEmpty()) sharedPrefs.edit().putFloat("crosshair_size_$currentPackage", it).apply()
            },
            valueRange = 16f..128f
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text("Opacity", color = Color.Gray, fontSize = 12.sp)
        Slider(
            value = crosshairOpacityState.value,
            onValueChange = { 
                crosshairOpacityState.value = it 
                sharedPrefs.edit().putFloat("crosshair_opacity", it).apply()
                if (currentPackage.isNotEmpty()) sharedPrefs.edit().putFloat("crosshair_opacity_$currentPackage", it).apply()
            },
            valueRange = 0.1f..1f
        )
    }
}
