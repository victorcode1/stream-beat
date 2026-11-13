import 'package:flow_music/core/connectivity/offline_banner.dart';
import 'package:flow_music/features/home/presentation/widgets/home_suggestions.dart';
import 'package:flutter/material.dart';

/// Renderiza el cuerpo central del home segun el estado actual de navegacion.
class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return SizeTransition(sizeFactor: animation, child: child);
            },
            child: child ?? const HomeSuggestions(),
          ),
        ),
      ],
    );
  }
}
