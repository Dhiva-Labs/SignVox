# MediaPipe Tasks' bundled protobuf-lite messages access fields like "platform_"
# via reflection at runtime (GeneratedMessageLite's dynamic field lookup). R8 can't
# see that statically, so without these keeps it renames/strips the fields and
# HandLandmarker init throws "Field platform_ for ... not found" (see PLAN.md P1
# gotchas — hit and fixed during implementation).
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**

# TensorFlow Lite (bundled transitively by MediaPipe Tasks) has similar reflective
# delegate/op-resolver lookups.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# AutoValue-generated option/result classes (BaseOptions, NormalizedLandmark, Category).
-keep @com.google.auto.value.AutoValue class * { *; }
-keep class **$Builder { *; }

# The above keeps stop renaming/stripping, but R8's *optimization* pass (inlining,
# frame merging) still runs on kept methods and broke a different thing: MediaPipe's
# Graph class initializes a Google Flogger logger via FluentLogger.forEnclosingClass(),
# which identifies its caller by walking the live call stack at runtime. R8-optimized
# code changed that stack's shape enough that Flogger threw
# "IllegalStateException: no caller found on the stack for: ..." from Graph.<clinit>,
# wrapped as ExceptionInInitializerError / NoClassDefFoundError on every later use.
# Disabling optimization (shrinking/obfuscation stay on) is the standard fix for this
# class of stack-walking-dependent library under R8 — cheap here since the app's real
# work is native C++/TFLite inference, not JVM bytecode, so losing R8's optimization
# pass has no meaningful runtime cost.
-dontoptimize
