import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show AnyhowException;
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../l10n/l10n.dart';

/// Settings: an encrypted backup of everything the user made, and the way
/// back on this or another computer. Catalogs are not in it: restored
/// sources sync afterwards.
class BackupSettings extends StatefulWidget {
  const BackupSettings({super.key});

  @override
  State<BackupSettings> createState() => _BackupSettingsState();
}

class _BackupSettingsState extends State<BackupSettings> {
  String? _status;
  bool _error = false;
  bool _busy = false;

  static final _type = XTypeGroup(label: 'Karadelik', extensions: const ['kpbackup']);

  void _say(String text, {bool error = false}) => setState(() {
    _status = text;
    _error = error;
  });

  Future<void> _export() async {
    final password = await _askPassword(context, confirm: true);
    if (password == null || !mounted) return;
    final name = 'karadelik-yedek-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.kpbackup';
    final where = await getSaveLocation(suggestedName: name, acceptedTypeGroups: [_type]);
    if (where == null || !mounted) return;
    final path = where.path.toLowerCase().endsWith('.kpbackup') ? where.path : '${where.path}.kpbackup';
    setState(() => _busy = true);
    try {
      final c = await context.library.exportBackup(path, password);
      _say(l10n.backupSaved(c.sources, c.favorites, c.groups));
    } on AnyhowException catch (e) {
      _say(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: [_type]);
    if (file == null || !mounted) return;
    final password = await _askPassword(context, confirm: false);
    if (password == null || !mounted) return;
    final app = context.app;
    final lib = context.library;
    setState(() => _busy = true);
    try {
      final r = await lib.importBackup(file.path, password);
      for (final (i, id) in r.toSync.indexed) {
        _say(l10n.backupSyncing(i + 1, r.toSync.length));
        await for (final e in lib.syncSource(id)) {
          if (e is SyncEvent_Failed) break;
        }
      }
      await app.restored();
      _say(l10n.backupRestored(r.counts.sources, r.counts.favorites, r.counts.groups));
    } on AnyhowException catch (e) {
      _say(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.backupTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l10n.backupBody, style: const TextStyle(color: KdColors.muted, height: 1.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KdButton(label: l10n.backupExport, icon: LucideIcons.download, onPressed: _busy ? null : _export),
            KdButton(label: l10n.backupImport, icon: LucideIcons.upload, kind: KdButtonKind.ghost, onPressed: _busy ? null : _import),
          ],
        ),
        if (_busy) ...[const SizedBox(height: 12), const SizedBox(width: 220, child: KdIndeterminate())],
        if (_status case final s?) ...[
          const SizedBox(height: 10),
          Text(s, style: TextStyle(color: _error ? KdColors.err : KdColors.ok, fontSize: KdType.small)),
        ],
      ],
    );
  }
}

/// The backup's password; with [confirm], typed twice and 8+ characters.
Future<String?> _askPassword(BuildContext context, {required bool confirm}) =>
    showDialog<String>(context: context, builder: (_) => _PasswordDialog(confirm: confirm));

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _go() {
    final p = _first.text;
    if (widget.confirm && p.length < 8) {
      setState(() => _error = l10n.backupPasswordShort);
    } else if (widget.confirm && p != _second.text) {
      setState(() => _error = l10n.backupPasswordMismatch);
    } else if (p.isNotEmpty) {
      Navigator.pop(context, p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KdColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KdRadius.card), side: const BorderSide(color: KdColors.line)),
      title: Text(widget.confirm ? l10n.backupPasswordNew : l10n.backupPasswordAsk, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.confirm ? l10n.backupPasswordNewBody : l10n.backupPasswordAskBody,
              style: const TextStyle(color: KdColors.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            KdInput(controller: _first, obscure: true, autofocus: true, hint: l10n.backupPassword, onSubmitted: (_) => _go()),
            if (widget.confirm) ...[
              const SizedBox(height: 8),
              KdInput(controller: _second, obscure: true, hint: l10n.backupPasswordAgain, onSubmitted: (_) => _go()),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: 8),
              Text(e, style: const TextStyle(color: KdColors.err, fontSize: KdType.small)),
            ],
          ],
        ),
      ),
      actions: [
        KdButton(label: l10n.actionCancel, onPressed: () => Navigator.pop(context)),
        KdButton(label: l10n.pinOk, kind: KdButtonKind.cta, onPressed: _go),
      ],
    );
  }
}
