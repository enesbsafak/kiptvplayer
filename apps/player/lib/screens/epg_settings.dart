import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_icon_button.dart';
import '../l10n/l10n.dart';

/// "Yayın akışı ayarı": a channel's guide shifted in 15-minute steps and,
/// with an XMLTV guide, matched by hand to the right guide channel (or
/// none). Kept in the library, so guide refreshes keep it.
Future<void> showEpgSettings(BuildContext context, Item item) async {
  final settings = await context.library.epgSettings(item.id);
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => _EpgSettingsDialog(item: item, initial: settings));
}

/// "+1 sa 30 dk", "−45 dk", "0".
String shiftText(int minutes) {
  if (minutes == 0) return l10n.epgShiftNone;
  final sign = minutes > 0 ? '+' : '−';
  final h = minutes.abs() ~/ 60, m = minutes.abs() % 60;
  return '$sign${[if (h > 0) l10n.epgHours(h), if (m > 0) l10n.epgMinutes(m)].join(' ')}';
}

class _EpgSettingsDialog extends StatefulWidget {
  const _EpgSettingsDialog({required this.item, required this.initial});

  final Item item;
  final EpgSettings initial;

  @override
  State<_EpgSettingsDialog> createState() => _EpgSettingsDialogState();
}

class _EpgSettingsDialogState extends State<_EpgSettingsDialog> {
  late int _shift = widget.initial.shiftMinutes;
  late String? _forced = widget.initial.forced;
  late String? _forcedLabel = widget.initial.forcedLabel;
  final _query = TextEditingController();
  List<GuideEntry> _found = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final sid = context.app.activeSource?.id;
      if (sid == null) return;
      final found = q.trim().isEmpty ? const <GuideEntry>[] : await context.library.findGuideChannels(sid, q);
      if (mounted) setState(() => _found = found);
    });
  }

  Future<void> _save() async {
    final app = context.app;
    await context.library.setEpgSettings(widget.item.id, forced: _forced, shiftMinutes: _shift);
    // Cached now/next is stale for this channel: reload guides.
    await app.guideUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.initial;
    final current = switch (_forced) {
      null => s.mapped == null ? l10n.epgAutoNone : l10n.epgAutoMatched(s.mapped!.label),
      '' => l10n.epgNoGuide,
      final id => l10n.epgPicked(_forcedLabel ?? id),
    };
    return AlertDialog(
      backgroundColor: KdColors.bg2,
      shape: kdDialogShape,
      title: Text(l10n.epgSettingsTitle(widget.item.name), style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.epgShift, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l10n.epgShiftBody, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small, height: 1.4)),
            const SizedBox(height: 10),
            Row(
              children: [
                KdIconButton(icon: LucideIcons.minus, tooltip: '−15', onPressed: () => setState(() => _shift = (_shift - 15).clamp(-1440, 1440))),
                SizedBox(
                  width: 140,
                  child: Text(
                    shiftText(_shift),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: KdType.title, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                KdIconButton(icon: LucideIcons.plus, tooltip: '+15', onPressed: () => setState(() => _shift = (_shift + 15).clamp(-1440, 1440))),
              ],
            ),
            if (s.hasGuide) ...[
              const SizedBox(height: 22),
              Text(l10n.epgMatch, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(current, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  KdPill(
                    label: l10n.epgAuto,
                    selected: _forced == null,
                    onTap: () => setState(() {
                      _forced = null;
                      _forcedLabel = null;
                    }),
                  ),
                  KdPill(
                    label: l10n.epgNoGuideShort,
                    selected: _forced == '',
                    onTap: () => setState(() {
                      _forced = '';
                      _forcedLabel = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              KdInput(controller: _query, hint: l10n.epgFindHint, prefix: LucideIcons.search, onChanged: _search),
              if (_found.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final g in _found)
                        ListTile(
                          dense: true,
                          selected: _forced == g.id,
                          selectedColor: KdColors.accent2,
                          leading: Icon(_forced == g.id ? LucideIcons.check : LucideIcons.tv, size: 15),
                          title: Text(g.label),
                          subtitle: Text(g.id, style: const TextStyle(color: KdColors.muted, fontSize: KdType.tag)),
                          onTap: () => setState(() {
                            _forced = g.id;
                            _forcedLabel = g.label;
                          }),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        KdButton(label: l10n.actionCancel, onPressed: () => Navigator.pop(context)),
        KdButton(label: l10n.epgSave, kind: KdButtonKind.cta, onPressed: _save),
      ],
    );
  }
}
