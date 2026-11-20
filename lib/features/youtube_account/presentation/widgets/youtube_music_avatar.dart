import 'package:flow_music/features/youtube_account/data/youtube_music_library_parser.dart';
import 'package:flutter/material.dart';

/// Foto de la cuenta (o su inicial). Sin cuenta, un circulo con un icono de
/// persona que invita a iniciar sesion.
class YouTubeMusicAvatar extends StatelessWidget {
  const YouTubeMusicAvatar({
    super.key,
    required this.size,
    required this.connected,
    required this.account,
  });

  final double size;
  final bool connected;
  final YouTubeMusicAccountInfo? account;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photoUrl = account?.photoUrl ?? '';
    final initial = account?.name.characters.firstOrNull?.toUpperCase();

    if (!connected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainerHighest,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: size * 0.55,
          color: colors.onSurface,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colors.primary,
      foregroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
      onForegroundImageError: photoUrl.isEmpty ? null : (_, _) {},
      child: initial == null
          ? Icon(Icons.person_rounded, size: size * 0.55)
          : Text(
              initial,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}
