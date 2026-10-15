import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/contact/developer_contact.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';

const _developerName = 'Victor Flores';
const _developerPhone = '50762395182';
final _developerGitHubUri = Uri.parse('https://github.com/victorcode1');

class DeveloperContactCard extends StatelessWidget {
  const DeveloperContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final details = _DeveloperDetails(theme: theme);
          final actions = _ContactActions(
            onEmail: () => _openEmail(context),
            onGitHub: () => _openUri(context, _developerGitHubUri),
            onTelegram: () => _openTelegram(context),
            onWhatsApp: () => _openWhatsApp(context),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DeveloperAvatar(colors: colors),
                  const SizedBox(width: 16),
                  Expanded(child: details),
                  if (!compact) ...[const SizedBox(width: 24), actions],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                LocaleKeys.developer_contact_invitation.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (compact) ...[const SizedBox(height: 18), actions],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEmail(BuildContext context) async {
    final unavailableMessage = LocaleKeys.developer_email_unavailable.tr();
    final contactErrorMessage = LocaleKeys.developer_contact_error.tr();
    final email = Email(
      subject: LocaleKeys.developer_email_subject.tr(),
      body: LocaleKeys.developer_email_body.tr(),
      recipients: const [developerEmail],
      isHTML: false,
    );
    String? errorMessage;

    try {
      final capabilities = await FlutterEmailSender.getCapabilities();
      if (!capabilities.canSend) {
        errorMessage = unavailableMessage;
      } else {
        await FlutterEmailSender.send(email);
      }
    } on FlutterEmailSenderNotAvailableException {
      errorMessage = unavailableMessage;
    } on FlutterEmailSenderException {
      errorMessage = contactErrorMessage;
    } catch (_) {
      errorMessage = contactErrorMessage;
    }

    if (errorMessage != null && context.mounted) {
      _showContactMessage(context, errorMessage);
    }
  }

  Future<void> _openTelegram(BuildContext context) {
    final telegramUri = Uri.https('t.me', '/+$_developerPhone', {
      'text': LocaleKeys.developer_chat_message.tr(),
    });
    return _openUri(context, telegramUri);
  }

  Future<void> _openWhatsApp(BuildContext context) {
    final whatsAppUri = Uri.https('wa.me', '/$_developerPhone', {
      'text': LocaleKeys.developer_chat_message.tr(),
    });
    return _openUri(context, whatsAppUri);
  }

  Future<void> _openUri(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    final opened = await _tryOpenUri(uri, mode: mode);

    if (!opened && context.mounted) {
      _showContactMessage(context, LocaleKeys.developer_contact_error.tr());
    }
  }

  Future<bool> _tryOpenUri(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  void _showContactMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DeveloperAvatar extends StatelessWidget {
  const _DeveloperAvatar({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Text(
        'VF',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colors.onPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DeveloperDetails extends StatelessWidget {
  const _DeveloperDetails({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.about_developer.tr(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _developerName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          LocaleKeys.developer_role.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              Icons.alternate_email_rounded,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                developerEmail,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({
    required this.onEmail,
    required this.onGitHub,
    required this.onTelegram,
    required this.onWhatsApp,
  });

  final VoidCallback onEmail;
  final VoidCallback onGitHub;
  final VoidCallback onTelegram;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onEmail,
          icon: const Icon(Icons.mail_outline_rounded),
          label: Text(LocaleKeys.contact_me.tr()),
        ),
        OutlinedButton.icon(
          onPressed: onGitHub,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(LocaleKeys.view_github.tr()),
        ),
        OutlinedButton.icon(
          onPressed: onTelegram,
          icon: const Icon(Icons.send_rounded),
          label: Text(LocaleKeys.telegram.tr()),
        ),
        OutlinedButton.icon(
          onPressed: onWhatsApp,
          icon: const Icon(Icons.chat_rounded),
          label: Text(LocaleKeys.whatsapp.tr()),
        ),
      ],
    );
  }
}
