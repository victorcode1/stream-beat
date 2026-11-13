# R8 de AGP 9 elimina las clases que Room y WorkManager crean por reflexion;
# sin ellas la app se cierra al abrir ("Failed to create an instance of
# androidx.work.impl.WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-keep class androidx.startup.** { *; }
