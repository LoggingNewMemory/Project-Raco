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
# Do NOT keep class names - we want them obfuscated.
# Only protect method signatures that are reflectively checked.
-keepclassmembers class com.kanagawa.yamada.project.raco.security.RacoAntiCrack {
    public static boolean verifySignature(android.content.Context);
    public static boolean isDebuggerAttached();
    public static boolean runAllChecks(android.content.Context, kotlin.jvm.functions.Function1);
}
-keepclassmembers class com.kanagawa.yamada.project.raco.security.RacoSecApi {
    public static * validateKey(java.lang.String, kotlin.coroutines.Continuation);
    public static * registerKey(java.lang.String, java.lang.String, kotlin.coroutines.Continuation);
    public static * verifyDevice(java.lang.String, java.lang.String, kotlin.coroutines.Continuation);
}

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