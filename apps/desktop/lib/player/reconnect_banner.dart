import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import 'player_controller.dart';

/// Shown over the video while a dropped live stream is being reopened:
/// why it dropped, which attempt, a countdown, and a way out.
/// The channel number being typed (number-key zapping), top right.
class ZapDigits extends StatelessWidget {
  const ZapDigits({super.key, required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final d = player.zapDigits;
    if (d.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: KdColors.bg2.withValues(alpha: 0.92),
        border: Border.all(color: KdColors.accentAlpha(0.45)),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: Text(
        d,
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: KdColors.accent2, fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class ReconnectBanner extends StatefulWidget {
  const ReconnectBanner({super.key, required this.player, this.compact = false});

  final PlayerController player;

  /// Smaller layout for the preview and mini player.
  final bool compact;

  @override
  State<ReconnectBanner> createState() => _ReconnectBannerState();
}

class _ReconnectBannerState extends State<ReconnectBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final at = p.reconnectAt;
    final left = at == null ? 0 : (at.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 99);
    final status = p.opening || left == 0 ? 'Bağlanılıyor…' : '$left sn içinde yeniden denenecek';
    return Container(
      width: widget.compact ? 300 : 380,
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: KdColors.bg2.withValues(alpha: 0.96),
        border: Border.all(color: KdColors.warn.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.refreshCw, size: 15, color: KdColors.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${p.reconnectReason ?? 'Bağlantı koptu'} · yeniden bağlanılıyor',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${p.reconnectAttempt}. deneme · $status',
            style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
          ),
          if (p.backupName case final b?) ...[
            const SizedBox(height: 4),
            Text('Yedek yayın deneniyor: $b', style: const TextStyle(fontSize: KdType.small, color: KdColors.accent2)),
          ],
          const SizedBox(height: 10),
          const KdIndeterminate(),
          if (!widget.compact) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KdButton(label: 'Durdur', onPressed: p.stop),
                const SizedBox(width: 8),
                KdButton(label: 'Şimdi dene', kind: KdButtonKind.primary, onPressed: p.retryNow),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 0-9 from the top row or the numpad.
int? digitOf(LogicalKeyboardKey k) {
  const top = [
    LogicalKeyboardKey.digit0, LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9,
  ];
  const pad = [
    LogicalKeyboardKey.numpad0, LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3, LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5, LogicalKeyboardKey.numpad6, LogicalKeyboardKey.numpad7, LogicalKeyboardKey.numpad8, LogicalKeyboardKey.numpad9,
  ];
  final i = top.indexOf(k);
  if (i >= 0) return i;
  final j = pad.indexOf(k);
  return j >= 0 ? j : null;
}

