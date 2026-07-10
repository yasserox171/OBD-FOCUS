# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_bluetooth_serial
-keep class io.github.edufolly.flutterbluetoothserial.** { *; }

# flutter_local_notifications (gson type tokens)
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Google Sign-In / Drive
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
