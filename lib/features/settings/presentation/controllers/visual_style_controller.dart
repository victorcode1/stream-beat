import 'package:flow_music/core/theme/visual_style.dart';
import 'package:flow_music/features/account/presentation/providers/local_user_data_providers.dart';
import 'package:flow_music/features/settings/data/settings_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Clave dentro de la caja `settings` de Hive para el estilo elegido.
const String _visualStyleKey = 'visual_style';

/// Estilo que se usa mientras el usuario no elija otro.
const VisualStyle defaultVisualStyle = VisualStyle.mola;

/// Estilo visual activo, elegido en Ajustes y guardado en el telefono.
final visualStyleControllerProvider =
    NotifierProvider<VisualStyleController, VisualStyle>(
      VisualStyleController.new,
    );

class VisualStyleController extends Notifier<VisualStyle> {
  @override
  VisualStyle build() {
    ref.watch(localUserDataRevisionProvider);
    return decodeVisualStyle(Hive.box(settingsBoxName).get(_visualStyleKey));
  }

  /// Cambia el estilo activo y lo guarda.
  Future<void> setStyle(VisualStyle style) async {
    if (state == style) return;
    // Solo en el telefono: la copia de ajustes de la cuenta guarda campos
    // fijos y el estilo es una preferencia visual local.
    await Hive.box(settingsBoxName).put(_visualStyleKey, style.name);
    state = style;
  }
}

/// Lee el estilo guardado; un valor desconocido vuelve al de por defecto.
VisualStyle decodeVisualStyle(Object? raw) {
  return VisualStyle.values.firstWhere(
    (style) => style.name == raw,
    orElse: () => defaultVisualStyle,
  );
}
