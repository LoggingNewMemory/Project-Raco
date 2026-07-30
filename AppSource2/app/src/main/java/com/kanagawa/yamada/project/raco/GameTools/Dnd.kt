package com.kanagawa.yamada.project.raco.GameTools

import androidx.compose.runtime.MutableState

object DndTool {
    fun toggle(
        currentPackage: String,
        activeDndState: MutableState<Boolean>,
        sharedPrefs: android.content.SharedPreferences
    ) {
        val newState = !activeDndState.value
        activeDndState.value = newState
        sharedPrefs.edit().putBoolean("dnd_active_$currentPackage", newState).apply()
        
        if (newState) {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd notification set_dnd priority")).waitFor()
        } else {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "cmd notification set_dnd off")).waitFor()
        }
    }
}
