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

package com.kanagawa.yamada.project.raco.tools

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.core.content.ContextCompat

/**
 * Bypass charging: pauses charging of the battery while the charger stays plugged in,
 * by writing to a kernel charger-control node (sysfs), which needs root.
 *
 * Nodes differ per device/kernel, so the app detects which known nodes exist, lets the user pick one
 * and also accepts a custom node. Everything here is blocking: call it from a background thread.
 */
object BypassCharging {
    private const val PREFS = "raco_app_config"
    private const val KEY_ENABLED = "bypass_enabled"
    private const val KEY_PATH = "bypass_path"
    private const val KEY_NORMAL = "bypass_normal"
    private const val KEY_BYPASS = "bypass_value"
    private const val KEY_RESUME = "bypass_resume_level"

    const val MSG_NO_NODE = "No node found"
    const val MSG_WRITE_FAILED = "Write failed"
    const val MSG_PLUG_FIRST = "Plug in the charger first"

    /** [normal] = value that charges normally, [bypass] = value that pauses charging. */
    data class Node(val path: String, val normal: String, val bypass: String)

    data class Detected(val node: Node, val currentValue: String)

    data class Status(
        val level: Int,
        val plugged: Int,      // BatteryManager.BATTERY_PLUGGED_* bitmask, 0 = unplugged
        val statusCode: Int,   // BatteryManager.BATTERY_STATUS_*
        val currentMa: Int?,
        val tempC: Float
    )

    /** Commonly used charger-control nodes (the first one found is used by default). */
    val candidates = listOf(
        // MediaTek battery-gauge interface (used by AZenith / ACC): real bypass, battery current ~0 mA.
        // Values contain a space ("0 1" is written as-is).
        Node("/proc/mtk_battery_cmd/current_cmd", "0 0", "0 1"),
        Node("/proc/mtk_battery_cmd/en_power_path", "1", "0"),
        // MediaTek / Transsion (Infinix, Tecno, itel): vendor bypass node (on newer XOS it only reduces the
        // charging current instead of stopping it), then the "disable charger" nodes
        Node("/sys/devices/platform/charger/bypass_charger", "0", "1"),
        Node("/sys/devices/platform/charger/tran_custom_disable_charger", "0", "1"),
        Node("/sys/devices/platform/charger/tran_aichg_disable_charger", "0", "1"),
        Node("/sys/class/power_supply/battery/batt_slate_mode", "0", "1"),
        Node("/sys/class/power_supply/battery/input_suspend", "0", "1"),
        Node("/sys/class/qcom-battery/input_suspend", "0", "1"),
        Node("/sys/class/power_supply/battery/charging_enabled", "1", "0"),
        Node("/sys/class/power_supply/battery/battery_charging_enabled", "1", "0"),
        Node("/sys/class/power_supply/battery/charge_enabled", "1", "0"),
        Node("/sys/class/power_supply/battery/charge_disable", "0", "1"),
        Node("/sys/class/power_supply/battery/op_disable_charge", "0", "1"),
        Node("/sys/class/power_supply/battery/mmi_charging_enable", "1", "0"),
        Node("/sys/class/power_supply/main/charging_enabled", "1", "0"),
        Node("/sys/devices/platform/mt-battery/disable_charger", "0", "1")
    )

    private fun prefs(c: Context) = c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun su(cmd: String): String = try {
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        p.outputStream.close()
        val out = p.inputStream.bufferedReader().use { it.readText() }
        p.waitFor()
        out.trim()
    } catch (e: Exception) {
        ""
    }

    // ------------------------------------------------------------------ settings

    fun isEnabled(c: Context) = prefs(c).getBoolean(KEY_ENABLED, false)

    fun resumeLevel(c: Context) = prefs(c).getInt(KEY_RESUME, 20).coerceIn(5, 50)

    fun setResumeLevel(c: Context, v: Int) {
        prefs(c).edit().putInt(KEY_RESUME, v.coerceIn(5, 50)).apply()
    }

    fun currentNode(c: Context): Node? {
        val p = prefs(c)
        val path = p.getString(KEY_PATH, "") ?: ""
        val normal = p.getString(KEY_NORMAL, "") ?: ""
        val bypass = p.getString(KEY_BYPASS, "") ?: ""
        return if (path.isNotEmpty() && normal.isNotEmpty() && bypass.isNotEmpty()) Node(path, normal, bypass) else null
    }

    fun saveNode(c: Context, node: Node) {
        prefs(c).edit()
            .putString(KEY_PATH, node.path)
            .putString(KEY_NORMAL, node.normal)
            .putString(KEY_BYPASS, node.bypass)
            .apply()
    }

    /** Custom nodes go into a root shell, so they are strictly validated (no spaces, quotes, ';' ...). */
    fun isValidCustom(path: String, normal: String, bypass: String): Boolean =
        PATH_RE.matches(path) &&
            !path.contains("..") &&
            VALUE_RE.matches(normal) &&
            VALUE_RE.matches(bypass) &&
            normal != bypass

    private val PATH_RE = Regex("^/(sys|proc)/[A-Za-z0-9_./:@-]{3,200}$")
    private val VALUE_RE = Regex("^[A-Za-z0-9_-]{1,8}( [A-Za-z0-9_-]{1,8}){0,2}$")

    /** Forgives pasted shell syntax: "echo 0 > ..." / quotes are stripped, only the value is kept. */
    fun cleanValue(raw: String): String =
        raw.replace("echo", "").replace(">", "").replace("\"", "").replace("'", "").trim().replace(Regex("\\s+"), " ")

    /** Called on boot: kernel nodes are reset by a reboot, so a stale "on" flag must not survive. */
    fun clearFlag(c: Context) {
        prefs(c).edit().putBoolean(KEY_ENABLED, false).apply()
    }

    // ------------------------------------------------------------------ detection / status

    /** Lists the known nodes that exist on this device together with their current value. */
    fun detect(): List<Detected> {
        val script = candidates.joinToString("; ") {
            "[ -e ${it.path} ] && echo \"${it.path}|\$(cat ${it.path} 2>/dev/null)\""
        }
        val out = su(script)
        val found = HashMap<String, String>()
        for (line in out.lines()) {
            val i = line.indexOf('|')
            if (i > 0) found[line.substring(0, i).trim()] = line.substring(i + 1).trim()
        }
        return candidates.filter { found.containsKey(it.path) }.map { Detected(it, found[it.path] ?: "") }
    }

    fun readNodeValue(path: String): String {
        if (!PATH_RE.matches(path)) return ""
        return su("cat $path 2>/dev/null")
    }

    fun readStatus(c: Context): Status {
        val i = c.applicationContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val pct = if (level >= 0 && scale > 0) level * 100 / scale else -1
        val bm = c.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val raw = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val ma = if (raw == Int.MIN_VALUE || raw == 0) null
        else kotlin.math.abs(raw).let { if (it > 20000) it / 1000 else it }
        return Status(
            level = pct,
            plugged = i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0,
            statusCode = i?.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
                ?: BatteryManager.BATTERY_STATUS_UNKNOWN,
            currentMa = ma,
            tempC = (i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10f
        )
    }

    fun isPlugged(c: Context): Boolean = readStatus(c).plugged != 0

    // ------------------------------------------------------------------ switching

    private fun writeNode(path: String, value: String): Boolean =
        su("echo \"$value\" > $path; echo rc=\$?").lines().lastOrNull()?.trim() == "rc=0"

    /**
     * Turns bypass on or off. Returns null on success or a short error message
     * (shown by the Game Assistant tile and the settings screen).
     */
    fun setEnabled(c: Context, on: Boolean): String? {
        val app = c.applicationContext
        var node = currentNode(app)
        if (node == null) {
            node = detect().firstOrNull()?.node ?: return MSG_NO_NODE
            saveNode(app, node)
        }
        if (on && !isPlugged(app)) return MSG_PLUG_FIRST
        if (!writeNode(node.path, if (on) node.bypass else node.normal)) return MSG_WRITE_FAILED
        prefs(app).edit().putBoolean(KEY_ENABLED, on).apply()
        syncService(app, on)
        return null
    }

    /** Resumes normal charging (used by the safety service). */
    fun disableNow(c: Context) {
        val app = c.applicationContext
        currentNode(app)?.let { writeNode(it.path, it.normal) }
        prefs(app).edit().putBoolean(KEY_ENABLED, false).apply()
    }

    private fun syncService(app: Context, on: Boolean) {
        val intent = Intent(app, BypassService::class.java)
        try {
            if (on) ContextCompat.startForegroundService(app, intent) else app.stopService(intent)
        } catch (e: Exception) {
            // Bypass still works without the safety watcher; it just cannot auto-restore charging.
        }
    }
}
