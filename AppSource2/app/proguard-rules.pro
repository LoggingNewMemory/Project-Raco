# =====================================================================
# Project Raco - ProGuard / R8 Rules
# =====================================================================

# ── Attributes ────────────────────────────────────────────────────────
# Keep essentials for Compose/Kotlin, but drop variable tables to save size
-keepattributes Exceptions,InnerClasses,Signature,*Annotation*,SourceFile,LineNumberTable

# ── Aggressive Size Optimizations (Safe) ──────────────────────────────
-allowaccessmodification
-overloadaggressively
-repackageclasses 'r'
-flattenpackagehierarchy
-mergeinterfacesaggressively
-optimizationpasses 5

# ── Strip all logging in release to minimize size ─────────────────────
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
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