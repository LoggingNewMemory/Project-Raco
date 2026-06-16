package com.kanagawa.yamada.project.raco

import android.net.LocalSocket
import android.net.LocalSocketAddress
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

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
        GlobalScope.launch(Dispatchers.IO) {
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
            Runtime.getRuntime().exec(arrayOf("su", "-c", cmd)).waitFor()
        } catch (_: Exception) { }
    }
}
