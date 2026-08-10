# Keep rules for the release build, where R8 shrinks and renames code.
#
# flutter_local_notifications stores scheduled alarms as JSON and reads them
# back with Gson, using a TypeToken to recover the element type of a
# List<NotificationDetails>. R8 strips generic signatures by default, so the
# TypeToken comes back raw and the plugin throws
#
#   java.lang.IllegalArgumentException: Missing type parameter.
#
# on the first cancel() or reschedule — which for this app is the moment a
# reminder is saved. Debug builds are unaffected because they are not
# minified, so this only ever shows up in a release APK.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keep class com.dexterous.** { *; }

# Gson's reflective machinery, and any TypeToken subclass, which is exactly
# the generic information being lost above.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# Model classes Gson fills by reflection have no direct callers, so R8 would
# otherwise strip their fields.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
