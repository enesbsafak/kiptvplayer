import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';

/// "Starting soon" card for a programme reminder, over every screen (the
/// full player included) until watched or dismissed.
class ReminderBanner extends StatelessWidget {
  const ReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final reminders = context.app.reminders;
    return ListenableBuilder(
      listenable: reminders,
      builder: (context, _) {
        final r = reminders.due;
        if (r == null) return const SizedBox.shrink();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: KdColors.bg2,
            border: Border.all(color: KdColors.accentAlpha(0.45)),
            borderRadius: BorderRadius.circular(KdRadius.card),
            boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bellRing, size: 14, color: KdColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    r.start > now ? l10n.reminderStartsAt(kdClock(r.start)) : l10n.reminderStarted,
                    style: const TextStyle(color: KdColors.accent2, fontSize: KdType.small, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.title, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(r.item.name, style: const TextStyle(color: KdColors.muted)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KdButton(label: l10n.actionDismiss, kind: KdButtonKind.ghost, onPressed: reminders.dismiss),
                  const SizedBox(width: 8),
                  KdButton(
                    label: l10n.actionWatch,
                    icon: LucideIcons.play,
                    kind: KdButtonKind.cta,
                    onPressed: () {
                      reminders.dismiss();
                      context.player.play(r.item, Kind.live, queue: [r.item], view: PlayerView.full);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
