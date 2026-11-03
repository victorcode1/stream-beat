# Room crea esta base de WorkManager por reflexión. R8 debe conservar su
# constructor incluso cuando ninguna llamada directa lo utiliza.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
