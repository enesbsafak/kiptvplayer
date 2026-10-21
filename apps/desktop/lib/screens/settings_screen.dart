import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../app/updates.dart';
import '../app/version.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import 'add_source.dart';
import 'parental.dart';
import 'edits.dart';

enum _Tab { sources, preferences, shortcuts, about }

/// KaradelikDev prefs layout: tab bar on `--bg-2`, rows below. Only settings
/// that actually do something are shown.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _Tab _tab = _Tab.sources;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Opened on a given tab (the update badge: "about", the palette).
    final app = context.app;
    if (_Tab.values.asNameMap()[app.settingsTab] case final tab?) {
      _tab = tab;
      app.settingsTab = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: KdColors.bg2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (t, label) in [(_Tab.sources, l10n.setSources), (_Tab.preferences, l10n.setPreferences), (_Tab.shortcuts, l10n.setShortcuts), (_Tab.about, l10n.setAbout)])
                _TabButton(label: label, active: _tab == t, onTap: () => setState(() => _tab = t)),
            ],
          ),
        ),
        const Divider(height: 1, color: KdColors.line),
        Expanded(
          child: switch (_tab) {
            _Tab.sources => const _SourcesTab(),
            _Tab.preferences => const _PreferencesTab(),
            _Tab.shortcuts => const _ShortcutsTab(),
            _Tab.about => const _AboutTab(),
          },
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? KdColors.accent : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: TextStyle(color: active ? KdColors.text : KdColors.muted, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _SourcesTab extends StatefulWidget {
  const _SourcesTab();

  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Text(l10n.setSources, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!_adding)
                KdButton(label: l10n.sourceAdd, icon: LucideIcons.plus, kind: KdButtonKind.primary, onPressed: () => setState(() => _adding = true)),
            ],
          ),
          const SizedBox(height: 12),
          if (_adding)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: KdColors.line),
                borderRadius: BorderRadius.circular(KdRadius.card),
              ),
              child: AddSourceForm(
                onCancel: () => setState(() => _adding = false),
                onDone: (s) {
                  setState(() => _adding = false);
                  app.sourceChanged(s);
                },
              ),
            ),
          for (final s in app.sources) _SourceRow(source: s, active: s.id == app.activeSource?.id),
          if (app.sources.isEmpty && !_adding)
            Padding(padding: const EdgeInsets.all(20), child: Text(l10n.sourceNoneYet, style: const TextStyle(color: KdColors.muted))),
        ],
      ),
    );
  }
}

class _SourceRow extends StatefulWidget {
  const _SourceRow({required this.source, required this.active});

  final SourceInfo source;
  final bool active;

  @override
  State<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<_SourceRow> {
  String? _stage;
  StreamSubscription<SyncEvent>? _sub;

  Future<void> _refreshGuide() async {
    setState(() => _stage = l10n.guideDownloading);
    await context.library.refreshGuide(widget.source.id).catchError((_) => widget.source);
    if (!mounted) return;
    setState(() => _stage = null);
    await context.app.guideUpdated(); // also shows a failed attempt
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _sync() {
    setState(() => _stage = l10n.syncConnecting);
    _sub = context.library.syncSource(widget.source.id).listen((e) {
      if (!mounted) return;
      switch (e) {
        case SyncEvent_Downloading(:final what):
          setState(() => _stage = l10n.syncDownloading(what));
        case SyncEvent_Saving():
          setState(() => _stage = l10n.syncSaving);
        case SyncEvent_Done(:final source):
          setState(() => _stage = null);
          context.app.sourceChanged(source);
        case SyncEvent_Failed():
          setState(() => _stage = null);
          context.app.load();
        case SyncEvent_Connecting():
          break;
      }
    });
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KdColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KdRadius.card), side: const BorderSide(color: KdColors.line)),
        title: Text(l10n.sourceDeleteTitle(widget.source.name), style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        content: Text(
          l10n.sourceDeleteBody,
          style: const TextStyle(color: KdColors.muted),
        ),
        actions: [
          KdButton(label: l10n.actionCancel, onPressed: () => Navigator.pop(context, false)),
          KdButton(label: l10n.actionDelete, kind: KdButtonKind.danger, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok == true && mounted) await context.app.removeSource(widget.source.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KdColors.bg2,
        border: Border.all(color: widget.active ? KdColors.accentAlpha(0.45) : KdColors.line),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: Row(
        children: [
          KdStatusDot(running: s.lastError == null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    KdTag(switch (s.kind) { SourceType.xtream => 'Xtream', SourceType.m3U => 'M3U', SourceType.stalker => 'Stalker' }),
                    if (widget.active) ...[const SizedBox(width: 6), KdTag(l10n.sourceActive, ok: true)],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (s.username != null) s.username!,
                    _host(s.url),
                    l10n.sourceCounts(s.liveCount.toInt(), s.movieCount.toInt(), s.seriesCount.toInt()),
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
                ),
                if (_stage != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(_stage!, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
                      const SizedBox(width: 10),
                      const SizedBox(width: 140, child: KdIndeterminate()),
                    ],
                  ),
                ] else if (s.lastError != null) ...[
                  const SizedBox(height: 4),
                  Text(s.lastError!, style: const TextStyle(fontSize: KdType.chip, color: KdColors.err)),
                ],
                if (s.kind == SourceType.m3U && _stage == null) ...[const SizedBox(height: 4), _GuideLine(source: s)],
              ],
            ),
          ),
          if (s.kind == SourceType.m3U && s.epgUrl != null) ...[
            KdButton(label: l10n.guideButton, icon: LucideIcons.calendarSync, onPressed: _stage == null ? _refreshGuide : null),
            const SizedBox(width: 6),
          ],
          if (!widget.active) KdButton(label: l10n.sourceActivate, onPressed: () => context.app.selectSource(s.id)),
          const SizedBox(width: 6),
          KdButton(label: l10n.actionSync, icon: LucideIcons.refreshCw, onPressed: _stage == null ? _sync : null),
          const SizedBox(width: 6),
          KdButton(label: l10n.actionDelete, icon: LucideIcons.trash2, kind: KdButtonKind.danger, onPressed: _stage == null ? _remove : null),
        ],
      ),
    );
  }
}

/// How an M3U source's XMLTV guide is doing, in one line.
class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.source});

  final SourceInfo source;

  @override
  Widget build(BuildContext context) {
    final g = source.guide;
    final (text, color) = switch ((source.epgUrl, g)) {
      (null, _) => (l10n.guideNoUrl, KdColors.muted),
      (_, null) => (l10n.guideNotYet, KdColors.muted),
      (_, final g?) when !g.ok => (l10n.guideFailed(g.error ?? ''), KdColors.err),
      (_, final g?) => (
          l10n.guideStatus('${g.matched}/${g.channels}', _count(g.programmes.toInt()), kdAgo(g.at)),
          g.matched == BigInt.zero ? KdColors.warn : KdColors.muted,
        ),
    };
    return Text(text, style: TextStyle(fontSize: KdType.chip, color: color));
  }
}

String _count(int n) => NumberFormat.compact(locale: languageCode).format(n);


/// "Updates": check, download with progress, install and restart, go back.
class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context) {
    final u = context.updates;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        final info = u.available;
        final status = switch (u.phase) {
          UpdatePhase.idle => l10n.updIdle(appVersion),
          UpdatePhase.checking => l10n.updChecking,
          UpdatePhase.upToDate => l10n.updUpToDate(appVersion),
          UpdatePhase.available || UpdatePhase.downloading || UpdatePhase.ready => l10n.updAvailable(info?.version ?? ''),
          UpdatePhase.failed => l10n.updFailed(u.error ?? ''),
        };
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KdColors.bg2,
            border: Border.all(color: u.phase == UpdatePhase.available || u.phase == UpdatePhase.ready ? KdColors.accentAlpha(0.45) : KdColors.line),
            borderRadius: BorderRadius.circular(KdRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.download, size: 15, color: KdColors.accent2),
                  const SizedBox(width: 8),
                  Text(l10n.updTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Text(status, style: TextStyle(color: u.phase == UpdatePhase.failed ? KdColors.err : KdColors.muted)),
              if (info != null && info.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(info.notes, style: const TextStyle(fontSize: KdType.small, height: 1.5)),
              ],
              if (u.phase == UpdatePhase.downloading) ...[
                const SizedBox(height: 10),
                SizedBox(width: 360, child: KdProgress(value: u.progress)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (u.phase == UpdatePhase.available)
                    KdButton(label: l10n.updDownload, icon: LucideIcons.download, kind: KdButtonKind.cta, onPressed: u.download)
                  else if (u.phase == UpdatePhase.ready)
                    KdButton(label: l10n.updInstall, icon: LucideIcons.refreshCw, kind: KdButtonKind.cta, onPressed: u.installAndRestart)
                  else
                    KdButton(
                      label: l10n.updCheck,
                      icon: LucideIcons.refreshCw,
                      onPressed: u.phase == UpdatePhase.checking || u.phase == UpdatePhase.downloading ? null : () => u.check(),
                    ),
                  if (u.previous case final p? when u.phase != UpdatePhase.downloading)
                    KdButton(label: l10n.updRollBack(p.$1), icon: LucideIcons.undo2, kind: KdButtonKind.ghost, onPressed: u.rollBack),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _host(String url) {
  final u = Uri.tryParse(url);
  return (u != null && u.host.isNotEmpty) ? u.host : url;
}

/// Display names (Turkish, English) for region codes providers use.
const _regionNames = {
  'TR': ('Türkiye', 'Türkiye'),
  'DE': ('Almanya', 'Germany'),
  'AT': ('Avusturya', 'Austria'),
  'CH': ('İsviçre', 'Switzerland'),
  'UK': ('Birleşik Krallık', 'United Kingdom'),
  'US': ('ABD', 'USA'),
  'CA': ('Kanada', 'Canada'),
  'FR': ('Fransa', 'France'),
  'ES': ('İspanya', 'Spain'),
  'PT': ('Portekiz', 'Portugal'),
  'IT': ('İtalya', 'Italy'),
  'NL': ('Hollanda', 'Netherlands'),
  'BE': ('Belçika', 'Belgium'),
  'PL': ('Polonya', 'Poland'),
  'RO': ('Romanya', 'Romania'),
  'BG': ('Bulgaristan', 'Bulgaria'),
  'GR': ('Yunanistan', 'Greece'),
  'AL': ('Arnavutluk', 'Albania'),
  'RS': ('Sırbistan', 'Serbia'),
  'HR': ('Hırvatistan', 'Croatia'),
  'BA': ('Bosna-Hersek', 'Bosnia and Herzegovina'),
  'MK': ('Kuzey Makedonya', 'North Macedonia'),
  'HU': ('Macaristan', 'Hungary'),
  'SE': ('İsveç', 'Sweden'),
  'NO': ('Norveç', 'Norway'),
  'DK': ('Danimarka', 'Denmark'),
  'FI': ('Finlandiya', 'Finland'),
  'RU': ('Rusya', 'Russia'),
  'UA': ('Ukrayna', 'Ukraine'),
  'AZ': ('Azerbaycan', 'Azerbaijan'),
  'AR': ('Arapça', 'Arabic'),
  'IR': ('İran', 'Iran'),
  'IN': ('Hindistan', 'India'),
  'PK': ('Pakistan', 'Pakistan'),
  'KU': ('Kürtçe', 'Kurdish'),
  'EXYU': ('Eski Yugoslavya', 'Ex-Yugoslavia'),
  'LAT': ('Latin Amerika', 'Latin America'),
};

String regionName(String code) {
  final n = _regionNames[code];
  if (n == null) return code;
  return languageCode == 'tr' ? n.$1 : n.$2;
}

class _PreferencesTab extends StatefulWidget {
  const _PreferencesTab();

  @override
  State<_PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<_PreferencesTab> {
  List<RegionCount> _regions = const [];
  bool _saving = false;

  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sid = context.app.activeSource?.id;
    if (sid != null && sid != _loadedFor) {
      _loadedFor = sid;
      context.library.sourceRegions(sid).then((r) {
        if (mounted) setState(() => _regions = r);
      });
    }
  }

  Future<void> _pick(String? region) async {
    setState(() => _saving = true);
    await context.app.setRegion(region);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final current = context.app.region;
    final codes = [
      if (current != null && !_regions.any((r) => r.region == current)) current,
      ..._regions.map((r) => r.region),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.prefLanguage, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            KdPill(label: l10n.prefLanguageSystem, selected: context.app.languageChoice == null, onTap: () => context.app.setLanguage(null)),
            KdPill(label: 'Türkçe', selected: context.app.languageChoice == 'tr', onTap: () => context.app.setLanguage('tr')),
            KdPill(label: 'English', selected: context.app.languageChoice == 'en', onTap: () => context.app.setLanguage('en')),
          ],
        ),
        const SizedBox(height: 28),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 22),
        Text(l10n.prefRegion, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          l10n.prefRegionBody,
          style: const TextStyle(color: KdColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            KdPill(label: l10n.prefOff, selected: current == null, onTap: () => _pick(null)),
            for (final code in codes)
              KdPill(
                label: regionName(code),
                trailing: _regions.where((r) => r.region == code).map((r) => '${r.count}').firstOrNull,
                selected: current == code,
                onTap: () => _pick(code),
              ),
          ],
        ),
        if (_saving) ...[const SizedBox(height: 12), const SizedBox(width: 200, child: KdIndeterminate())],
        if (_regions.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.prefRegionNone,
            style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
          ),
        ],
        const SizedBox(height: 28),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 22),
        const _TimeshiftSection(),
        const SizedBox(height: 28),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 22),
        const ParentalSettings(),
        const SizedBox(height: 28),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 22),
        const HiddenItemsSettings(),
        const SizedBox(height: 28),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 22),
        const TmdbSettings(),
        const SizedBox(height: 28),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 22),
        const _HistorySection(),
      ],
    );
  }
}

/// Local timeshift size: how much of a live channel is kept on disk to
/// pause and rewind.
class _TimeshiftSection extends StatelessWidget {
  const _TimeshiftSection();

  static const _sizes = [0, 1024, 2048, 4096, 8192];

  @override
  Widget build(BuildContext context) {
    final player = context.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.prefTimeshift, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(l10n.prefTimeshiftBody, style: const TextStyle(color: KdColors.muted, height: 1.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mb in _sizes)
                KdPill(
                  label: mb == 0 ? l10n.prefOff : '${mb ~/ 1024} GB',
                  trailing: mb == 0 ? null : l10n.prefTimeshiftMinutes(mb * 8 ~/ 2 ~/ 5 ~/ 60),
                  selected: player.timeshiftMb == mb,
                  onTap: () {
                    player.configureTimeshift(mb);
                    context.library.setAppSetting('timeshift_mb', '$mb');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Watch history": clears recent channels and resume points of the active
/// source after a confirmation; favorites are kept.
class _HistorySection extends StatefulWidget {
  const _HistorySection();

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  bool _done = false;

  Future<void> _clear() async {
    final sid = context.app.activeSource?.id;
    if (sid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KdColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KdRadius.card), side: const BorderSide(color: KdColors.line)),
        title: Text(l10n.historyClearAll, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        content: Text(l10n.historyClearBody, style: const TextStyle(color: KdColors.muted)),
        actions: [
          KdButton(label: l10n.actionCancel, onPressed: () => Navigator.pop(context, false)),
          KdButton(label: l10n.historyClear, kind: KdButtonKind.danger, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.library.clearHistory(sid);
    if (!mounted) return;
    setState(() => _done = true);
    context.app.historyCleared();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.historyTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l10n.historyClearBody, style: const TextStyle(color: KdColors.muted, height: 1.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            KdButton(label: l10n.historyClearAll, icon: LucideIcons.eraser, kind: KdButtonKind.danger, onPressed: _clear),
            if (_done) ...[
              const SizedBox(width: 12),
              Text(l10n.historyCleared, style: const TextStyle(color: KdColors.ok)),
            ],
          ],
        ),
      ],
    );
  }
}

/// TMDB key and language. The key is checked with TMDB before it is saved,
/// and lives in the OS keyring like source passwords.
class TmdbSettings extends StatefulWidget {
  const TmdbSettings({super.key});

  @override
  State<TmdbSettings> createState() => _TmdbSettingsState();
}

class _TmdbSettingsState extends State<TmdbSettings> {
  final _key = TextEditingController();
  TmdbStatus? _status;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status == null) _reload();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final s = await context.library.tmdbStatus();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _save(String? key) async {
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      await context.library.setTmdbKey(key);
      _key.clear();
      _done = key == null ? l10n.tmdbRemoved : l10n.tmdbSaved;
    } catch (e) {
      _error = errorText(e);
    }
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _language(String l) async {
    await context.library.setTmdbLanguage(l);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final on = s?.configured ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.tmdbTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            if (s != null) KdTag(on ? l10n.tagOn : l10n.tagOff, ok: on),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tmdbBody,
          style: const TextStyle(color: KdColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 420,
              child: KdInput(
                controller: _key,
                hint: on ? l10n.tmdbReplaceHint : l10n.tmdbKeyHint,
                obscure: true,
                mono: true,
                prefix: LucideIcons.keyRound,
                onSubmitted: (v) => v.trim().isEmpty ? null : _save(v.trim()),
              ),
            ),
            const SizedBox(width: 8),
            KdButton(
              label: l10n.tmdbVerify,
              icon: LucideIcons.check,
              kind: KdButtonKind.primary,
              onPressed: _busy ? null : () => _key.text.trim().isEmpty ? null : _save(_key.text.trim()),
            ),
            if (on) ...[
              const SizedBox(width: 8),
              KdButton(label: l10n.actionRemove, icon: LucideIcons.trash2, kind: KdButtonKind.danger, onPressed: _busy ? null : () => _save(null)),
            ],
          ],
        ),
        if (_busy) ...[const SizedBox(height: 10), const SizedBox(width: 420, child: KdIndeterminate())],
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: KdColors.err))],
        if (_done != null) ...[const SizedBox(height: 10), Text(_done!, style: const TextStyle(color: KdColors.ok))],
        const SizedBox(height: 10),
        Row(
          children: [
            Text(l10n.tmdbWhere, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
            const SizedBox(width: 6),
            KdButton(
              label: l10n.tmdbWhereLink,
              icon: LucideIcons.externalLink,
              kind: KdButtonKind.ghost,
              onPressed: () => launchUrl(Uri.parse('https://www.themoviedb.org/settings/api')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(l10n.tmdbLanguage, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final (code, label) in const [('tr-TR', 'Türkçe'), ('en-US', 'English')])
              KdPill(label: label, selected: s?.language == code, onTap: () => _language(code)),
          ],
        ),
      ],
    );
  }
}

class _ShortcutsTab extends StatelessWidget {
  const _ShortcutsTab();

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Ctrl K', l10n.navSearch),
      ('Ctrl 1 … 6', l10n.keySections),
      ('Ctrl ,', l10n.navSettings),
      ('↑ / ↓', l10n.keyZap),
      ('0 … 9', l10n.keyDigits),
      (l10n.keyMediaKeys, l10n.keyMediaKeysDo),
      ('PgUp / PgDn', l10n.keyPage),
      ('Enter', l10n.keyEnter),
      ('Space', l10n.tipPlayPause),
      ('← / →', l10n.keySeek),
      (l10n.keyFKey, l10n.keyFullscreen),
      ('A, S', l10n.keyTracks),
      ('L', l10n.keyChannelList),
      ('Z / X', l10n.keySubtitleDelay),
      ('I', l10n.keyStats),
      ('M', l10n.keyMute),
      ('Esc', l10n.keyEsc),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final (k, d) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: KdKbd(k))),
                Expanded(child: Text(d)),
              ],
            ),
          ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Image.asset('assets/brand/logo.png', width: 44, height: 44),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Karadelik IPTV Player', style: TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
                Text(l10n.aboutVersion(appVersion), style: const TextStyle(color: KdColors.muted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(l10n.aboutDisclaimer, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        Text(l10n.aboutPrivacy, style: const TextStyle(height: 1.5, color: KdColors.muted)),
        const SizedBox(height: 14),
        // Required wording of TMDB's API terms (English in every language).
        Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB. ${l10n.aboutTmdb}',
          style: const TextStyle(height: 1.5, color: KdColors.muted, fontSize: KdType.small),
        ),
        const SizedBox(height: 22),
        const _UpdatesSection(),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: KdButton(
            label: l10n.aboutLicenses,
            icon: LucideIcons.scrollText,
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Karadelik IPTV Player',
              applicationVersion: appVersion,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/brand/logo.png', width: 40, height: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
