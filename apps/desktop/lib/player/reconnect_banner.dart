import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import 'player_controller.dart';

/// Shown over the video while a dropped live stream is being reopened:
/// why it dropped, which attempt, a countdown, and a way out.
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
