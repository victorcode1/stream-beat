import 'package:flutter/material.dart';

import 'artist_songs_sheet.dart';

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
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: () => showArtistSongs(context, artist),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style,
        ),
      ),
    ),
  );
}
