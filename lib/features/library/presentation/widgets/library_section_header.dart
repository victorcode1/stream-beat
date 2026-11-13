import 'package:flow_music/features/home/presentation/widgets/home_mobile_sections.dart';
import 'package:flutter/material.dart';

/// Titulo de seccion de la Biblioteca. Usa el mismo encabezado que el Inicio
/// para que cada estilo visual (franjas Mola, bandas Carteles...) se repita.
class LibrarySectionHeader extends StatelessWidget {
  const LibrarySectionHeader({
    super.key,
    required this.title,
    this.index = 0,
    this.trailing,
  });

  final String title;

  /// Posicion de la seccion; elige el color de su tela.
  final int index;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return HomeSectionHeader(title: title, index: index, trailing: trailing);
  }
}
