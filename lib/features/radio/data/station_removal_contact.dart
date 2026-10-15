import 'package:flow_music/core/contact/developer_contact.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';

Uri buildStationRemovalMailto({
  RadioStation? station,
  required String subject,
  required String bodyTemplate,
}) {
  final fields = {
    'name': station?.name ?? '',
    'uuid': station?.stationUuid ?? '',
    'stream': station?.streamUrl ?? '',
    'country': station?.country ?? '',
  };
  final body = bodyTemplate.replaceAllMapped(
    RegExp(r'\{(name|uuid|stream|country)\}'),
    (match) => fields[match.group(1)]!,
  );
  // mailto requires percent-encoded spaces rather than form-style '+' signs.
  final query = {'subject': subject, 'body': body}.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');
  return Uri(scheme: 'mailto', path: developerEmail, query: query);
}
