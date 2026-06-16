package com.kanagawa.yamada.project.raco

import android.net.LocalSocket
import android.net.LocalSocketAddress
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

/**
 * Central helper for communicating with the raco_gameservice daemon.
 *
 * Strategy:
 *  1. Try the Unix abstract socket (fast path — daemon is running).
 *  2. If the socket fails for any reason (daemon dead, busy, OEM killed it),
 *     fall back to direct execution via `su` using linker64.
 *     This matches exactly what works manually, so it is always reliable
 *     as long as root is available.
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
            val socketOk = trySendViaSocket(mode, packageName)
            if (!socketOk) {
                // Socket failed — daemon is likely dead or busy.
                // Fall back to direct execution via su, identical to the manual command that always works.
                tryExecDirect(mode)
            }
        }
    }

    private fun trySendViaSocket(mode: String, packageName: String?): Boolean {
        return try {
            val socket = LocalSocket()
            // 3-second timeout: if the daemon is dead or stalled, we must not
            // hang the IO thread waiting for the OS default (~2 min).
            socket.soTimeout = 3_000
            val address = LocalSocketAddress("raco_gameservice", LocalSocketAddress.Namespace.ABSTRACT)
            socket.connect(address)
            val payload = if (packageName != null) "$mode:$packageName" else mode
            socket.outputStream.write(payload.toByteArray())
            socket.outputStream.flush()
            socket.close()
            true
        } catch (e: Exception) {
            false // Daemon not reachable
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
