# Flutter ProGuard Rules

# Firebase & Google Play Services Rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# Keep plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# For Crashlytics stack traces
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Flutter Engine keep rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Ignore missing Play Core deferred component references in Flutter Engine
-dontwarn com.google.android.play.core.**
