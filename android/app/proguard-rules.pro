# Room crea esta base de WorkManager por reflexión. R8 debe conservar su
# constructor incluso cuando ninguna llamada directa lo utiliza.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

# flutter_local_notifications guarda las notificaciones programadas con Gson.
# R8 elimina las firmas genéricas que necesita TypeToken y, sin estas reglas,
# programar o cancelar notificaciones falla solo en release.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
