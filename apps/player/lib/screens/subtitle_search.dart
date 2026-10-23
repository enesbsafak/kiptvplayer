import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/media_track.dart';
import '../player/player_controller.dart';

/// OpenSubtitles from the player: results for the film or episode playing,
/// most downloaded first; a click downloads and turns it on.
Future<void> showSubtitleSearch(BuildContext context, PlayerController player) =>
    showDialog<void>(context: context, builder: (_) => _SubtitleSearch(player: player));

class _SubtitleSearch extends StatefulWidget {
  const _SubtitleSearch({required this.player});

  final PlayerController player;

  @override
  State<_SubtitleSearch> createState() => _SubtitleSearchState();
}

class _SubtitleSearchState extends State<_SubtitleSearch> {
  bool? _configured;
  List<SubtitleResult>? _results;
  String? _error;
  int? _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured == null) _start();
  }

  Future<void> _start() async {
    final lib = context.library;
    final on = await lib.opensubsConfigured();
    if (!mounted) return;
    setState(() => _configured = on);
    final n = widget.player.now;
    if (!on || n == null) return;
    try {
      final r = await lib.subtitleSearch(n.item.id, season: n.episode?.season, episode: n.episode?.number);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  Future<void> _pick(SubtitleResult r) async {
    setState(() {
      _loading = r.fileId;
      _error = null;
    });
    try {
      final file = await context.library.subtitleDownload(r.fileId);
      await widget.player.addSubtitleFile(file.path, title: 'OpenSubtitles', language: r.language);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = null;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return AlertDialog(
      backgroundColor: KdColors.bg2,
      shape: kdDialogShape,
      title: Text(l10n.subsTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_configured == false) ...[
              Text(l10n.subsNoKey, style: const TextStyle(color: KdColors.muted, height: 1.5)),
              const SizedBox(height: 12),
              KdButton(
                label: l10n.subsOpenSettings,
                icon: LucideIcons.settings,
                onPressed: () {
                  final app = context.app;
                  Navigator.pop(context);
                  widget.player.setView(PlayerView.preview);
                  app.openSettings('preferences');
                },
              ),
            ] else if (results == null && _error == null)
              const KdIndeterminate()
            else if (results != null && results.isEmpty)
              Text(l10n.subsNone, style: const TextStyle(color: KdColors.muted))
            else if (results != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final r in results) _ResultRow(result: r, busy: _loading == r.fileId, onTap: _loading == null ? () => _pick(r) : null)],
                ),
              ),
            if (_error case final e?) ...[
              const SizedBox(height: 10),
              Text(e, style: const TextStyle(color: KdColors.err, fontSize: KdType.small)),
            ],
          ],
        ),
      ),
      actions: [KdButton(label: l10n.actionClose, onPressed: () => Navigator.pop(context))],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.busy, required this.onTap});

  final SubtitleResult result;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KdRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: Row(
          children: [
            SizedBox(width: 86, child: Text(languageName(r.language) ?? r.language.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.release.isEmpty ? r.fileName : r.release, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    l10n.subsDownloads(NumberFormat.compact(locale: languageCode).format(r.downloads)),
                    style: const TextStyle(color: KdColors.muted, fontSize: KdType.small),
                  ),
                ],
              ),
            ),
            if (r.hearingImpaired) ...[const SizedBox(width: 6), const KdTag('SDH')],
            if (r.machine) ...[const SizedBox(width: 6), KdTag(l10n.subsMachine)],
            const SizedBox(width: 10),
            SizedBox(
              width: 18,
              height: 18,
              child: busy ? const CircularProgressIndicator(strokeWidth: 2, color: KdColors.accent) : const Icon(LucideIcons.download, size: 16, color: KdColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings: the user's own OpenSubtitles API key.
class OpenSubsSettings extends StatefulWidget {
  const OpenSubsSettings({super.key});

  @override
  State<OpenSubsSettings> createState() => _OpenSubsSettingsState();
}

class _OpenSubsSettingsState extends State<OpenSubsSettings> {
  final _key = TextEditingController();
  bool? _on;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_on == null) _reload();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final on = await context.library.opensubsConfigured();
    if (mounted) setState(() => _on = on);
  }

  Future<void> _save(String? key) async {
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      await context.library.setOpensubsKey(key);
      _key.clear();
      _done = key == null ? l10n.tmdbRemoved : l10n.tmdbSaved;
    } catch (e) {
      _error = errorText(e);
    }
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final on = _on ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.subsSettingsTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            if (_on != null) KdTag(on ? l10n.tagOn : l10n.tagOff, ok: on),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.subsSettingsBody, style: const TextStyle(color: KdColors.muted, height: 1.5)),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 420,
              child: KdInput(
                controller: _key,
                hint: on ? l10n.tmdbReplaceHint : l10n.subsKeyHint,
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
        KdButton(
          label: l10n.subsWhereLink,
          icon: LucideIcons.externalLink,
          kind: KdButtonKind.ghost,
          onPressed: () => launchUrl(Uri.parse('https://www.opensubtitles.com/consumers')),
        ),
      ],
    );
  }
}
