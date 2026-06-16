-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.** { *; }

-dontwarn com.google.auto.value.**
-keep class com.google.auto.value.** { *; }

# Play Core split install (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# javax.lang.model (referenced by errorprone annotations)
-dontwarn javax.lang.model.**
-keep class javax.lang.model.** { *; }

-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
-dontwarn java.awt.**
