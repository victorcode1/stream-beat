import 'package:flutter/material.dart';

/// Aviso de seccion vacia: discreto, sin tarjeta, para que no compita con el
/// contenido real de la Biblioteca.
class LibraryEmptyCard extends StatelessWidget {
  const LibraryEmptyCard({
    super.key,
    required this.icon,
    required this.message,
    required this.colors,
    this.minHeight = 0,
  });

  final IconData icon;
  final String message;
  final ColorScheme colors;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 24, color: colors.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
