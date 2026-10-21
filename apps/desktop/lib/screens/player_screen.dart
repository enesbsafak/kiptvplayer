import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/paging.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/media_track.dart';
import '../player/player_controller.dart';
import '../player/reconnect_banner.dart';

enum _Panel { none, tracks, channels }

/// Full player: video with a Flutter OSD drawn over the texture.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _focus = FocusNode(debugLabel: 'player');
  bool _osd = true;
  Timer? _hide;
  _Panel _panel = _Panel.none;

  @override
  void initState() {
    super.initState();
    _poke();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    // Back to the usual place for the preview and the next video.
    _player?.engine.setSubtitlePosition(100);
    super.dispose();
  }

  PlayerController? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player ??= context.player;
    _placeSubtitles();
  }

  /// The bottom controls' height (seek bar, buttons, padding).
  static const _osdHeight = 140.0;

  /// Subtitles sit above the controls while they show, so nothing is
  /// hidden under them, and drop back once they fade.
  void _placeSubtitles() {
    final h = MediaQuery.sizeOf(context).height;
    final raised = h <= 0 ? 85 : (100 - _osdHeight / h * 100).floor().clamp(60, 100);
    _player?.engine.setSubtitlePosition(_osd ? raised : 100);
  }

  void _setOsd(bool v) {
    if (_osd == v) return;
    setState(() => _osd = v);
    _placeSubtitles();
  }

  /// Shows the OSD and restarts its 3 s hide timer.
  void _poke() {
    _hide?.cancel();
    _setOsd(true);
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _panel == _Panel.none) _setOsd(false);
    });
  }

  void _togglePanel(_Panel p) {
    setState(() => _panel = _panel == p ? _Panel.none : p);
    _poke();
  }

  void _exit() {
    final player = context.player;
    if (_panel != _Panel.none) {
      setState(() => _panel = _Panel.none);
      return;
    }
    if (player.now?.isLive ?? false) {
      player.setView(PlayerView.preview);
    } else if (player.now?.isCatchup ?? false) {
      // Back where the replay was picked: the channel's live preview.
      player.setView(PlayerView.preview);
      player.backToLive();
    } else {
      player.stop();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final p = context.player;
    final live = p.now?.isLive ?? false;
    final k = e.logicalKey;
    _poke();
    if (k == LogicalKeyboardKey.escape) {
      _exit();
    } else if (k == LogicalKeyboardKey.space) {
      p.togglePause();
    } else if (k == LogicalKeyboardKey.keyF) {
      p.toggleWindowFullscreen();
    } else if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.keyS) {
      _togglePanel(_Panel.tracks);
    } else if (k == LogicalKeyboardKey.keyL && live) {
      _togglePanel(_Panel.channels);
    } else if (live && digitOf(k) != null) {
      p.typeDigit(digitOf(k)!);
    } else if (live && p.zapDigits.isNotEmpty && (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter)) {
      p.commitDigits();
    } else if (k == LogicalKeyboardKey.keyM) {
      p.setVolume(p.volume > 0 ? 0 : 100);
    } else if (live && k == LogicalKeyboardKey.arrowUp) {
      p.zap(-1);
    } else if (live && k == LogicalKeyboardKey.arrowDown) {
      p.zap(1);
    } else if (!live && k == LogicalKeyboardKey.arrowLeft) {
      p.seekBy(const Duration(seconds: -10));
    } else if (!live && k == LogicalKeyboardKey.arrowRight) {
      p.seekBy(const Duration(seconds: 10));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      p.setVolume(p.volume + 5);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      p.setVolume(p.volume - 5);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.player;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: _osd ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: (_) => _poke(),
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final now = player.now;
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                GestureDetector(
                  onTap: () {
                    _focus.requestFocus();
                    if (_panel != _Panel.none) {
                      setState(() => _panel = _Panel.none);
                    } else {
                      player.togglePause();
                    }
                    _poke();
                  },
                  onDoubleTap: player.toggleWindowFullscreen,
                  child: player.engine.surface(),
                ),
                if (player.opening || player.buffering)
                  const Center(child: SizedBox(width: 160, child: KdIndeterminate(height: 3))),
                if (player.reconnecting)
                  Center(child: ReconnectBanner(player: player))
                else if (player.error != null && !player.opening)
                  Center(child: _ErrorCard(message: player.error!, onRetry: () => _retry(player))),
                IgnorePointer(
                  ignoring: !_osd,
                  child: AnimatedOpacity(
                    opacity: _osd ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(alignment: Alignment.topCenter, child: _TopBar(now: now, player: player, onBack: _exit)),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _BottomBar(
                            player: player,
                            onTracks: () => _togglePanel(_Panel.tracks),
                            onChannels: () => _togglePanel(_Panel.channels),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(top: 70, right: 24, child: ZapDigits(player: player)),
                if (_panel == _Panel.tracks)
                  Positioned(right: 20, bottom: 110, child: _TracksPanel(player: player)),
                if (_panel == _Panel.channels && now != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 340,
                    child: _ChannelSheet(now: now, onPick: (item) => player.play(item, Kind.live, queue: now.queue, view: PlayerView.full)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _retry(PlayerController p) {
    final n = p.now;
    if (n == null) return;
    p.play(n.item, n.kind, queue: n.queue, episode: n.episode, programme: n.programme, view: PlayerView.full);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.now, required this.player, required this.onBack});

  final NowPlaying? now;
  final PlayerController player;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final n = now;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE60B0B10), Color(0x000B0B10)],
        ),
      ),
      child: Row(
        children: [
          _OsdButton(icon: LucideIcons.arrowLeft, tooltip: l10n.tipBackEsc, onTap: onBack),
          const SizedBox(width: 12),
          // Title and tags take the free space, so trailing actions sit at the edge.
          Expanded(
            child: n == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Flexible(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (n.isLive) KdTag(l10n.tagLive),
                      if (n.isCatchup) KdTag(l10n.tagCatchup),
                      if (player.backupName != null) ...[const SizedBox(width: 6), KdTag(l10n.tagBackup)],
                      if (player.videoHeight case final h? when h > 0) ...[
                        const SizedBox(width: 6),
                        KdTag(h >= 2000 ? '4K' : h >= 1000 ? 'FHD' : h >= 700 ? 'HD' : 'SD', ok: true),
                      ],
                    ],
                  ),
          ),
          if (n != null && n.isCatchup) ...[
            const SizedBox(width: 12),
            KdButton(label: l10n.actionBackToLive, icon: LucideIcons.radio, kind: KdButtonKind.cta, onPressed: player.backToLive),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.player, required this.onTracks, required this.onChannels});

  final PlayerController player;
  final VoidCallback onTracks;
  final VoidCallback onChannels;

  @override
  Widget build(BuildContext context) {
    final n = player.now;
    final live = n?.isLive ?? false;
    final epg = context.epg;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xEE0B0B10), Color(0x000B0B10)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live && n != null)
            ListenableBuilder(
              listenable: epg,
              builder: (context, _) {
                final p = epg.now(n.item.id);
                if (p == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(
                        kdClock(p.start),
                        style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: KdProgress(value: programmeProgress(p), height: 3)),
                      const SizedBox(width: 10),
                      Text(
                        kdClock(p.stop),
                        style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            _SeekBar(player: player),
          Row(
            children: [
              Expanded(child: _NowInfo(player: player)),
              _OsdButton(
                icon: live ? LucideIcons.chevronsUpDown : LucideIcons.rewind,
                tooltip: live ? l10n.tipPrevChannel : l10n.tipBack10,
                onTap: () => live ? player.zap(-1) : player.seekBy(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 6),
              _OsdButton(
                icon: player.playing ? LucideIcons.pause : LucideIcons.play,
                tooltip: l10n.tipPlayPauseSpace,
                big: true,
                onTap: player.togglePause,
              ),
              const SizedBox(width: 6),
              _OsdButton(
                icon: live ? LucideIcons.skipForward : LucideIcons.fastForward,
                tooltip: live ? l10n.tipNextChannel : l10n.tipForward10,
                onTap: () => live ? player.zap(1) : player.seekBy(const Duration(seconds: 10)),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _Volume(player: player),
                    const SizedBox(width: 6),
                    _OsdButton(icon: LucideIcons.subtitles, tooltip: l10n.tipTracks, onTap: onTracks),
                    if (live) ...[
                      const SizedBox(width: 6),
                      _OsdButton(icon: LucideIcons.listVideo, tooltip: l10n.tipChannelList, onTap: onChannels),
                    ],
                    const SizedBox(width: 6),
                    _OsdButton(icon: LucideIcons.maximize, tooltip: l10n.tipFullscreen, onTap: player.toggleWindowFullscreen),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowInfo extends StatelessWidget {
  const _NowInfo({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final n = player.now;
    if (n == null) return const SizedBox.shrink();
    final epg = context.epg;
    return Row(
      children: [
        KdArt(url: n.item.logo, label: n.item.name, width: 40, height: 40, contain: n.kind == Kind.live),
        const SizedBox(width: 10),
        Flexible(
          child: ListenableBuilder(
            listenable: epg,
            builder: (context, _) {
              final p = n.isLive ? epg.now(n.item.id) : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(n.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    switch (n.programme) {
                      final pr? => '${pr.title} · ${kdDay(pr.start)} ${kdClock(pr.start)}',
                      _ => p?.title ?? n.episode?.title ?? (n.isLive ? l10n.liveBroadcast : ''),
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player});

  final PlayerController player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final total = p.duration.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ValueListenableBuilder<Duration>(
        valueListenable: p.position,
        builder: (context, pos, _) {
          final value = _drag ?? (total > 0 ? pos.inMilliseconds / total : 0.0);
          return Row(
            children: [
              Text(_fmt(pos), style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    void at(double dx) => setState(() => _drag = (dx / c.maxWidth).clamp(0, 1));
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => at(d.localPosition.dx),
                      onTapUp: (_) => _commit(total),
                      onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
                      onHorizontalDragEnd: (_) => _commit(total),
                      child: SizedBox(height: 16, child: Center(child: KdProgress(value: value, height: 3))),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(_fmt(p.duration), style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          );
        },
      ),
    );
  }

  void _commit(int total) {
    final v = _drag;
    if (v != null && total > 0) widget.player.seekTo(Duration(milliseconds: (v * total).round()));
    setState(() => _drag = null);
  }
}

class _Volume extends StatelessWidget {
  const _Volume({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final muted = player.volume <= 0;
    return Row(
      children: [
        _OsdButton(
          icon: muted ? LucideIcons.volumeX : LucideIcons.volume2,
          tooltip: l10n.tipVolume,
          onTap: () => player.setVolume(muted ? 100 : 0),
        ),
        SizedBox(
          width: 90,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => player.setVolume(d.localPosition.dx / c.maxWidth * 100),
              onHorizontalDragUpdate: (d) => player.setVolume(d.localPosition.dx / c.maxWidth * 100),
              child: SizedBox(height: 20, child: Center(child: KdProgress(value: player.volume / 100, height: 3, color: KdColors.text))),
            ),
          ),
        ),
      ],
    );
  }
}

class _OsdButton extends StatefulWidget {
  const _OsdButton({required this.icon, required this.onTap, this.tooltip, this.big = false});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool big;

  @override
  State<_OsdButton> createState() => _OsdButtonState();
}

class _OsdButtonState extends State<_OsdButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 44.0 : 34.0;
    Widget b = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.big
                ? (_hover ? KdColors.accent2 : KdColors.accent)
                : (_hover ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF)),
          ),
          child: Icon(widget.icon, size: widget.big ? 20 : 16, color: widget.big ? KdColors.accentInk : KdColors.text),
        ),
      ),
    );
    if (widget.tooltip != null) {
      b = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 400), child: b);
    }
    return b;
  }
}

/// Audio and subtitle tracks side by side, like HBO Max's picker. Same-
/// language tracks carry what tells them apart (forced, SDH, format).
class _TracksPanel extends StatelessWidget {
  const _TracksPanel({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final audios = player.tracks.where((t) => t.kind == TrackKind.audio).toList();
    final subs = player.tracks.where((t) => t.kind == TrackKind.subtitle).toList();
    final audioLabels = trackLabels(audios);
    final subLabels = trackLabels(subs);
    Widget column(String title, List<Widget> rows) => SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KdSectionLabel(title),
          const SizedBox(height: 8),
          if (rows.isEmpty) Text(l10n.tracksNone, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
          ...rows,
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(
        color: KdColors.bg2.withValues(alpha: 0.96),
        border: Border.all(color: KdColors.line),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            column(l10n.tracksAudio, [
              for (final (i, t) in audios.indexed)
                _TrackRow(label: audioLabels[i], selected: t.selected, onTap: () => player.setAudio(t)),
            ]),
            const SizedBox(width: 18),
            column(l10n.tracksSubtitles, [
              if (subs.isNotEmpty)
                _TrackRow(
                  label: TrackLabel(l10n.tracksOff, ''),
                  selected: !subs.any((t) => t.selected),
                  onTap: () => player.setSubtitle(null),
                ),
              for (final (i, t) in subs.indexed)
                _TrackRow(label: subLabels[i], selected: t.selected, onTap: () => player.setSubtitle(t)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.label, required this.selected, required this.onTap});

  final TrackLabel label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KdRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          children: [
            SizedBox(width: 18, child: selected ? const Icon(LucideIcons.check, size: 14, color: KdColors.accent) : null),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label.name,
                      style: TextStyle(color: selected ? KdColors.accent2 : KdColors.text, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                    ),
                    if (label.detail.isNotEmpty)
                      TextSpan(text: '  ${label.detail}', style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Left sheet with the zap queue, current channel highlighted.
class _ChannelSheet extends StatefulWidget {
  const _ChannelSheet({required this.now, required this.onPick});

  final NowPlaying now;
  final ValueChanged<Item> onPick;

  @override
  State<_ChannelSheet> createState() => _ChannelSheetState();
}

class _ChannelSheetState extends State<_ChannelSheet> {
  static const _row = 46.0;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final i = widget.now.queue.indexWhere((c) => c.id == widget.now.item.id);
    _scroll = ScrollController(initialScrollOffset: (i < 3 ? 0 : i - 3) * _row);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.now.queue;
    final epg = context.epg;
    return Container(
      decoration: BoxDecoration(
        color: KdColors.bg.withValues(alpha: 0.94),
        border: const Border(right: BorderSide(color: KdColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: KdSectionLabel(l10n.kindChannels)),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemExtent: _row,
              itemCount: q.length,
              itemBuilder: (context, i) {
                final c = q[i];
                final current = c.id == widget.now.item.id;
                epg.want(c.id);
                return InkWell(
                  onTap: () => widget.onPick(c),
                  child: Container(
                    color: current ? KdColors.accentAlpha(0.12) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('${c.chno ?? i + 1}', style: const TextStyle(color: KdColors.muted, fontSize: KdType.small, fontFeatures: [FontFeature.tabularFigures()])),
                        ),
                        KdArt(url: c.logo, label: c.name, width: 30, height: 30, contain: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: epg,
                            builder: (context, _) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: current ? KdColors.accent2 : KdColors.text, fontWeight: FontWeight.w500)),
                                if (epg.now(c.id) case final p?)
                                  Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KdColors.bg2,
        border: Border.all(color: KdColors.err.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.circleAlert, size: 16, color: KdColors.err),
              const SizedBox(width: 8),
              Text(l10n.playerOpenFailed, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: KdButton(label: l10n.actionRetry, kind: KdButtonKind.primary, onPressed: onRetry)),
        ],
      ),
    );
  }
}
