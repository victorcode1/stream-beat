import 'package:flow_music/features/search/presentation/pages/list_search.dart';
import 'package:flutter/material.dart';

Future<void> showArtistSongs(BuildContext context, String artist) async {
  final query = artist.trim();
  if (query.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    query,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                CloseButton(onPressed: () => Navigator.of(sheetContext).pop()),
              ],
            ),
          ),
          Expanded(
            child: SuggestedListSearch(searchQuery: query, playInPlace: true),
          ),
        ],
      ),
    ),
  );
}
