import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../src/rust/api/library.dart' show SourceHealth;
import 'playback_stats.dart';
import 'player_controller.dart';

/// "Neden donuyor?": what the stream, the decoder and the network are doing,
/// sampled once a second while open, with a plain-language reading of it.
/// The provider is checked once on opening (one light request, never a
/// stream) and again on request.
class StatsPanel extends StatefulWidget {
  const StatsPanel({super.key, required this.player, required this.onClose});

  final PlayerController player;
  final VoidCallback onClose;

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  static const every = Duration(seconds: 1);
  Timer? _timer;
  PlaybackStats _now = PlaybackStats.empty;
  PlaybackStats? _before;
  SourceHealth? _health;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _sample();
    _timer = Timer.periodic(every, (_) => _sample());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sample() async {
    final s = await widget.player.engine.stats();
    if (!mounted) return;
    setState(() {
      _before = _now == PlaybackStats.empty ? null : _now;
      _now = s;
    });
  }

  Future<void> _check() async {
    final sid = context.app.activeSource?.id;
    if (sid == null) return;
    setState(() => _checking = true);
    final h = await context.library.checkSource(sid);
    if (!mounted) return;
    setState(() {
      _health = h;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _now;
    final p = widget.player;
    const dash = '—';
    String positive(int? v, String Function(int) show) => v != null && v > 0 ? show(v) : dash;
    final video = [
      ?s.videoCodec?.toUpperCase(),
      if (s.width != null && s.height != null) '${s.width}×${s.height}',
      if (s.fps case final f?) '${f.round()} fps',
    ].join(' · ');
    final audio = [
      ?s.audioCodec?.toUpperCase(),
      if (s.channels case final c?) c >= 6 ? '${c - 1}.1' : c == 1 ? 'Mono' : 'Stereo',
      if (s.audioBitrate case final b? when b > 0) bitrateText(b),
    ].join(' · ');
    final rows = <(String, String)>[
      (l10n.statsVideo, video.isEmpty ? dash : video),
      (l10n.statsDecoder, switch (s.hwdec) { null => dash, 'no' => l10n.statsSoftware, final h => h }),
      (l10n.statsBitrate, positive(s.videoBitrate, bitrateText)),
      (l10n.statsAudio, audio.isEmpty ? dash : audio),
      (l10n.statsBuffer, switch (s.cacheSeconds) { final c? => '${oneDecimal(c)} s', null => dash }),
      (l10n.statsDownload, positive(s.inputRate, (r) => bitrateText(r * 8))),
      (l10n.statsDropped, '${s.decoderDrops} / ${s.droppedFrames}'),
      (l10n.statsOpen, positive(p.lastZapMs, (ms) => '$ms ms')),
      (l10n.statsReconnects, '${p.reconnects}'),
    ];
    final findings = diagnose(s, previous: _before, live: p.now?.isLive ?? false, reconnects: p.reconnects, health: _health);
    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
      decoration: BoxDecoration(
        color: KdColors.bg2.withValues(alpha: 0.94),
        border: Border.all(color: KdColors.line),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: KdSectionLabel(l10n.statsTitle)),
              IconButton(
                onPressed: widget.onClose,
                tooltip: l10n.actionClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 14, color: KdColors.muted),
              ),
            ],
          ),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 130, child: Text(k, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small))),
                  Expanded(
                    child: Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: KdType.mono, fontFamilyFallback: KdType.monoFallback, fontSize: KdType.small),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: KdColors.line),
          const SizedBox(height: 10),
          for (final f in findings) _FindingRow(finding: f),
          const SizedBox(height: 10),
          Row(
            children: [
              KdButton(
                label: _checking ? l10n.statsChecking : l10n.statsCheckSource,
                icon: LucideIcons.serverCog,
                onPressed: _checking ? null : _check,
              ),
              const SizedBox(width: 10),
              if (_health case final h?)
                Expanded(
                  child: Text(
                    h.ok ? l10n.statsAnswered(h.latencyMs) : l10n.statsNoAnswer,
                    style: TextStyle(color: h.ok ? KdColors.ok : KdColors.err, fontSize: KdType.small),
                  ),
                ),
            ],
          ),
          if (_health case final h?) ..._account(h),
        ],
      ),
    );
  }

  /// Connections and account end, when the provider says.
  List<Widget> _account(SourceHealth h) {
    final parts = [
      if (h.maxConnections case final max? when max > 0) l10n.statsConnections(h.activeConnections ?? 0, max),
      if (h.expiresAt case final end? when end > 0)
        l10n.statsExpires(DateFormat.yMd(languageCode).format(DateTime.fromMillisecondsSinceEpoch(end * 1000))),
      ?h.status,
    ];
    return [
      if (parts.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(parts.join(' · '), style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
      ],
      if (h.error case final e?) ...[
        const SizedBox(height: 6),
        Text(e, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
      ],
    ];
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (finding) {
      Finding.sourceDown => (KdColors.err, l10n.findSourceDown),
      Finding.accountExpired => (KdColors.err, l10n.findAccountExpired),
      Finding.connectionLimit => (KdColors.warn, l10n.findConnectionLimit),
      Finding.slowNetwork => (KdColors.err, l10n.findSlowNetwork),
      Finding.cacheLow => (KdColors.warn, l10n.findCacheLow),
      Finding.framesDropping => (KdColors.warn, l10n.findFramesDropping),
      Finding.softwareDecoding => (KdColors.warn, l10n.findSoftwareDecoding),
      Finding.reconnected => (KdColors.warn, l10n.findReconnected),
      Finding.healthy => (KdColors.ok, l10n.findHealthy),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 8),
            child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: KdType.small, height: 1.4))),
        ],
      ),
    );
  }
}
