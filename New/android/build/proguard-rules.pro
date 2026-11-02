
# Godot Engine Core (Added by Poing Godot AdMob Plugin for R8 optimization)
-keep class org.godotengine.** { *; }
-keepclassmembers class org.godotengine.** { *; }
-keep class com.godot.** { *; }
-keepclassmembers class com.godot.** { *; }
-keep class * extends org.godotengine.godot.plugin.GodotPlugin { *; }
-keepclassmembers class * extends org.godotengine.godot.plugin.GodotPlugin {
	@org.godotengine.godot.plugin.UsedByGodot <methods>;
}
-keepclasseswithmembernames class * {
	native <methods>;
}
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service

# Suppress harmless warnings from Kotlin metadata and optional mediation dependencies
-dontwarn kotlin.Metadata
-dontwarn com.android.billingclient.**
-dontwarn com.bytedance.sdk.**
-dontwarn com.tiktok.**
-dontwarn jp.maio.sdk.**
-dontwarn ru.ok.tracer.**
