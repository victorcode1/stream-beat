import 'package:flutter/material.dart';

import 'artist_songs_sheet.dart';

/// Nombre del artista que abre la hoja con sus canciones.
///
/// El chevron al final, del mismo color que el texto, es la señal de que el
/// nombre lleva a otra parte (convencion de Apple Music y Spotify) sin
/// competir con el titulo.
class ArtistNameButton extends StatelessWidget {
  const ArtistNameButton({
    super.key,
    required this.artist,
    this.style,
    this.textAlign,
  });

  final String artist;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = effective.fontSize ?? 14;

    return Semantics(
      button: true,
      label: artist,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showArtistSongs(context, artist),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: textAlign,
                  style: style,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: fontSize * 1.25,
                color: effective.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
