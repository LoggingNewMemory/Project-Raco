package com.kanagawa.yamada.project.raco.RacoOverlayTools

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

import android.content.Intent
import androidx.compose.ui.platform.LocalContext
import com.kanagawa.yamada.project.raco.ToastOverlayService

@Composable
fun OverlayClean(themeColor: Color) {
    val context = LocalContext.current
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .border(1.dp, themeColor, RoundedCornerShape(11.4.dp))
                .clip(RoundedCornerShape(11.4.dp))
                .clickable {
                    Thread {
                        try {
                            Runtime.getRuntime().exec(arrayOf("su", "-c", "sync; cmd activity kill-all > /dev/null 2>&1; pm trim-caches 100G > /dev/null 2>&1; echo 3 > /proc/sys/vm/drop_caches; logcat -b all -c")).waitFor()
                            
                            val intent = Intent(context, ToastOverlayService::class.java).apply {
                                putExtra("msg", "Clean Up Finished")
                            }
                            context.startService(intent)
                        } catch (e: Exception) {}
                    }.start()
                },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Delete,
                contentDescription = "Clean",
                tint = themeColor,
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Clean",
            color = themeColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
