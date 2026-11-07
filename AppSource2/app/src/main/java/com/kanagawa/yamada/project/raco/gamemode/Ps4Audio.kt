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

package com.kanagawa.yamada.project.raco.gamemode

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin

/**
 * Sound engine of the Game Mode.
 *
 * All default sounds are ORIGINAL and synthesised on the device the first time they are needed
 * (cached in cacheDir), so the app ships no audio files.
 *
 * You can override any sound with your own file by putting it into res/raw using these names:
 *   ps4_nav, ps4_confirm, ps4_startup, ps4_launch, ps4_mode_eco, ps4_mode_balanced,
 *   ps4_mode_awaken (sound effects) and ps4_bgm (background music).
 * The user can also pick a custom music file from the in-app settings.
 */
object Ps4Audio {
    private const val SR = 22050
    private const val VERSION = "v1"

    private val main = Handler(Looper.getMainLooper())
    private var appCtx: Context? = null
    private var pool: SoundPool? = null
    private val ids = ConcurrentHashMap<String, Int>()
    private val ready = ConcurrentHashMap.newKeySet<Int>()

    private var player: MediaPlayer? = null
    @Volatile private var musicWanted = false
    @Volatile private var preparingMusic = false

    // ---------------------------------------------------------------- init / sfx

    fun init(context: Context) {
        if (appCtx != null) return
        val ctx = context.applicationContext
        appCtx = ctx
        Ps4Settings.init(ctx)

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val sp = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(attrs).build()
        sp.setOnLoadCompleteListener { _, sampleId, status -> if (status == 0) ready.add(sampleId) }
        pool = sp

        Thread {
            try {
                for ((name, gen) in sfxDefs) {
                    val rawId = ctx.resources.getIdentifier("ps4_$name", "raw", ctx.packageName)
                    val id = if (rawId != 0) {
                        sp.load(ctx, rawId, 1)
                    } else {
                        val f = File(ctx.cacheDir, "ps4_${name}_$VERSION.wav")
                        if (!f.exists()) writeWav(f, gen())
                        sp.load(f.absolutePath, 1)
                    }
                    ids[name] = id
                }
            } catch (e: Exception) {
                // sound is optional, never crash because of it
            }
        }.start()
    }

    private fun play(name: String, tries: Int = 12) {
        if (!Ps4Settings.sfxEnabled) return
        val sp = pool ?: return
        val id = ids[name]
        if (id != null && ready.contains(id)) {
            val v = Ps4Settings.volume.coerceIn(0f, 1f)
            try { sp.play(id, v, v, 1, 0, 1f) } catch (e: Exception) {}
        } else if (tries > 0) {
            // still generating / loading the first time: retry shortly
            main.postDelayed({ play(name, tries - 1) }, 150)
        }
    }

    fun playNav() = play("nav", 0)
    fun playConfirm() = play("confirm", 0)
    fun playStartup() = play("startup")
    fun playLaunch() = play("launch")
    fun playMode(modeId: String) = play(
        when (modeId) {
            "2" -> "mode_eco"
            "4", "5" -> "mode_awaken"
            else -> "mode_balanced"
        }
    )

    // ---------------------------------------------------------------- music

    fun startMusic(context: Context) {
        init(context)
        musicWanted = true
        applyMusic()
    }

    fun stopMusic() {
        musicWanted = false
        releasePlayer()
    }

    fun pauseMusic() {
        try { player?.let { if (it.isPlaying) it.pause() } } catch (e: Exception) {}
    }

    fun resumeMusic() {
        if (musicWanted) applyMusic()
    }

    /** Call after the user changed the music source or toggled music on/off. */
    fun refreshMusic() {
        releasePlayer()
        if (musicWanted) applyMusic()
    }

    fun updateVolume() {
        val v = musicVolume()
        try { player?.setVolume(v, v) } catch (e: Exception) {}
    }

    private fun musicVolume() = (Ps4Settings.volume * 0.7f).coerceIn(0f, 1f)

    private fun releasePlayer() {
        val p = player
        player = null
        if (p != null) {
            try { p.stop() } catch (e: Exception) {}
            try { p.release() } catch (e: Exception) {}
        }
    }

    private fun applyMusic() {
        val ctx = appCtx ?: return
        if (!Ps4Settings.musicEnabled || !musicWanted) return
        val existing = player
        if (existing != null) {
            updateVolume()
            try { if (!existing.isPlaying) existing.start() } catch (e: Exception) {}
            return
        }
        if (preparingMusic) return
        preparingMusic = true
        Thread {
            var source: String? = null
            val rawId = ctx.resources.getIdentifier("ps4_bgm", "raw", ctx.packageName)
            val custom = Ps4Settings.customMusicPath
            try {
                if (custom.isNotEmpty() && File(custom).exists()) {
                    source = custom
                } else if (rawId == 0) {
                    val f = File(ctx.cacheDir, "ps4_bgm_$VERSION.wav")
                    if (!f.exists()) writeWav(f, genAmbient())
                    source = f.absolutePath
                }
            } catch (e: Exception) {}
            main.post {
                preparingMusic = false
                if (!musicWanted || player != null || !Ps4Settings.musicEnabled) return@post
                player = buildPlayer(ctx, source, rawId) ?: if (source == custom && custom.isNotEmpty()) {
                    // custom file could not be played: fall back to the built-in ambient
                    buildPlayer(ctx, File(ctx.cacheDir, "ps4_bgm_$VERSION.wav").takeIf { it.exists() }?.absolutePath, rawId)
                } else null
                try { player?.start() } catch (e: Exception) {}
            }
        }.start()
    }

    private fun buildPlayer(ctx: Context, source: String?, rawId: Int): MediaPlayer? {
        return try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            if (source != null) {
                mp.setDataSource(source)
            } else if (rawId != 0) {
                val afd = ctx.resources.openRawResourceFd(rawId)
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            } else {
                mp.release()
                return null
            }
            mp.isLooping = true
            val v = musicVolume()
            mp.setVolume(v, v)
            mp.prepare()
            mp
        } catch (e: Exception) {
            null
        }
    }

    // ---------------------------------------------------------------- synthesis

    private val sfxDefs: List<Pair<String, () -> ShortArray>> = listOf(
        "nav" to { genNav() },
        "confirm" to { genConfirm() },
        "startup" to { genStartup() },
        "launch" to { genLaunch() },
        "mode_eco" to { genModeEco() },
        "mode_balanced" to { genModeBalanced() },
        "mode_awaken" to { genModeAwaken() }
    )

    private fun midi(m: Int): Double = 440.0 * 2.0.pow((m - 69) / 12.0)

    private fun buffer(seconds: Double) = FloatArray((seconds * SR).toInt())

    private fun toPcm(buf: FloatArray, peak: Float = 0.85f): ShortArray {
        var max = 0f
        for (v in buf) max = maxOf(max, abs(v))
        val g = if (max > 0f) peak / max else 1f
        return ShortArray(buf.size) { (buf[it] * g * 32767f).toInt().coerceIn(-32767, 32767).toShort() }
    }

    /** Adds a decaying (optionally gliding) tone to [buf]. */
    private fun addTone(
        buf: FloatArray, startSec: Double, dur: Double, f0: Double, f1: Double,
        amp: Double, attack: Double, tau: Double, h2: Double = 0.0
    ) {
        val s0 = (startSec * SR).toInt()
        val n = (dur * SR).toInt()
        var phase = 0.0
        for (i in 0 until n) {
            val idx = s0 + i
            if (idx >= buf.size) break
            val t = i.toDouble() / SR
            val f = f0 + (f1 - f0) * (t / dur)
            phase += 2.0 * PI * f / SR
            val env = (if (t < attack) t / attack else 1.0) * exp(-t / tau)
            buf[idx] += (amp * env * (sin(phase) + h2 * sin(2.0 * phase))).toFloat()
        }
    }

    private fun genNav(): ShortArray {
        val b = buffer(0.12)
        addTone(b, 0.0, 0.11, 1500.0, 1100.0, 0.5, 0.002, 0.03)
        return toPcm(b, 0.55f)
    }

    private fun genConfirm(): ShortArray {
        val b = buffer(0.9)
        addTone(b, 0.0, 0.8, 1318.5, 1318.5, 0.5, 0.003, 0.16, 0.3)
        addTone(b, 0.08, 0.8, 1975.5, 1975.5, 0.4, 0.003, 0.2, 0.3)
        return toPcm(b, 0.7f)
    }

    private fun genStartup(): ShortArray {
        val b = buffer(3.2)
        // soft swelling pad: Dmaj9
        for (m in intArrayOf(50, 57, 62, 66, 69)) {
            addTone(b, 0.0, 3.0, midi(m), midi(m), 0.2, 0.9, 1.5, 0.2)
        }
        // sparkles
        addTone(b, 0.9, 1.6, midi(86), midi(86), 0.25, 0.004, 0.45, 0.3)
        addTone(b, 1.25, 1.6, midi(90), midi(90), 0.2, 0.004, 0.45, 0.3)
        addTone(b, 1.6, 1.6, midi(93), midi(93), 0.18, 0.004, 0.5, 0.3)
        return toPcm(b, 0.75f)
    }

    private fun genLaunch(): ShortArray {
        val b = buffer(2.4)
        addTone(b, 0.0, 1.5, 220.0, 1760.0, 0.35, 0.3, 2.0, 0.25)
        addTone(b, 0.0, 1.5, 330.0, 2640.0, 0.18, 0.4, 2.0, 0.2)
        addTone(b, 1.35, 1.0, midi(96), midi(96), 0.4, 0.002, 0.3, 0.3)
        addTone(b, 1.4, 1.0, midi(84), midi(84), 0.3, 0.002, 0.4, 0.3)
        return toPcm(b, 0.8f)
    }

    private fun genModeEco(): ShortArray {
        val b = buffer(0.9)
        addTone(b, 0.0, 0.8, 880.0, 440.0, 0.45, 0.01, 0.28, 0.2)
        addTone(b, 0.1, 0.7, 660.0, 330.0, 0.25, 0.01, 0.25, 0.2)
        return toPcm(b, 0.7f)
    }

    private fun genModeBalanced(): ShortArray {
        val b = buffer(0.9)
        addTone(b, 0.0, 0.5, 660.0, 660.0, 0.4, 0.005, 0.12, 0.25)
        addTone(b, 0.14, 0.7, 880.0, 880.0, 0.4, 0.005, 0.18, 0.25)
        return toPcm(b, 0.7f)
    }

    private fun genModeAwaken(): ShortArray {
        val b = buffer(1.3)
        addTone(b, 0.0, 0.6, 330.0, 1320.0, 0.4, 0.01, 0.4, 0.3)
        addTone(b, 0.0, 0.6, 495.0, 1980.0, 0.2, 0.01, 0.4, 0.3)
        addTone(b, 0.32, 0.9, 1760.0, 1760.0, 0.4, 0.003, 0.25, 0.4)
        return toPcm(b, 0.8f)
    }

    /**
     * 32 second seamless ambient pad loop (Dmaj9 - Bm7 - Gmaj7 - Asus).
     * Four overlapping Hann windows sum to a constant, and every sparkle is written circularly,
     * so the loop point is inaudible.
     */
    private fun genAmbient(): ShortArray {
        val total = 32.0
        val n = (total * SR).toInt()
        val buf = FloatArray(n)
        val chords = arrayOf(
            intArrayOf(38, 57, 61, 64, 66),
            intArrayOf(47, 59, 62, 66, 69),
            intArrayOf(43, 59, 62, 66, 71),
            intArrayOf(45, 57, 62, 64, 67)
        )
        val half = 8.0
        for (k in chords.indices) {
            val center = 4.0 + 8.0 * k
            val freqs = chords[k].map { midi(it) }
            for (i in 0 until n) {
                val t = i.toDouble() / SR
                var d = t - center
                if (d > total / 2) d -= total
                if (d < -total / 2) d += total
                if (abs(d) >= half) continue
                val w = 0.5 * (1.0 + cos(PI * d / half))
                var s = 0.0
                for ((vi, f) in freqs.withIndex()) {
                    val lfo = 0.75 + 0.25 * sin(2.0 * PI * (0.07 + 0.03 * vi) * t + vi)
                    val a = if (vi == 0) 0.9 else 0.5
                    s += a * lfo * (sin(2.0 * PI * f * t) + 0.35 * sin(2.0 * PI * f * 1.003 * t) + 0.12 * sin(4.0 * PI * f * t))
                }
                buf[i] += (w * s).toFloat()
            }
        }
        // sparkles (circular write so they also loop smoothly)
        val notes = intArrayOf(86, 90, 93, 88, 91, 95, 86, 93)
        for ((si, m) in notes.withIndex()) {
            val start = 1.5 + si * 4.0
            val f = midi(m)
            val len = (2.6 * SR).toInt()
            val s0 = (start * SR).toInt()
            for (i in 0 until len) {
                val t = i.toDouble() / SR
                val env = (1.0 - exp(-t / 0.01)) * exp(-t / 0.7)
                val v = (0.16 * env * (sin(2.0 * PI * f * t) + 0.25 * sin(4.0 * PI * f * t))).toFloat()
                buf[(s0 + i) % n] += v
            }
        }
        return toPcm(buf, 0.7f)
    }

    private fun writeWav(f: File, pcm: ShortArray) {
        val dataLen = pcm.size * 2
        val bb = ByteBuffer.allocate(44 + dataLen).order(ByteOrder.LITTLE_ENDIAN)
        bb.put("RIFF".toByteArray())
        bb.putInt(36 + dataLen)
        bb.put("WAVE".toByteArray())
        bb.put("fmt ".toByteArray())
        bb.putInt(16)
        bb.putShort(1)
        bb.putShort(1)
        bb.putInt(SR)
        bb.putInt(SR * 2)
        bb.putShort(2)
        bb.putShort(16)
        bb.put("data".toByteArray())
        bb.putInt(dataLen)
        for (s in pcm) bb.putShort(s)
        val tmp = File(f.parentFile, f.name + ".tmp")
        tmp.writeBytes(bb.array())
        if (!tmp.renameTo(f)) {
            f.writeBytes(bb.array())
            tmp.delete()
        }
    }
}
