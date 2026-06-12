package com.kanagawa.yamada.project.raco

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import android.app.Activity
import android.content.pm.ActivityInfo
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun Terminal(accentColor: Color, onClose: () -> Unit) {
    val context = LocalContext.current
    val activity = context as? Activity

    DisposableEffect(Unit) {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        onDispose {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE
        }
    }

    var outputLines by remember { mutableStateOf(listOf<String>()) }
    var input by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        val introText = listOf(
            "Welcome to Raco Shell"
        )
        for (line in introText) {
            outputLines = outputLines + line
            kotlinx.coroutines.delay(150)
        }
        focusRequester.requestFocus()
    }

    LaunchedEffect(outputLines.size) {
        if (outputLines.isNotEmpty()) {
            listState.animateScrollToItem(outputLines.size - 1)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .safeDrawingPadding()
    ) {
        Row(
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            modifier = Modifier.background(Color(0xFF1E1E1E)).fillMaxWidth().padding(8.dp)
        ) {
            IconButton(onClick = onClose) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Close", tint = Color.White)
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text("Raco Shell", color = accentColor, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            items(outputLines) { line ->
                Text(line, color = Color.White, fontFamily = FontFamily.Monospace, fontSize = 14.sp)
            }
        }

        TextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color(0xFF1E1E1E),
                unfocusedContainerColor = Color(0xFF1E1E1E),
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent
            ),
            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = FontFamily.Monospace),
            placeholder = { Text("$", color = Color.Gray, fontFamily = FontFamily.Monospace) },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
            keyboardActions = KeyboardActions(
                onGo = {
                    val cmd = input
                    if (cmd.isNotBlank()) {
                        outputLines = outputLines + "$ $cmd"
                        input = ""
                        scope.launch {
                            if (cmd.trim() == "clear") {
                                outputLines = listOf()
                            } else {
                                val res = executeShellCommand(cmd)
                                outputLines = outputLines + res.split("\n")
                            }
                        }
                    }
                }
            )
        )
    }
}

suspend fun executeShellCommand(command: String): String = withContext(Dispatchers.IO) {
    try {
        if (command.trim() == "help") return@withContext "Built-in: help, clear. Also runs standard shell commands. Try 'su' for root operations."
        
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", command))
        val stdout = process.inputStream.bufferedReader().readText()
        val stderr = process.errorStream.bufferedReader().readText()
        process.waitFor()
        
        val output = stdout + stderr
        if (output.isEmpty()) "[No output]" else output.trimEnd()
    } catch (e: Exception) {
        e.message ?: "Unknown error"
    }
}
