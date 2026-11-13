import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/library/presentation/widgets/downloaded_file_actions.dart';
import 'package:flow_music/features/library/data/downloaded_audio.dart';
import 'package:flow_music/features/song/presentation/controllers/audio_download_writer_stub.dart'
    if (dart.library.io) 'package:flow_music/features/song/presentation/controllers/audio_download_writer_io.dart';
import 'package:flow_music/features/song/presentation/controllers/song_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Enlace publico de una cancion de YouTube.
String youtubeShareLink(String videoId) => 'https://youtu.be/$videoId';

/// Hoja para compartir lo que suena: el enlace de YouTube o, si la cancion ya
/// esta en el dispositivo, el propio archivo de audio.
Future<void> showShareSongSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final controller = ref.read(songController);
  final videoId = controller.currentVideoId ?? '';
  final messenger = ScaffoldMessenger.maybeOf(context);

  if (videoId.isEmpty) {
    messenger?.showSnackBar(
      SnackBar(content: Text(LocaleKeys.download_no_song.tr())),
    );
    return;
  }

  final title = controller.displayTitle ?? '';
  final author = controller.displayAuthor ?? '';
  // El archivo local puede venir de "guardar offline" o de una descarga de
  // audio; en modo video tambien sirve la copia de audio ya descargada.
  final localAudio =
      controller.currentOfflineAudio ?? controller.currentDownloadedAudio;
  final shareableFile = localAudio == null || localAudio.isVideo
      ? null
      : localAudio;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  LocaleKeys.share_song.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    author.isEmpty ? title : '$title · $author',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(LocaleKeys.share_youtube_link.tr()),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await shareYoutubeLink(
                    context: context,
                    videoId: videoId,
                    title: title,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy_rounded),
                title: Text(LocaleKeys.copy_link.tr()),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(
                    ClipboardData(text: youtubeShareLink(videoId)),
                  );
                  messenger?.showSnackBar(
                    SnackBar(content: Text(LocaleKeys.link_copied.tr())),
                  );
                },
              ),
              _ShareAudioFileTile(
                videoId: videoId,
                localAudio: shareableFile,
                onReady: (audio) async {
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
                  await shareDownloadedFile(context: context, audio: audio);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// Opcion "Compartir archivo de audio". Si la cancion no esta en el
/// dispositivo, la descarga primero mostrando el progreso y, al terminar,
/// entrega el archivo a [onReady] para abrir la hoja de compartir.
class _ShareAudioFileTile extends ConsumerStatefulWidget {
  const _ShareAudioFileTile({
    required this.videoId,
    required this.localAudio,
    required this.onReady,
  });

  final String videoId;
  final DownloadedAudio? localAudio;
  final Future<void> Function(DownloadedAudio audio) onReady;

  @override
  ConsumerState<_ShareAudioFileTile> createState() =>
      _ShareAudioFileTileState();
}

class _ShareAudioFileTileState extends ConsumerState<_ShareAudioFileTile> {
  bool _downloading = false;

  Future<void> _shareOrDownload() async {
    final ready = widget.localAudio;
    if (ready != null) return widget.onReady(ready);

    final controller = ref.read(songController);
    if (controller.isDownloading) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(LocaleKeys.share_audio_download_busy.tr())),
      );
      return;
    }

    setState(() => _downloading = true);
    final path = await controller.downloadAudio(id: widget.videoId);
    final audio = path == null
        ? null
        : await getDownloadedAudio(widget.videoId);
    if (mounted) setState(() => _downloading = false);
    // Aunque el usuario haya cerrado la hoja, la descarga sigue y al
    // terminar se abre igual la opcion de compartir.
    if (audio != null) await widget.onReady(audio);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(
      songController.select((c) => c.downloadProgress),
    );

    return ListTile(
      enabled: !kIsWeb && !_downloading,
      leading: _downloading
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.audio_file_rounded),
      title: Text(LocaleKeys.share_audio_file.tr()),
      subtitle: _subtitle(progress),
      onTap: kIsWeb ? null : _shareOrDownload,
    );
  }

  Widget? _subtitle(double progress) {
    if (kIsWeb) return Text(LocaleKeys.share_unavailable.tr());
    if (_downloading) {
      final percent = (progress * 100).clamp(0, 100).round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LocaleKeys.downloading_progress.tr(args: ['$percent'])),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress > 0 ? progress : null),
        ],
      );
    }
    if (widget.localAudio == null) {
      return Text(LocaleKeys.share_audio_needs_download.tr());
    }
    return null;
  }
}

/// Comparte el enlace de YouTube de [videoId] por la hoja del sistema.
Future<void> shareYoutubeLink({
  required BuildContext context,
  required String videoId,
  String title = '',
}) async {
  if (videoId.isEmpty) return;

  final link = youtubeShareLink(videoId);
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: title.isEmpty ? link : '$title\n$link',
      subject: title.isEmpty ? null : title,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    ),
  );
}
