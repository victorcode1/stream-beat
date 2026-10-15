import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flow_music/core/analytics/product_analytics.dart';
import 'package:flow_music/core/utils/locale_keys.g.dart';
import 'package:flow_music/features/radio/data/models/radio_station.dart';
import 'package:flow_music/features/radio/data/repositories/radio_browser_repository.dart';
import 'package:flow_music/features/radio/presentation/pages/radio_player_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SharedStationPage extends ConsumerStatefulWidget {
  const SharedStationPage({super.key, required this.stationId});

  final String stationId;

  @override
  ConsumerState<SharedStationPage> createState() => _SharedStationPageState();
}

class _SharedStationPageState extends ConsumerState<SharedStationPage> {
  late final RadioBrowserRepository _repository;
  late Future<RadioStation?> _stationFuture;

  @override
  void initState() {
    super.initState();
    _repository = RadioBrowserRepository();
    _stationFuture = _repository.stationByUuid(widget.stationId);
    unawaited(
      ref
          .read(productAnalyticsProvider)
          .track(
            'shared_station_opened',
            properties: {
              if (isRadioStationUuid(widget.stationId))
                'station_id': widget.stationId.trim(),
              'valid_link': isRadioStationUuid(widget.stationId),
            },
          ),
    );
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _stationFuture = _repository.stationByUuid(widget.stationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RadioStation?>(
      future: _stationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SharedStationStatus(child: const CircularProgressIndicator());
        }
        final station = snapshot.data;
        if (!snapshot.hasError && station != null) {
          return RadioPlayerPage(initialStation: station);
        }
        return _SharedStationStatus(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.radio_rounded, size: 64),
              const SizedBox(height: 20),
              Text(
                LocaleKeys.station_unavailable.tr(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(LocaleKeys.retry.tr()),
              ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(LocaleKeys.home.tr()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SharedStationStatus extends StatelessWidget {
  const _SharedStationStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('StreamBeat'),
      ),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: child),
      ),
    );
  }
}
