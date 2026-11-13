import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flutter/material.dart';

/// Item visual de estado para la barra de reproduccion actual.
@immutable
class NowPlayingStatusItem {
  final IconData icon;
  final String label;

  const NowPlayingStatusItem({required this.icon, required this.label});
}

/// Estado derivado que la vista de now playing necesita para renderizarse.
@immutable
class NowPlayingDetailsViewState {
  final DownloadedAudio item;
  final String title;
  final String author;
  final bool isDownloaded;
  final bool isOfflineSaved;
  final bool isLoading;
  final bool isFavorite;
  final NowPlayingStatusItem? transferStatus;
  final List<NowPlayingStatusItem> statusItems;

  const NowPlayingDetailsViewState({
    required this.item,
    required this.title,
    required this.author,
    required this.isDownloaded,
    required this.isOfflineSaved,
    required this.isLoading,
    required this.isFavorite,
    required this.transferStatus,
    required this.statusItems,
  });

  factory NowPlayingDetailsViewState.fromPlayback({
    required DownloadedAudio item,
    required bool isDownloaded,
    required bool isOfflineSaved,
    required bool isLoading,
    required bool isDownloading,
    required bool isSavingOffline,
    required double downloadProgress,
    required double offlineProgress,
    required bool isFavorite,
  }) {
    final transferStatus = _buildTransferStatus(
      isDownloading: isDownloading,
      isSavingOffline: isSavingOffline,
      downloadProgress: downloadProgress,
      offlineProgress: offlineProgress,
    );

    return NowPlayingDetailsViewState(
      item: item,
      title: item.title.trim().isEmpty ? LocaleKeys.playing.tr() : item.title,
      author: item.author.trim(),
      isDownloaded: isDownloaded,
      isOfflineSaved: isOfflineSaved,
      isLoading: isLoading || isDownloading || isSavingOffline,
      isFavorite: isFavorite,
      transferStatus: transferStatus,
      // El modo audio/video ya se ve en el boton de video de la barra.
      statusItems: [
        if (isOfflineSaved)
          NowPlayingStatusItem(
            icon: Icons.offline_pin_rounded,
            label: LocaleKeys.offline_available.tr(),
          )
        else if (isDownloaded)
          NowPlayingStatusItem(
            icon: Icons.download_done_rounded,
            label: LocaleKeys.smart_downloaded.tr(),
          ),
      ],
    );
  }

  static NowPlayingStatusItem? _buildTransferStatus({
    required bool isDownloading,
    required bool isSavingOffline,
    required double downloadProgress,
    required double offlineProgress,
  }) {
    if (isDownloading) {
      final percent = (downloadProgress.clamp(0, 1) * 100).round();
      return NowPlayingStatusItem(
        icon: Icons.downloading_rounded,
        label: LocaleKeys.downloading_progress.tr(args: [percent.toString()]),
      );
    }
    if (isSavingOffline) {
      final percent = (offlineProgress.clamp(0, 1) * 100).round();
      return NowPlayingStatusItem(
        icon: Icons.offline_bolt_rounded,
        label: LocaleKeys.offline_saving_progress.tr(
          args: [percent.toString()],
        ),
      );
    }
    return null;
  }
}
