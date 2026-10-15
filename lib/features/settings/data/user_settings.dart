/// DTO de los ajustes que la app guarda localmente en el dispositivo.
class UserSettings {
  const UserSettings({
    this.themeMode,
    this.locale,
    this.autoplayEnabled,
    this.defaultPlaybackMode,
    this.repeatEnabled,
    this.smoothTransitions,
    this.updatedAtMs,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      themeMode: json['themeMode'] as String?,
      locale: json['locale'] as String?,
      autoplayEnabled: json['autoplayEnabled'] as bool?,
      defaultPlaybackMode: json['defaultPlaybackMode'] as String?,
      repeatEnabled: json['repeatEnabled'] as bool?,
      smoothTransitions: json['smoothTransitions'] as bool?,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt(),
    );
  }

  /// `system` | `light` | `dark`.
  final String? themeMode;

  /// Codigo ISO del idioma activo, p.ej. `es` o `en`.
  final String? locale;

  final bool? autoplayEnabled;
  final String? defaultPlaybackMode;
  final bool? repeatEnabled;
  final bool? smoothTransitions;

  /// Marca de tiempo en ms desde epoch del momento en que se guardo este
  /// ajuste en el dispositivo.
  final int? updatedAtMs;

  bool get isEmpty {
    return themeMode == null &&
        locale == null &&
        autoplayEnabled == null &&
        defaultPlaybackMode == null &&
        repeatEnabled == null &&
        smoothTransitions == null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (themeMode != null) 'themeMode': themeMode,
      if (locale != null) 'locale': locale,
      if (autoplayEnabled != null) 'autoplayEnabled': autoplayEnabled,
      if (defaultPlaybackMode != null)
        'defaultPlaybackMode': defaultPlaybackMode,
      if (repeatEnabled != null) 'repeatEnabled': repeatEnabled,
      if (smoothTransitions != null) 'smoothTransitions': smoothTransitions,
      'updatedAtMs': updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  UserSettings copyWith({
    String? themeMode,
    String? locale,
    bool? autoplayEnabled,
    String? defaultPlaybackMode,
    bool? repeatEnabled,
    bool? smoothTransitions,
    int? updatedAtMs,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      autoplayEnabled: autoplayEnabled ?? this.autoplayEnabled,
      defaultPlaybackMode: defaultPlaybackMode ?? this.defaultPlaybackMode,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      smoothTransitions: smoothTransitions ?? this.smoothTransitions,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}
