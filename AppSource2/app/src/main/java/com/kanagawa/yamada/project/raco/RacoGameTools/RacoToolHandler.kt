package com.kanagawa.yamada.project.raco.RacoGameTools

import android.content.Context
import android.content.Intent

object RacoToolHandler {
    
    /**
     * Restores previously enabled gaming tools.
     * This is designed to be called after entrance animations or other blocking flows complete,
     * so you don't have to rewrite this restoration logic repeatedly across the app.
     */
    fun restoreSavedTools(context: Context) {
        val prefs = context.getSharedPreferences("raco_slingshot_prefs", Context.MODE_PRIVATE)
        
        // 1. Crosshair
        if (prefs.getBoolean("is_crosshair_enabled", false)) {
            context.startService(Intent(context, GameCrosshairService::class.java))
        }
        
        // 2. Aux Line
        if (prefs.getBoolean("is_auxline_enabled", false)) {
            context.startService(Intent(context, GameAuxLineService::class.java))
        }
        
        // 3. Ayunda Visual Filters
        if (prefs.getBoolean("is_ayunda_enabled", false)) {
            val filterName = prefs.getString("ayunda_filter", "NORMAL") ?: "NORMAL"
            Thread {
                try {
                    val cmd = java.lang.StringBuilder()
                    cmd.append("settings put secure accessibility_display_inversion_enabled ${if (filterName == "INVERT") 1 else 0}; ")
                    cmd.append("settings put secure accessibility_display_daltonizer_enabled 0; ")
                    val saturation = when(filterName) {
                        "VIVID" -> 1.5f
                        "VIVID_MAX" -> 2.0f
                        "GRAYSCALE" -> 0.0f
                        else -> 1.0f
                    }
                    cmd.append("service call SurfaceFlinger 1022 f $saturation; ")
                    val matrix = when(filterName) {
                        "EAGLE_EYE" -> "f 1.2 f 0.0 f 0.0 f 0.0 f 0.0 f 1.2 f 0.0 f 0.0 f 0.0 f 0.0 f 0.8 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                        "NIGHT_VISION" -> "f 0.3 f 0.0 f 0.0 f 0.0 f 0.0 f 1.5 f 0.0 f 0.0 f 0.0 f 0.0 f 0.3 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                        "WARM" -> "f 1.0 f 0.0 f 0.0 f 0.0 f 0.0 f 0.9 f 0.0 f 0.0 f 0.0 f 0.0 f 0.6 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                        "CINEMATIC" -> "f 0.9 f 0.0 f 0.0 f 0.0 f 0.0 f 0.9 f 0.0 f 0.0 f 0.0 f 0.0 f 1.2 f 0.0 f 0.0 f 0.0 f 0.0 f 1.0"
                        else -> null
                    }
                    if (matrix != null) {
                        cmd.append("service call SurfaceFlinger 1015 i32 1 $matrix")
                    } else if (filterName != "INVERT") {
                        cmd.append("service call SurfaceFlinger 1015 i32 0")
                    }
                    Runtime.getRuntime().exec(arrayOf("su", "-c", cmd.toString())).waitFor()
                } catch (e: Exception) {}
            }.start()
        }
    }
}
