import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/features/account/application/library_export.dart';
import 'package:flow_music/features/account/presentation/providers/local_user_data_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class LocalLibraryTools extends ConsumerStatefulWidget {
  const LocalLibraryTools({super.key});

  @override
  ConsumerState<LocalLibraryTools> createState() => _LocalLibraryToolsState();
}

class _LocalLibraryToolsState extends ConsumerState<LocalLibraryTools> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('export-local-library'),
    onPressed: _busy ? null : _export,
    icon: const Icon(Icons.file_download_outlined),
    label: Text('library_export_local'.tr()),
  );

  Future<void> _export() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('library_export_title'.tr()),
        content: Text('library_export_privacy'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('library_export_continue'.tr()),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final snapshot = await ref
          .read(localUserDataCoordinatorProvider)
          .readCurrentUser();
      if (!mounted) return;
      final renderBox = context.findRenderObject();
      final origin = renderBox is RenderBox && renderBox.hasSize
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              LibraryExport.encode(snapshot),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: [
            'streambeat-library-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.json',
          ],
          sharePositionOrigin: origin,
        ),
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        _message('library_export_failed'.tr());
      }
    } catch (_) {
      if (mounted) _message('library_export_failed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
