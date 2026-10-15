import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/data/custom_station.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/station_removal_contact.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openStationLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Missing mail clients and browser handlers get the same visible feedback.
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(LocaleKeys.developer_contact_error.tr())),
    );
  }
}

Future<void> requestStationRemoval(
  BuildContext context, [
  RadioStation? station,
]) => openStationLink(
  context,
  buildStationRemovalMailto(
    station: station,
    subject: LocaleKeys.station_removal_subject.tr(),
    bodyTemplate: LocaleKeys.station_removal_body.tr(),
  ),
);

class StationLinks extends StatelessWidget {
  const StationLinks({super.key, required this.station});
  final RadioStation station;

  @override
  Widget build(BuildContext context) {
    final homepage = stationWebUri(station.homepage);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (homepage != null)
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded),
            title: Text(LocaleKeys.station_website.tr()),
            onTap: () => openStationLink(context, homepage),
          ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(LocaleKeys.station_report_removal.tr()),
          onTap: () => requestStationRemoval(context, station),
        ),
      ],
    );
  }
}

class StationActionsMenu extends StatelessWidget {
  const StationActionsMenu({super.key, required this.station});
  final RadioStation station;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: LocaleKeys.menu.tr(),
    onSelected: (action) => handleStationLinkAction(context, station, action),
    itemBuilder: (_) => stationLinkMenuItems(station),
  );
}

List<PopupMenuEntry<String>> stationLinkMenuItems(RadioStation station) => [
  if (stationWebUri(station.homepage) != null)
    PopupMenuItem(
      value: 'website',
      child: Text(LocaleKeys.station_website.tr()),
    ),
  PopupMenuItem(
    value: 'report',
    child: Text(LocaleKeys.station_report_removal.tr()),
  ),
];

void handleStationLinkAction(
  BuildContext context,
  RadioStation station,
  String action,
) {
  if (action == 'report') {
    requestStationRemoval(context, station);
  } else if (action == 'website') {
    final homepage = stationWebUri(station.homepage);
    if (homepage != null) openStationLink(context, homepage);
  }
}
