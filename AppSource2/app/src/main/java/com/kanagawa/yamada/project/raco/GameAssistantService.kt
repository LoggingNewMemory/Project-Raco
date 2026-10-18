/*
 * Project Raco - Performance and Gaming Optimization Suite
 * Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package com.kanagawa.yamada.project.raco

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class GameAssistantService : Service() {
    private var gameSpaceOverlay: RacoGameAssistant? = null

    override fun onCreate() {
        super.onCreate()
        Handler(Looper.getMainLooper()).post {
            gameSpaceOverlay = RacoGameAssistant(this)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val pkg = intent?.getStringExtra("package") ?: ""
        if (pkg.isNotEmpty()) {
            Handler(Looper.getMainLooper()).post {
                gameSpaceOverlay?.show(pkg)
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        gameSpaceOverlay?.hide()
    }
}
