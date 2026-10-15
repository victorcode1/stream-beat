import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/data/custom_station.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/presentation/controllers/radio_favorites_controller.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

Future<void> showAddStationDialog(BuildContext context, WidgetRef ref) async {
  final station = await showDialog<RadioStation>(
    context: context,
    builder: (_) => const _AddStationDialog(),
  );
  if (station == null || !context.mounted) return;
  try {
    await ref.read(radioFavoritesControllerProvider.notifier).toggle(station);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(LocaleKeys.station_save_error.tr())),
      );
    }
  }
}

class _AddStationDialog extends StatefulWidget {
  const _AddStationDialog();

  @override
  State<_AddStationDialog> createState() => _AddStationDialogState();
}

class _AddStationDialogState extends State<_AddStationDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _stream = TextEditingController();
  final _website = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _stream.dispose();
    _website.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value, {bool optional = false}) {
    if (optional && (value ?? '').trim().isEmpty) return null;
    return stationWebUri(value ?? '') == null
        ? LocaleKeys.station_invalid_url.tr()
        : null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      createCustomStation(
        name: _name.text,
        streamUrl: _stream.text,
        homepage: _website.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(LocaleKeys.station_add.tr()),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: LocaleKeys.station_name.tr(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? LocaleKeys.station_name_required.tr()
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stream,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: LocaleKeys.station_stream_url.tr(),
                ),
                validator: _validateUrl,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _website,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: LocaleKeys.station_optional_website.tr(),
                ),
                validator: (value) => _validateUrl(value, optional: true),
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(LocaleKeys.cancel.tr()),
      ),
      FilledButton(onPressed: _save, child: Text(LocaleKeys.station_add.tr())),
    ],
  );
}
