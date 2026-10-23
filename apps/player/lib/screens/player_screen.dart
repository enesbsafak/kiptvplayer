import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/paging.dart';
import '../app/platform.dart';
import '../app/scope.dart';
import '../design/layout.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/media_track.dart';
import '../player/playback_stats.dart';
import '../player/player_controller.dart';
import '../player/reconnect_banner.dart';
import '../player/stats_panel.dart';
import 'subtitle_search.dart';
import '../design/widgets/kd_focus.dart';

enum _Panel { none, tracks, channels }

/// Full player: video with a Flutter OSD drawn over the texture.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _focus = FocusNode(debugLabel: 'player');

  /// The play button: where a remote's OK lands when it brings the
  /// controls up.
  final _playFocus = FocusNode(debugLabel: 'player-play');

  /// The audio and subtitles panel's own scope, so opening it can hand it
  /// the focus.
  final _tracksScope = FocusScopeNode(debugLabel: 'player-tracks');
  bool _osd = true;
  Timer? _hide;
  _Panel _panel = _Panel.none;

  /// The statistics panel ("I"): stays while the controls fade.
  bool _stats = false;

  /// A short note for key-driven changes without a panel ("Altyazı +0.3 s").
  String? _flash;
  Timer? _flashTimer;

  void _note(String text) {
    _flashTimer?.cancel();
    setState(() => _flash = text);
    _flashTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  void initState() {
    super.initState();
    // Keys and the remote go to the player while it is open, whatever had
    // the focus before (autofocus only applies when nothing has).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _poke();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _flashTimer?.cancel();
    _focus.dispose();
    _playFocus.dispose();
    _tracksScope.dispose();
    // Back to the usual place for the preview and the next video.
    _player?.engine.setSubtitlePosition(100);
    _player?.tracksPanelRequest.removeListener(_openTracksOnRequest);
    _player?.statsPanelRequest.removeListener(_openStatsOnRequest);
    _player?.removeListener(_onPlayer);
    super.dispose();
  }

  PlayerController? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_player == null) {
      _player = context.player
        ..tracksPanelRequest.addListener(_openTracksOnRequest)
        ..statsPanelRequest.addListener(_openStatsOnRequest)
        ..addListener(_onPlayer);
      _wasPlaying = _player!.playing;
      _openTracksOnRequest();
      _openStatsOnRequest();
    }
    _placeSubtitles();
  }

  void _openTracksOnRequest() {
    final request = _player?.tracksPanelRequest;
    if (request == null || !request.value) return;
    request.value = false;
    if (_panel != _Panel.tracks) _togglePanel(_Panel.tracks);
  }

  /// A pause from anywhere (key, click, media keys) brings the controls up.
  bool _wasPlaying = true;
  void _onPlayer() {
    final playing = _player?.playing ?? true;
    if (_wasPlaying && !playing && mounted) _poke();
    _wasPlaying = playing;
  }

  void _openStatsOnRequest() {
    final request = _player?.statsPanelRequest;
    if (request == null || !request.value) return;
    request.value = false;
    setState(() => _stats = true);
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
    // Paused, the controls stay: where it stopped, how far behind live.
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _panel == _Panel.none && (_player?.playing ?? true)) {
        // No invisible button keeps the focus.
        if (_onControl) _focus.requestFocus();
        _setOsd(false);
      }
    });
  }

  void _togglePanel(_Panel p) {
    final closing = _panel == p;
    setState(() => _panel = closing ? _Panel.none : p);
    if (closing) {
      _focus.requestFocus();
    } else if (p == _Panel.tracks) {
      // Its first row, once built (the channel list focuses its current row
      // itself).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _panel == p && !_tracksScope.hasFocus) _tracksScope.nextFocus();
      });
    }
    _poke();
  }

  /// A control (an OSD button, a panel row) has the keyboard or remote
  /// focus rather than the video itself.
  bool get _onControl {
    final f = FocusManager.instance.primaryFocus;
    return f != null && f != _focus && f.ancestors.contains(_focus);
  }

  static final _traversalKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  /// OK on a remote with nothing focused: the controls come up with the play
  /// button focused, so the arrows move between the buttons from there. The
  /// controls are always built (faded out, not removed), so it is there.
  void _focusControls() {
    _poke();
    _playFocus.requestFocus();
  }

  void _exit() {
    final player = context.player;
    if (_panel != _Panel.none) {
      setState(() => _panel = _Panel.none);
      _focus.requestFocus();
      return;
    }
    if (_onControl) {
      // Back from the buttons hides them first, as on a TV's own player.
      _focus.requestFocus();
      _hide?.cancel();
      _setOsd(false);
      return;
    }
    if (isCompact(context)) {
      // No preview pane to fall back to on a phone.
      player.stop();
    } else if (player.now?.isLive ?? false) {
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
    if (_onControl && _traversalKeys.contains(k)) {
      // The focused button or row takes them: arrows move, OK activates.
      return KeyEventResult.ignored;
    }
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
    } else if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _focusControls();
    } else if (live && (k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.channelDown)) {
      p.zap(k == LogicalKeyboardKey.channelUp ? -1 : 1);
    } else if (k == LogicalKeyboardKey.mediaPlayPause) {
      p.togglePause();
    } else if (k == LogicalKeyboardKey.mediaPlay || k == LogicalKeyboardKey.mediaPause) {
      if (p.playing != (k == LogicalKeyboardKey.mediaPlay)) p.togglePause();
    } else if ((!live || p.canTimeshift) && (k == LogicalKeyboardKey.mediaRewind || k == LogicalKeyboardKey.mediaFastForward)) {
      p.seekBy(Duration(seconds: k == LogicalKeyboardKey.mediaRewind ? -10 : 10));
    } else if (k == LogicalKeyboardKey.contextMenu || k == LogicalKeyboardKey.info) {
      _togglePanel(_Panel.tracks);
    } else if (k == LogicalKeyboardKey.keyZ || k == LogicalKeyboardKey.keyX) {
      p.nudgeSubtitleDelay(k == LogicalKeyboardKey.keyZ ? -0.1 : 0.1).then((_) {
        if (mounted) _note(l10n.adjSubtitleDelayNote(seconds(p.subtitleDelay)));
      });
    } else if (k == LogicalKeyboardKey.keyI) {
      setState(() => _stats = !_stats);
    } else if (k == LogicalKeyboardKey.keyM) {
      p.setVolume(p.volume > 0 ? 0 : 100);
    } else if (live && k == LogicalKeyboardKey.arrowUp) {
      p.zap(-1);
    } else if (live && k == LogicalKeyboardKey.arrowDown) {
      p.zap(1);
    } else if ((!live || p.canTimeshift) && k == LogicalKeyboardKey.arrowLeft) {
      p.seekBy(const Duration(seconds: -10));
    } else if ((!live || p.canTimeshift) && k == LogicalKeyboardKey.arrowRight) {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        // The video itself: arrows on the controls move between them only.
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: _osd ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onHover: (_) => _poke(),
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final now = player.now;
              // A phone's cutout, a TV's overscan: overlays keep inside it.
              final safe = MediaQuery.paddingOf(context);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  GestureDetector(
                    onTapUp: (d) {
                      _focus.requestFocus();
                      if (_panel != _Panel.none) {
                        setState(() => _panel = _Panel.none);
                      } else if (d.kind == PointerDeviceKind.touch) {
                        // Touch: a tap shows or hides the controls, as on any phone player.
                        if (_osd) {
                          _hide?.cancel();
                          _setOsd(false);
                        } else {
                          _poke();
                        }
                        return;
                      } else {
                        player.togglePause();
                      }
                      _poke();
                    },
                    onDoubleTap: isDesktopOs ? player.toggleWindowFullscreen : null,
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
                      // The shades reach the screen's edges; the controls in
                      // them keep clear of camera cutouts, rounded corners and
                      // a TV's overscan (the bars add the safe padding).
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(alignment: Alignment.topCenter, child: _TopBar(now: now, player: player, onBack: _exit)),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: _BottomBar(
                              player: player,
                              playFocus: _playFocus,
                              onTracks: () => _togglePanel(_Panel.tracks),
                              onStats: () => setState(() => _stats = !_stats),
                              onChannels: () => _togglePanel(_Panel.channels),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(top: 70 + safe.top, right: 24 + safe.right, child: ZapDigits(player: player)),
                  if (_stats && now != null)
                    Positioned(
                      top: 70 + safe.top,
                      left: 20 + safe.left,
                      child: StatsPanel(player: player, onClose: () => setState(() => _stats = false)),
                    ),
                  if (_flash case final f?)
                    Positioned(
                      top: 70,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: KdColors.bg2.withValues(alpha: 0.92),
                            border: Border.all(color: KdColors.line),
                            borderRadius: BorderRadius.circular(KdRadius.card),
                          ),
                          child: Text(f, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                        ),
                      ),
                    ),
                  // Each panel is its own focus scope: opened, it takes the
                  // focus (the first track, the current channel) so a remote
                  // works in it at once (_togglePanel).
                  if (_panel == _Panel.tracks && _TracksSheet.fits(context))
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: _TracksSheet.width(context),
                      child: FocusScope(node: _tracksScope, child: _TracksSheet(player: player)),
                    )
                  else if (_panel == _Panel.tracks)
                    Positioned(right: 20 + safe.right, bottom: 110 + safe.bottom, child: FocusScope(node: _tracksScope, child: _TracksPanel(player: player))),
                  if (_panel == _Panel.channels && now != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 340,
                      child: FocusScope(
                        child: _ChannelSheet(now: now, onPick: (item) => player.play(item, Kind.live, queue: now.queue, view: PlayerView.full)),
                      ),
                    ),
                ],
              );
            },
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 36) + MediaQuery.paddingOf(context).copyWith(bottom: 0),
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
                      if (player.sleepAt case final at?) ...[
                        const SizedBox(width: 6),
                        KdTag(l10n.adjSleepTag(kdClock(at.millisecondsSinceEpoch ~/ 1000))),
                      ],
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
  const _BottomBar({required this.player, required this.onTracks, required this.onStats, required this.onChannels, this.playFocus});

  final PlayerController player;
  final FocusNode? playFocus;
  final VoidCallback onTracks;
  final VoidCallback onStats;
  final VoidCallback onChannels;

  @override
  Widget build(BuildContext context) {
    final n = player.now;
    final live = n?.isLive ?? false;
    final epg = context.epg;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 18) + MediaQuery.paddingOf(context).copyWith(top: 0),
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
            // One timeline for live TV: the programme from the guide and,
            // with timeshift, the buffered stretch and the playhead on it.
            ListenableBuilder(
              listenable: epg,
              builder: (context, _) {
                final p = epg.now(n.item.id);
                if (player.canTimeshift) return _LiveBar(player: player, programme: p);
                if (p == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      _Clock(p.start),
                      const SizedBox(width: 10),
                      Expanded(child: KdProgress(value: programmeProgress(p), height: 3)),
                      const SizedBox(width: 10),
                      _Clock(p.stop),
                    ],
                  ),
                );
              },
            )
          else
            _SeekBar(player: player),
          if (isCompact(context))
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _OsdButton(icon: LucideIcons.subtitles, tooltip: l10n.tipTracks, onTap: onTracks),
                _OsdButton(icon: LucideIcons.activity, tooltip: l10n.tipStats, onTap: onStats),
                _OsdButton(
                  icon: live ? LucideIcons.chevronsUpDown : LucideIcons.rewind,
                  tooltip: live ? l10n.tipPrevChannel : l10n.tipBack10,
                  onTap: () => live ? player.zap(-1) : player.seekBy(const Duration(seconds: -10)),
                ),
                _OsdButton(
                  icon: player.playing ? LucideIcons.pause : LucideIcons.play,
                  tooltip: l10n.tipPlayPauseSpace,
                  big: true,
                  focusNode: playFocus,
                  onTap: player.togglePause,
                ),
                _OsdButton(
                  icon: live ? LucideIcons.skipForward : LucideIcons.fastForward,
                  tooltip: live ? l10n.tipNextChannel : l10n.tipForward10,
                  onTap: () => live ? player.zap(1) : player.seekBy(const Duration(seconds: 10)),
                ),
                if (live) _OsdButton(icon: LucideIcons.listVideo, tooltip: l10n.tipChannelList, onTap: onChannels),
              ],
            )
          else
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
                focusNode: playFocus,
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
                    const SizedBox(width: 6),
                    _OsdButton(icon: LucideIcons.activity, tooltip: l10n.tipStats, onTap: onStats),
                    if (live) ...[
                      const SizedBox(width: 6),
                      _OsdButton(icon: LucideIcons.listVideo, tooltip: l10n.tipChannelList, onTap: onChannels),
                    ],
                    const SizedBox(width: 6),
                    if (isDesktopOs) _OsdButton(icon: LucideIcons.maximize, tooltip: l10n.tipFullscreen, onTap: player.toggleWindowFullscreen),
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

class _Clock extends StatelessWidget {
  const _Clock(this.seconds);

  final int seconds;

  @override
  Widget build(BuildContext context) => Text(
        kdClock(seconds),
        style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
      );
}

/// Live TV on the local buffer. With a guide the bar spans the programme
/// (its start and end times at the ends) and shows how much has aired, the
/// buffered stretch that can be replayed and the playhead; without one it
/// spans the buffer. Also how far behind live, and the way back.
class _LiveBar extends StatefulWidget {
  const _LiveBar({required this.player, this.programme});

  final PlayerController player;
  final Programme? programme;

  @override
  State<_LiveBar> createState() => _LiveBarState();
}

class _LiveBarState extends State<_LiveBar> {
  Timer? _timer;
  (Duration, Duration)? _range;
  double? _drag;

  @override
  void initState() {
    super.initState();
    _read();
    // The buffer's ends move every second; only while the controls show.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    final r = await widget.player.engine.seekableRange();
    if (mounted) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final range = _range;
    final show = widget.programme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ValueListenableBuilder<Duration>(
        valueListenable: p.position,
        builder: (context, pos, _) {
          final (start, end) = range ?? (pos, pos);
          final behind = end - pos;
          final atLive = behind < const Duration(seconds: 4) && p.playing;
          // Wall-clock seconds: the buffer's end is now.
          final nowS = DateTime.now().millisecondsSinceEpoch / 1000;
          final bufferFrom = nowS - (end - start).inMilliseconds / 1000;
          final playhead = nowS - behind.inMilliseconds / 1000;
          final (from, to) = show != null && show.stop > show.start ? (show.start.toDouble(), show.stop.toDouble()) : (bufferFrom, nowS);
          double frac(double t) => to > from ? ((t - from) / (to - from)).clamp(0.0, 1.0) : 1.0;
          return Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  atLive ? l10n.tagLive : '−${_fmt(behind)}',
                  style: TextStyle(
                    fontSize: KdType.chip,
                    color: atLive ? KdColors.accent : KdColors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (show != null) ...[_Clock(show.start), const SizedBox(width: 10)],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    void at(double dx) => setState(() => _drag = (dx / c.maxWidth).clamp(0, 1));
                    void commit() {
                      final v = _drag;
                      if (v != null && end > start) {
                        // Only the buffered stretch can be reached.
                        final t = (from + v * (to - from)).clamp(bufferFrom, nowS);
                        p.seekTo(start + Duration(milliseconds: ((t - bufferFrom) * 1000).round()));
                      }
                      setState(() => _drag = null);
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => at(d.localPosition.dx),
                      onTapUp: (_) => commit(),
                      onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
                      onHorizontalDragEnd: (_) => commit(),
                      child: SizedBox(
                        key: const Key('live-bar'),
                        height: 16,
                        child: CustomPaint(
                          painter: _LiveBarPainter(aired: frac(nowS), buffered: frac(bufferFrom), playhead: _drag ?? frac(playhead)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (show != null) ...[const SizedBox(width: 10), _Clock(show.stop)],
              const SizedBox(width: 10),
              // Kept in the layout at live, so the bar does not jump.
              Visibility(
                visible: !atLive,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: KdButton(label: l10n.timeshiftGoLive, icon: LucideIcons.radio, kind: KdButtonKind.cta, onPressed: atLive ? null : p.goLive),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// The track, then what has aired (muted), the replayable buffer (faint
/// accent), what is watched up to the playhead (accent) and the playhead.
class _LiveBarPainter extends CustomPainter {
  _LiveBarPainter({required this.aired, required this.buffered, required this.playhead});

  final double aired;
  final double buffered;
  final double playhead;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 3.0;
    final y = size.height / 2;
    void bar(double a, double b, Color color) {
      if (b <= a) return;
      canvas.drawRRect(
        RRect.fromLTRBR(a * size.width, y - h / 2, b * size.width, y + h / 2, const Radius.circular(KdRadius.bar)),
        Paint()..color = color,
      );
    }

    bar(0, 1, KdColors.line);
    bar(0, aired, KdColors.muted.withValues(alpha: .45));
    bar(buffered, aired, KdColors.accent.withValues(alpha: .45));
    bar(0, playhead, KdColors.accent);
    canvas.drawCircle(Offset(playhead * size.width, y), 5, Paint()..color = KdColors.accent);
  }

  @override
  bool shouldRepaint(_LiveBarPainter old) => old.aired != aired || old.buffered != buffered || old.playhead != playhead;
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
  const _OsdButton({required this.icon, required this.onTap, this.tooltip, this.big = false, this.focusNode});

  final IconData icon;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final String? tooltip;
  final bool big;

  @override
  State<_OsdButton> createState() => _OsdButtonState();
}

class _OsdButtonState extends State<_OsdButton> {
  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 44.0 : 34.0;
    Widget b = KdTappable(
      onTap: widget.onTap,
      focusNode: widget.focusNode,
      builder: (context, hover, focus) => KdFocusRing(
        focused: focus,
        radius: size / 2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.big
                ? (hover ? KdColors.accent2 : KdColors.accent)
                : (hover ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF)),
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
      // Between the top bar and the bottom bar, whatever the window height;
      // never wider than the screen (a phone on its side, a TV): the columns
      // wrap and the panel scrolls.
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height - 200).clamp(240, 520),
        maxWidth: MediaQuery.sizeOf(context).width - 40 - MediaQuery.paddingOf(context).horizontal,
      ),
      decoration: BoxDecoration(
        color: KdColors.bg2.withValues(alpha: 0.96),
        border: Border.all(color: KdColors.line),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            column(l10n.tracksAudio, _audioRows(player)),
            column(l10n.tracksSubtitles, _subtitleRows(context, player)),
            _AdjustColumn(player: player),
          ],
        ),
      ),
    );
  }
}

List<Widget> _audioRows(PlayerController player, {bool touch = false}) {
  final audios = player.tracks.where((t) => t.kind == TrackKind.audio).toList();
  final labels = trackLabels(audios);
  return [
    for (final (i, t) in audios.indexed)
      _TrackRow(label: labels[i], selected: t.selected, touch: touch, onTap: () => player.setAudio(t)),
  ];
}

List<Widget> _subtitleRows(BuildContext context, PlayerController player, {bool touch = false}) {
  final subs = player.tracks.where((t) => t.kind == TrackKind.subtitle).toList();
  final labels = trackLabels(subs);
  return [
    if (subs.isNotEmpty)
      _TrackRow(
        label: TrackLabel(l10n.tracksOff, ''),
        selected: !subs.any((t) => t.selected),
        touch: touch,
        onTap: () => player.setSubtitle(null),
      ),
    for (final (i, t) in subs.indexed)
      _TrackRow(label: labels[i], selected: t.selected, touch: touch, onTap: () => player.setSubtitle(t)),
    const SizedBox(height: 8),
    KdButton(
      label: l10n.adjAddSubtitle,
      icon: LucideIcons.filePlus,
      kind: KdButtonKind.ghost,
      onPressed: () => _pickSubtitle(player),
    ),
    if (!(player.now?.isLive ?? true) && !(player.now?.isCatchup ?? false))
      KdButton(
        label: l10n.subsFind,
        icon: LucideIcons.globe,
        kind: KdButtonKind.ghost,
        onPressed: () => showSubtitleSearch(context, player),
      ),
  ];
}

/// Phones (and any short window): audio, subtitles and the adjustments as
/// tabs of a full-height sheet on the right, scrolling inside, with rows big
/// enough for a finger. The three columns of [_TracksPanel] need some
/// 850 x 400 px, more than a phone on its side has.
class _TracksSheet extends StatefulWidget {
  const _TracksSheet({required this.player});

  final PlayerController player;

  static bool fits(BuildContext context) => !isTv && (isMobileOs || MediaQuery.sizeOf(context).height < 560);

  static double width(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.6).clamp(280.0, 400.0) + MediaQuery.paddingOf(context).right;

  @override
  State<_TracksSheet> createState() => _TracksSheetState();
}

class _TracksSheetState extends State<_TracksSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final safe = MediaQuery.paddingOf(context);
    final tabs = [l10n.tracksAudio, l10n.tracksSubtitles, l10n.adjTitle];
    final rows = switch (_tab) {
      0 => _audioRows(player, touch: true),
      1 => _subtitleRows(context, player, touch: true),
      _ => [_AdjustColumn(player: player, width: double.infinity)],
    };
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12 + safe.top, 16 + safe.right, 0),
      decoration: BoxDecoration(
        color: KdColors.bg2.withValues(alpha: 0.97),
        border: const Border(left: BorderSide(color: KdColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, t) in tabs.indexed) KdPill(label: t, selected: _tab == i, onTap: () => setState(() => _tab = i)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: 16 + safe.bottom),
              children: [
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.tracksNone, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
                  ),
                ...rows,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickSubtitle(PlayerController player) async {
  final file = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(label: l10n.adjSubtitleFiles, extensions: const ['srt', 'ass', 'ssa', 'vtt', 'sub']),
    ],
  );
  if (file != null) await player.addSubtitleFile(file.path);
}

/// "+0.3 s", "0.0 s", "−0.2 s" for delays.
String seconds(double v) {
  final s = oneDecimal(v.abs());
  return v > 0.04 ? '+$s s' : v < -0.04 ? '−$s s' : '$s s';
}

/// Delays, subtitle size, aspect, speed (files) and the sleep timer.
class _AdjustColumn extends StatelessWidget {
  const _AdjustColumn({required this.player, this.width = 300});

  final PlayerController player;
  final double width;

  static const _scales = [0.8, 1.0, 1.25, 1.5];
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const _sleeps = [15, 30, 60, 90];

  @override
  Widget build(BuildContext context) {
    final n = player.now;
    final live = n?.isLive ?? false;
    final programme = live && n != null ? context.epg.now(n.item.id) : null;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(text, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
    );
    Widget pills(List<Widget> children) => Wrap(spacing: 6, runSpacing: 6, children: children);
    // Label on the left, − value + on the right: two delays in two lines.
    Widget stepper(String text, double value, ValueChanged<double> nudge) => Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small))),
        _OsdButton(icon: LucideIcons.minus, onTap: () => nudge(-0.1)),
        SizedBox(
          width: 64,
          child: Text(
            seconds(value),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
        _OsdButton(icon: LucideIcons.plus, onTap: () => nudge(0.1)),
      ],
    );
    final sleeping = player.sleepAt != null;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KdSectionLabel(l10n.adjTitle),
          const SizedBox(height: 8),
          stepper(l10n.adjSubtitleDelay, player.subtitleDelay, player.nudgeSubtitleDelay),
          const SizedBox(height: 6),
          stepper(l10n.adjAudioDelay, player.audioDelay, player.nudgeAudioDelay),
          label(l10n.adjSubtitleSize),
          pills([
            for (final s in _scales)
              KdPill(label: '${(s * 100).round()}%', selected: (player.subtitleScale - s).abs() < 0.01, onTap: () => player.setSubtitleScale(s)),
          ]),
          label(l10n.adjAspect),
          pills([
            for (final (value, name) in [
              (null, l10n.adjAspectAuto),
              ('16:9', '16:9'),
              ('4:3', '4:3'),
              ('21:9', '21:9'),
              ('fill', l10n.adjAspectFill),
            ])
              KdPill(label: name, selected: player.aspect == value, onTap: () => player.setAspect(value)),
          ]),
          if (!live) ...[
            label(l10n.adjSpeed),
            pills([
              for (final s in _speeds)
                KdPill(label: '${s.toString().replaceAll(RegExp(r'\.0$'), '')}×', selected: player.speed == s, onTap: () => player.setSpeed(s)),
            ]),
          ],
          label(l10n.adjSleep),
          pills([
            KdPill(label: l10n.adjSleepOff, selected: !sleeping, onTap: () => player.setSleepTimer(null)),
            for (final m in _sleeps)
              KdPill(label: l10n.adjMinutes(m), selected: false, onTap: () => player.setSleepTimer(Duration(minutes: m))),
            if (programme != null)
              KdPill(label: l10n.adjSleepProgrammeEnd, selected: false, onTap: () => player.sleepAtProgrammeEnd(programme.stop)),
          ]),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.label, required this.selected, required this.onTap, this.touch = false});

  final TrackLabel label;
  final bool selected;
  final VoidCallback onTap;

  /// A finger's row (48 px) instead of a mouse's.
  final bool touch;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KdRadius.control),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: touch ? 14 : 5, horizontal: 4),
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
                  autofocus: current,
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
