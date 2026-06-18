package com.kanagawa.yamada.project.raco

// Socket imports removed
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

/**
 * Central helper for communicating with the raco core logic.
 *
 * Strategy:
 *  - Direct execution via `su` using linker64.
 *    This matches exactly what works manually, so it is always reliable
 *    as long as root is available.
 */
object RacoDaemon {

    // Dedicated scope — SupervisorJob means one failed send doesn’t cancel others.
    // Using GlobalScope here would leak the coroutine indefinitely with no way to cancel.
    private val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Mode string → raco binary argument number
    private fun modeToArg(mode: String): String = when (mode.uppercase()) {
        "AWAKEN"    -> "4"
        "BALANCED"  -> "3"
        "POWERSAVE" -> "2"
        "NORMAL"    -> "1"
        else        -> "1"
    }

    private const val RACO_BIN = "/data/adb/modules/ProjectRaco/Compiled/raco"

    /**
     * Send a mode switch command. Safe to call from the main thread —
     * dispatches to IO internally.
     */
    fun sendMode(mode: String, packageName: String? = null) {
        ioScope.launch {
            tryExecDirect(mode)
        }
    }

    private fun tryExecDirect(mode: String) {
        try {
            val cmd = "/system/bin/linker64 $RACO_BIN ${modeToArg(mode)} >/dev/null 2>&1"
            val proc = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            // 5-second guard: don’t let a hung su block the IO thread indefinitely.
            if (!proc.waitFor(5, TimeUnit.SECONDS)) {
                proc.destroy()
            }
        } catch (_: Exception) { }
    }
}
