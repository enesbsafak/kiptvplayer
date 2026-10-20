import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../tokens.dart';

/// `.tag`: accent-outlined pill, 10.5 px. [ok] turns it green.
class KdTag extends StatelessWidget {
  const KdTag(this.label, {super.key, this.ok = false});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? KdColors.ok : KdColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        // Faint dark fill: invisible on the dark UI, keeps the tag legible
        // over bright video.
        color: KdColors.bg.withValues(alpha: 0.55),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(KdRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: KdType.tag, color: color, height: 1.4),
      ),
    );
  }
}

/// 10 px status dot; [running] glows green like app.css:90.
class KdStatusDot extends StatelessWidget {
  const KdStatusDot({super.key, required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: running ? KdColors.ok : KdColors.idleDot,
        boxShadow: running
            ? [
                BoxShadow(
                  color: KdColors.ok.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Uppercase in the UI language: Turkish needs i → İ (Dart's
/// toUpperCase gives I), English must not get it.
String kdUpper(String s) => languageCode == 'tr' ? s.replaceAll('i', 'İ').toUpperCase() : s.toUpperCase();

/// Uppercase muted section label (11 px, tracking .8).
class KdSectionLabel extends StatelessWidget {
  const KdSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      kdUpper(text),
      style: const TextStyle(
        fontSize: KdType.chip,
        color: KdColors.muted,
        letterSpacing: KdType.upperTracking,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
