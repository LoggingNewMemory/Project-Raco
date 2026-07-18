package com.kanagawa.yamada.project.raco

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.BatteryManager
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.geometry.Offset

class GameSpaceOverlay(private val context: Context) : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var composeView: ComposeView? = null
    val selectedModeState = mutableStateOf("Awaken")
    val isExecutingState = mutableStateOf(false)
    val executingModeState = mutableStateOf("")

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val store = ViewModelStore()
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = store
    override val savedStateRegistry: SavedStateRegistry get() = savedStateRegistryController.savedStateRegistry

    private var isExpanded by mutableStateOf(false)
    private val sharedPrefs = context.getSharedPreferences("raco_app_config", Context.MODE_PRIVATE)
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

    fun show() {
        if (composeView != null) return

        composeView = ComposeView(context).apply {
            setViewTreeLifecycleOwner(this@GameSpaceOverlay)
            setViewTreeViewModelStoreOwner(this@GameSpaceOverlay)
            setViewTreeSavedStateRegistryOwner(this@GameSpaceOverlay)
            
            setContent {
                MaterialTheme(colorScheme = darkColorScheme()) {
                    GameSpaceContent(
                        isExpanded = isExpanded,
                        onExpand = {
                            isExpanded = true
                            updateLayoutParams()
                        },
                        onCollapse = {
                            isExpanded = false
                            updateLayoutParams()
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
                        executingModeState = executingModeState
                    )
                }
            }
        }
        
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        windowManager.addView(composeView, params)
    }

    fun hide() {
        composeView?.let {
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
            windowManager.removeView(it)
            composeView = null
        }
        isExpanded = false
    }
    
    private fun updateLayoutParams() {
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
    isExpanded: Boolean,
    onExpand: () -> Unit,
    onCollapse: () -> Unit,
    onDrag: (Float, Float) -> Unit,
    context: Context,
    selectedModeState: MutableState<String>,
    isExecutingState: MutableState<Boolean>,
    executingModeState: MutableState<String>
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
        GameSpaceDashboard(onCollapse = onCollapse, context = context, selectedModeState = selectedModeState, isExecutingState = isExecutingState, executingModeState = executingModeState, themeColor = themeColor)
    }
}

@Composable
fun GameSpaceDashboard(onCollapse: () -> Unit, context: Context, selectedModeState: MutableState<String>, isExecutingState: MutableState<Boolean>, executingModeState: MutableState<String>, themeColor: Color) {
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
                    isSelected = selectedTab == "Performance",
                    themeColor = themeColor,
                    onClick = { selectedTab = "Performance" }
                )
                SidebarItem(
                    icon = Icons.Default.Widgets,
                    label = "Tools",
                    isSelected = selectedTab == "Tools",
                    themeColor = themeColor,
                    onClick = { selectedTab = "Tools" }
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
                if (selectedTab == "Performance") {
                    PerformanceTab(context, selectedModeState, isExecutingState, executingModeState, themeColor)
                } else {
                    ToolsTab()
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
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = label,
            fontSize = 10.sp,
            color = if (isSelected) themeColor else Color.Gray
        )
    }
}

@Composable
fun PerformanceTab(context: Context, selectedModeState: MutableState<String>, isExecutingState: MutableState<Boolean>, executingModeState: MutableState<String>, themeColor: Color) {
    var batteryLevel by remember { mutableStateOf("--") }
    var cpuUsage by remember { mutableStateOf("--") }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            // Update battery once (or we can poll it)
            try {
                val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                batteryLevel = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).toString()
            } catch(e: Exception){}

            while (isActive) {
                try {
                    val cpufreqDir = java.io.File("/sys/devices/system/cpu/cpufreq")
                    val highestPolicy = cpufreqDir.listFiles { file -> 
                        file.isDirectory && file.name.startsWith("policy") 
                    }?.maxByOrNull { it.name.removePrefix("policy").toIntOrNull() ?: -1 }
                    
                    if (highestPolicy != null) {
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
                
                try {
                    val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    batteryLevel = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).toString()
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
            StatCircle(title = "CPU", value = cpuUsage, unit = "MHz", highlight = true, themeColor = themeColor)
            StatCircle(title = "Battery", value = batteryLevel, unit = "%", highlight = false, themeColor = themeColor)
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF2A2A2A)),
                contentAlignment = Alignment.Center
            ) {
                Text("Standard", color = Color.Gray, fontSize = 12.sp)
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .border(1.dp, themeColor, RoundedCornerShape(12.dp))
                    .background(Color(0xFF1E1E1E)),
                contentAlignment = Alignment.Center
            ) {
                Text("Ultra touch response", color = themeColor, fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun StatCircle(title: String, value: String, unit: String, highlight: Boolean, themeColor: Color) {
    Box(
        modifier = Modifier.size(72.dp),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
            drawArc(
                color = if (highlight) themeColor else Color(0xFF333333),
                startAngle = 135f,
                sweepAngle = 270f,
                useCenter = false,
                style = androidx.compose.ui.graphics.drawscope.Stroke(
                    width = 4.dp.toPx(),
                    cap = androidx.compose.ui.graphics.StrokeCap.Round
                )
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, color = Color.Gray, fontSize = 8.sp)
            Text(value, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(unit, color = Color.Gray, fontSize = 8.sp)
        }
    }
}

@Composable
fun ToolsTab() {
    val coroutineScope = rememberCoroutineScope()
    val tools = listOf(
        Triple("WLAN", Icons.Default.Wifi) { Runtime.getRuntime().exec(arrayOf("su", "-c", "svc wifi disable")) },
        Triple("Network", Icons.Default.Public) { Runtime.getRuntime().exec(arrayOf("su", "-c", "svc data disable")) },
        Triple("Cleanup", Icons.Default.CleaningServices) { Runtime.getRuntime().exec(arrayOf("su", "-c", "echo 3 > /proc/sys/vm/drop_caches")) },
        Triple("Screenshot", Icons.Default.CameraAlt) { Runtime.getRuntime().exec(arrayOf("su", "-c", "input keyevent 120")) },
        Triple("Record", Icons.Default.Videocam) { },
        Triple("Bullet Notif", Icons.Default.Message) { }
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
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                for (col in 0 until 3) {
                    val index = row * 3 + col
                    if (index < tools.size) {
                        val tool = tools[index]
                        ToolItem(title = tool.first, icon = tool.second as ImageVector) {
                            coroutineScope.launch(Dispatchers.IO) {
                                try {
                                    (tool.third as () -> Unit).invoke()
                                } catch (e: Exception) {}
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ToolItem(title: String, icon: ImageVector, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .width(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF2A2A2A))
            .clickable(onClick = onClick)
            .padding(10.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = title,
            tint = Color.White,
            modifier = Modifier.size(24.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = title,
            color = Color.LightGray,
            fontSize = 10.sp,
            maxLines = 1
        )
    }
}
