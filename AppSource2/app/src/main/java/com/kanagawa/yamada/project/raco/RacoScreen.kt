package com.kanagawa.yamada.project.raco
import androidx.compose.ui.res.stringResource
import com.kanagawa.yamada.project.raco.R

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.activity.compose.BackHandler
import android.media.MediaPlayer

private val dialogues = listOf(
    "Welcome. Please scroll down to read more.",
    "I am Zefanya... though most call me Raco.",
    "Yamada-sama requested I greet you.",
    "Don't stare too much... it is embarrassing.",
    "I was just tidying up the pixels here.",
    "My ears? Yes, they are real. Please do not touch.",
    "I hope you are not carrying any red laser pointers.",
    "I cannot responsible for my actions if I see a red dot.",
    "Yamada-sama is likely coding right now.",
    "I have to ensure he remembers to eat and sleep.",
    "Being a childhood friend is... a lot of work.",
    "My tail moves on its own. Pay it no mind.",
    "Do you require refreshments? I can brew some tea.",
    "I prefer warm fish over expensive dinners.",
    "The data below is accurate. I verified it myself.",
    "I am not cold... I am just composed.",
    "...",
    "You are quite patient to stay here with me.",
    "I do not dislike your company, I suppose.",
    "Feel free to check the Telegram group later.",
    "I will remain here. Please, proceed."
)

@Composable
private fun TypewriterText(text: String, modifier: Modifier = Modifier) {
    var displayed by remember { mutableStateOf("") }

    LaunchedEffect(text) {
        displayed = ""
        for (char in text) {
            displayed += char
            delay(30)
        }
    }

    Text(
        text = displayed,
        modifier = modifier,
        color = Color.White,
        fontSize = 16.sp,
        lineHeight = 24.sp
    )
}

@Composable
private fun ShimmerBox() {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(tween(1200, easing = LinearEasing), RepeatMode.Restart),
        label = "shimmerTranslate"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(300.dp)
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460), Color(0xFF16213E), Color(0xFF1A1A2E)),
                    start = Offset(translateAnim - 500f, 0f),
                    end = Offset(translateAnim, 0f)
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(stringResource(R.string.raco_l2d), color = Color.White.copy(alpha = 0.3f), fontWeight = FontWeight.Bold, letterSpacing = 4.sp)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RacoScreen(onBack: () -> Unit) {
    var dialogueIndex by remember { mutableIntStateOf(0) }
    val context = LocalContext.current

    val configuration = androidx.compose.ui.platform.LocalConfiguration.current
    val videoHeightDp = configuration.screenWidthDp.dp * (1280f / 720f)
    val overlapAmount = 25.dp + (videoHeightDp * 0.05f)

    val bgmPlayer = remember { MediaPlayer.create(context, R.raw.so_cute).apply { isLooping = true } }
    val scope = rememberCoroutineScope()
    var isClosing by remember { mutableStateOf(false) }

    val closeWithFade = {
        if (!isClosing) {
            isClosing = true
            onBack() // Navigate back instantly without delay
            Thread {
                try {
                    for (i in 20 downTo 0) {
                        val volume = i / 20f
                        bgmPlayer.setVolume(volume, volume)
                        Thread.sleep(40) // 800ms fade out
                    }
                    bgmPlayer.stop()
                    bgmPlayer.release()
                } catch (e: Exception) {}
            }.start()
        }
    }

    LaunchedEffect(Unit) {
        bgmPlayer.setVolume(0f, 0f)
        bgmPlayer.start()
        for (i in 1..20) {
            val volume = i / 20f
            bgmPlayer.setVolume(volume, volume)
            delay(50)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            if (!isClosing) {
                bgmPlayer.release()
            }
        }
    }

    BackHandler(enabled = !isClosing) {
        closeWithFade()
    }

    Scaffold(
        containerColor = Color.Transparent
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            // Video section (image placeholder)
            Box(modifier = Modifier.fillMaxWidth().background(Color.Black)) {
                val videoIds = listOf(R.raw.y1, R.raw.y2, R.raw.y3)
                val randomVideoId = remember { videoIds.random() }
                
                androidx.compose.ui.viewinterop.AndroidView(
                    factory = { ctx ->
                        android.view.TextureView(ctx).apply {
                            var mediaPlayer: android.media.MediaPlayer? = null
                            
                            surfaceTextureListener = object : android.view.TextureView.SurfaceTextureListener {
                                override fun onSurfaceTextureAvailable(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
                                    mediaPlayer = android.media.MediaPlayer.create(ctx, randomVideoId)?.apply {
                                        setSurface(android.view.Surface(surface))
                                        isLooping = true
                                        
                                        val vw = 720f
                                        val vh = 1280f
                                        val viewWidth = width.toFloat()
                                        val viewHeight = height.toFloat()
                                        val sx = viewWidth / vw
                                        val sy = viewHeight / vh
                                        val s = maxOf(sx, sy)
                                        val matrix = android.graphics.Matrix()
                                        matrix.setScale(s / sx, s / sy, viewWidth / 2f, viewHeight / 2f)
                                        setTransform(matrix)
                                        
                                        start()
                                    }
                                }
                                override fun onSurfaceTextureSizeChanged(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
                                    val vw = 720f
                                    val vh = 1280f
                                    val viewWidth = width.toFloat()
                                    val viewHeight = height.toFloat()
                                    val sx = viewWidth / vw
                                    val sy = viewHeight / vh
                                    val s = maxOf(sx, sy)
                                    val matrix = android.graphics.Matrix()
                                    matrix.setScale(s / sx, s / sy, viewWidth / 2f, viewHeight / 2f)
                                    setTransform(matrix)
                                }
                                override fun onSurfaceTextureDestroyed(surface: android.graphics.SurfaceTexture): Boolean {
                                    mediaPlayer?.release()
                                    mediaPlayer = null
                                    return true
                                }
                                override fun onSurfaceTextureUpdated(surface: android.graphics.SurfaceTexture) {}
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth().aspectRatio(720f / 1280f)
                )
                // VN dialogue box
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(start = 20.dp, end = 20.dp, top = 30.dp, bottom = overlapAmount + 5.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.Black.copy(alpha = 0.75f))
                        .clickable { dialogueIndex = (dialogueIndex + 1) % dialogues.size }
                        .padding(horizontal = 24.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(stringResource(R.string.raco), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        AnimatedContent(
                            targetState = dialogueIndex,
                            transitionSpec = { fadeIn(tween(200)) togetherWith fadeOut(tween(100)) },
                            label = "dialogue"
                        ) { idx ->
                            TypewriterText(text = dialogues[idx])
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(stringResource(R.string.tap_to_read), color = Color.White.copy(alpha = 0.5f), fontSize = 11.sp, modifier = Modifier.align(Alignment.End))
                    }
                }
                
                Box(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(top = padding.calculateTopPadding() + 8.dp, start = 16.dp)
                        .clip(androidx.compose.foundation.shape.CircleShape)
                        .background(Color.Black.copy(alpha = 0.5f))
                ) {
                    IconButton(onClick = { closeWithFade() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                }
            }

            // Info card section
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .offset(y = -overlapAmount)
                    .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(24.dp)
            ) {
                Column {
                    // Handle pill
                    Box(modifier = Modifier.width(40.dp).height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.Gray.copy(alpha = 0.5f)).align(Alignment.CenterHorizontally))
                    Spacer(modifier = Modifier.height(20.dp))

                    Text(stringResource(R.string.zefanya_raco), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                    Text("[ゼファニャ・ラチョ]", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.W400, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.9f))
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(stringResource(R.string.yamada_s_neko_maid), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)

                    HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))

                    val infoItems = listOf(
                        "Name Call" to "Raco / Zefa",
                        "Age" to "[Same as Kanagawa Yamada]",
                        "Nationality" to "Japanese",
                        "Height" to "180 cm",
                        "Weight" to "80 kg",
                        "Gender" to "Female [Straight]",
                        "Race" to "Cat girl",
                        "Hobby" to "Chasing Red Laser",
                        "Favorite Food" to "Warm Fish, Hot tea",
                        "Hate" to "Karbit, LGBTQ+",
                        "Origin" to "Yamada's childhood friend",
                        "Affiliation" to "KanaDev_IS Hidden Member",
                        "Personality" to "Kuudere",
                        "Birthday" to "4 September",
                        "Religion" to "Christian"
                    )

                    infoItems.forEach { (label, value) ->
                        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                            Text(label, modifier = Modifier.weight(4f), fontWeight = FontWeight.W600, color = MaterialTheme.colorScheme.secondary)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(value, modifier = Modifier.weight(6f), color = MaterialTheme.colorScheme.onSurface)
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        TextButton(onClick = {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/ProjectRaco")))
                        }) {
                            Text(stringResource(R.string.official_project_raco_telegram_group), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                        }
                        TextButton(onClick = {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/KanagawaYamadaCH/2543")))
                        }) {
                            Text(stringResource(R.string.donate_for_project_raco), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                        }
                    }

                    Spacer(modifier = Modifier.height(40.dp))
                }
            }
        }
    }
}
