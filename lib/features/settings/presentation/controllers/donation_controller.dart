import 'package:url_launcher/url_launcher.dart';

/// Abre el apoyo voluntario de StreamBeat Music fuera de la aplicación.
class DonationController {
  const DonationController();

  static final donationUri = Uri.https('ko-fi.com', '/streambeat');

  Future<bool> openDonationPage() async {
    try {
      return await launchUrl(donationUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
