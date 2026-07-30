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
