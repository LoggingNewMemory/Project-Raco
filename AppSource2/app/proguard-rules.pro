# =====================================================================
# Project Raco - ProGuard / R8 Rules
# RacoSec obfuscation is CRITICAL - do NOT relax these rules.
# =====================================================================

# ── Keep essential Android framework classes ──────────────────────────
-keepattributes Exceptions,InnerClasses,Signature

# ── Obfuscate everything by default ───────────────────────────────────
# (R8 full mode handles this; these just reinforce it)
-allowaccessmodification
-overloadaggressively
-repackageclasses 'r'
-flattenpackagehierarchy

# ── RacoSec Security Package ──────────────────────────────────────────

# ── Aggressive string encryption (R8 will handle via -optimizations) ──
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 7

# ── Rename source file attributes to hide structure ───────────────────
-renamesourcefileattribute X
-keepattributes SourceFile,LineNumberTable

# ── Strip logging in release ──────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    # Keep e() and w() so errors still surface if needed
}

# ── Compose & Kotlin internals ────────────────────────────────────────
-keepclassmembers class * extends androidx.lifecycle.ViewModel {
    <init>();
}
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ── Coil ──────────────────────────────────────────────────────────────
-dontwarn coil.**

# ── JSON (used in RacoSec API calls) ─────────────────────────────────
-keep class org.json.** { *; }

# ── Prevent reflection-based attacks from reconstructing class tree ───
-keepattributes !LocalVariableTable,!LocalVariableTypeTable

# ── Remove debug info strings ─────────────────────────────────────────
-dontusemixedcaseclassnames