# -----------------------------------------------------------------------
# Viva Matrimony — ProGuard / R8 rules
# -----------------------------------------------------------------------

# --- Crashlytics: preserve source file names and line numbers -----------
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
# Rename obfuscated classes in stack traces
-renamesourcefileattribute SourceFile

# --- Kotlin serialization (used by Supabase / ktor) --------------------
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class com.vivamatrimony.**$$serializer { *; }
-keepclassmembers class com.vivamatrimony.** {
    *** Companion;
}
-keepclasseswithmembers class com.vivamatrimony.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# --- Supabase / Realtime (Ktor + OkHttp) -------------------------------
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# --- Firebase Core & Crashlytics ---------------------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Flutter plugin JNI entry points -----------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Gson (used by some Flutter plugins) -------------------------------
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# --- App model / data classes ------------------------------------------
# Keep all data classes in the app package so Supabase JSON
# deserialization survives R8 shrinking.
-keep class com.vivamatrimony.viva_app.** { *; }

# --- Flutter Play Core (deferred components — not used by this app) ----
# R8 sees references to these classes from Flutter's embedding layer but
# the Play Core split-install library isn't on the classpath. Safe to
# suppress because this app doesn't use deferred components.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
