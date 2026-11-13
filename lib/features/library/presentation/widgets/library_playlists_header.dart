import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/presentation/widgets/library_section_header.dart';
import 'package:flutter/material.dart';

class LibraryPlaylistsHeader extends StatelessWidget {
  const LibraryPlaylistsHeader({
    super.key,
    required this.onCreate,
    required this.onImport,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return LibrarySectionHeader(
      title: LocaleKeys.playlists.tr(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            tooltip: LocaleKeys.new_playlist.tr(),
          ),
          IconButton(
            onPressed: onImport,
            icon: const Icon(Icons.file_upload_rounded),
            tooltip: LocaleKeys.import_playlist.tr(),
          ),
        ],
      ),
    );
  }
}
