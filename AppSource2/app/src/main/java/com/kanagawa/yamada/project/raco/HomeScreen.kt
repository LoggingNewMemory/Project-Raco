package com.kanagawa.yamada.project.raco

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun HomeScreen() {
    // Current theme color based on Awaken (Red), Balanced (Yellow), Powersave (Green)
    val accentColor = Color(0xFFE53935) // Defaulting to Awaken Red

    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0A))
            // ── Auto Notch Avoider ──
            // Automatically detects the camera notch and applies exactly enough padding
            // so your UI text/buttons aren't obscured, regardless of orientation.
            .displayCutoutPadding()
            .padding(16.dp)
    ) {
        // LEFT PANE: Game List
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
        ) {
            // Header
            Text(
                text = buildAnnotatedString {
                    withStyle(style = SpanStyle(color = accentColor)) { append("PROJECT ") }
                    withStyle(style = SpanStyle(color = Color.White)) { append("RACO") }
                },
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "13:11 • 74%", // Placeholder status
                color = Color.White,
                fontSize = 12.sp,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Game List
            LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(4) { index ->
                    GameListItemStub()
                }
                item {
                    Text("Add Game", color = Color.White, modifier = Modifier.padding(top = 8.dp))
                }
            }
        }

        // RIGHT PANE: Selected Game Info & Controls
        Box(
            modifier = Modifier
                .weight(2f)
                .fillMaxHeight()
                // Placeholder for your diagonal background asset
                .background(Color(0xFF1A1A1A))
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(24.dp),
                horizontalAlignment = Alignment.End
            ) {
                Text(
                    text = "[Game Name]",
                    color = Color.White,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 12.dp)
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // Settings/Menu Button
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .border(1.dp, accentColor, RoundedCornerShape(4.dp))
                            .background(Color.Black),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("III", color = Color.White)
                    }

                    // ENTER Button
                    Button(
                        onClick = { /* Launch Game via Daemon */ },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                        shape = RoundedCornerShape(4.dp),
                        modifier = Modifier
                            .height(48.dp)
                            .width(120.dp)
                            .border(1.dp, accentColor, RoundedCornerShape(4.dp))
                    ) {
                        Text("ENTER", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // Top Right Settings Icon
            Text(
                text = "[Settings Icon]",
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp)
            )
        }
    }
}

@Composable
fun GameListItemStub() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .background(Color.White, RoundedCornerShape(8.dp))
        )
        Column(modifier = Modifier.padding(start = 12.dp)) {
            Text("[Game Name]", color = Color.White, fontSize = 14.sp)
            Text("[Duration Played]", color = Color.Gray, fontSize = 12.sp)
        }
    }
}