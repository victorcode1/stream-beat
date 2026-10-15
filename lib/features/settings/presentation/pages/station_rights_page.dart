import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/presentation/widgets/station_links.dart';
import 'package:flutter/material.dart';

void openStationRights(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const StationRightsPage()));

class StationRightsEntry extends StatelessWidget {
  const StationRightsEntry({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.policy_outlined),
      title: Text(LocaleKeys.station_rights_title.tr()),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => openStationRights(context),
    ),
  );
}

class StationDirectoryAttribution extends StatelessWidget {
  const StationDirectoryAttribution({super.key});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => openStationRights(context),
    child: Text(
      LocaleKeys.station_directory_attribution.tr(),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class StationRightsPage extends StatelessWidget {
  const StationRightsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(LocaleKeys.station_rights_title.tr())),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(LocaleKeys.station_rights_directory.tr()),
            TextButton.icon(
              onPressed: () => openStationLink(
                context,
                Uri.parse('https://www.radio-browser.info/'),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Radio Browser'),
            ),
            const SizedBox(height: 16),
            Text(LocaleKeys.station_rights_streams.tr()),
            const SizedBox(height: 16),
            Text(LocaleKeys.station_rights_owners.tr()),
            const SizedBox(height: 16),
            Text(LocaleKeys.station_rights_removal.tr()),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => requestStationRemoval(context),
              icon: const Icon(Icons.mail_outline_rounded),
              label: Text(LocaleKeys.station_report_removal.tr()),
            ),
            TextButton.icon(
              onPressed: () => openStationLink(
                context,
                Uri.parse(
                  'https://victorcode1.github.io/stream-beat/broadcasters/',
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(LocaleKeys.station_broadcasters.tr()),
            ),
          ],
        ),
      ),
    ),
  );
}
