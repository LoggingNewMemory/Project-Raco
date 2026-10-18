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

package com.kanagawa.yamada.project.raco.GameTools

object CleanupTool {
    fun execute(): String {
        var memBefore = 0L
        try {
            java.io.File("/proc/meminfo").forEachLine { line ->
                if (line.startsWith("MemAvailable:")) {
                    memBefore = line.split("\\s+".toRegex())[1].toLong()
                }
            }
        } catch(e: Exception) {}
        
        Runtime.getRuntime().exec(arrayOf("su", "-c", "am kill-all; echo 3 > /proc/sys/vm/drop_caches; echo 1 > /proc/sys/vm/compact_memory")).waitFor()
        
        var memAfter = 0L
        try {
            java.io.File("/proc/meminfo").forEachLine { line ->
                if (line.startsWith("MemAvailable:")) {
                    memAfter = line.split("\\s+".toRegex())[1].toLong()
                }
            }
        } catch(e: Exception) {}
        
        val diff = (memAfter - memBefore) / 1024
        return if (diff > 0) "Cleaned\n$diff Mb" else "Optimized!"
    }
}
