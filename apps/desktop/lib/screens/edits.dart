import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../l10n/l10n.dart';

/// The user's own channel list: hide, rename, reorder categories and keep
/// custom groups. Everything is stored by stable id in the core and laid
/// over each sync, so a provider refresh keeps it.

/// A right-click menu at [at] (global position); runs the picked action.
Future<void> _menu(BuildContext context, Offset at, List<(IconData, String, Future<void> Function())?> entries) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(at);
  final picked = await showMenu<int>(
    context: context,
    color: KdColors.bg2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KdRadius.card), side: const BorderSide(color: KdColors.line)),
    position: RelativeRect.fromLTRB(local.dx, local.dy, overlay.size.width - local.dx, overlay.size.height - local.dy),
    items: [
      for (final (i, e) in entries.indexed)
        if (e == null)
          const PopupMenuDivider(height: 8)
        else
          PopupMenuItem<int>(
            value: i,
            height: 36,
            child: Row(
              children: [
                Icon(e.$1, size: 15, color: KdColors.muted),
                const SizedBox(width: 10),
                Flexible(child: Text(e.$2, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
    ],
  );
  if (picked == null) return;
  await entries[picked]!.$3();
}

/// Asks for a name; '' means "back to the provider's" (when [original] is
/// given), null means cancelled.
Future<String?> askName(BuildContext context, {required String title, required String initial, String? original}) =>
    showDialog<String>(context: context, builder: (_) => _NameDialog(title: title, initial: initial, original: original));

/// Owns its text controller, so it outlives the closing animation.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial, this.original});

  final String title;
  final String initial;
  final String? original;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.original;
    return AlertDialog(
      backgroundColor: KdColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KdRadius.card), side: const BorderSide(color: KdColors.line)),
      title: Text(widget.title, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KdInput(controller: _text, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v.trim())),
            if (original != null) ...[
              const SizedBox(height: 8),
              Text(l10n.editOriginalName(original), style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
            ],
          ],
        ),
      ),
      actions: [
        if (original != null) KdButton(label: l10n.editResetName, kind: KdButtonKind.ghost, onPressed: () => Navigator.pop(context, '')),
        KdButton(label: l10n.actionCancel, onPressed: () => Navigator.pop(context)),
        KdButton(label: l10n.pinOk, kind: KdButtonKind.cta, onPressed: () => Navigator.pop(context, _text.text.trim())),
      ],
    );
  }
}

/// Provider category: rename, move, hide.
Future<void> showCategoryMenu(BuildContext context, {required Offset at, required Kind kind, required Category category}) {
  final app = context.app;
  final lib = context.library;
  final sid = app.activeSource?.id;
  if (sid == null) return Future.value();
  return _menu(context, at, [
    (LucideIcons.pencil, l10n.editRename, () async {
      final original = await lib.originalName(sid, category.uid, category: true);
      if (!context.mounted) return;
      final name = await askName(context, title: l10n.editRenameCategory, initial: category.name, original: original);
      if (name == null) return;
      await lib.renameCategory(sid, category.uid, name.isEmpty ? null : name);
      app.editsChanged();
    }),
    (LucideIcons.arrowUp, l10n.editMoveUp, () async {
      await lib.moveCategory(sid, kind, category.uid, -1);
      app.editsChanged();
    }),
    (LucideIcons.arrowDown, l10n.editMoveDown, () async {
      await lib.moveCategory(sid, kind, category.uid, 1);
      app.editsChanged();
    }),
    null,
    (LucideIcons.eyeOff, l10n.editHideCategory, () async {
      await lib.hideCategory(sid, category.uid, hidden: true);
      app.editsChanged();
    }),
  ]);
}

/// Custom group: rename, move, delete.
Future<void> showGroupMenu(BuildContext context, {required Offset at, required Category group}) {
  final app = context.app;
  final lib = context.library;
  return _menu(context, at, [
    (LucideIcons.pencil, l10n.editRename, () async {
      final name = await askName(context, title: l10n.editRenameGroup, initial: group.name);
      if (name == null || name.isEmpty) return;
      await lib.renameGroup(group.uid, name);
      app.editsChanged();
    }),
    (LucideIcons.arrowUp, l10n.editMoveUp, () async {
      await lib.moveGroup(group.uid, -1);
      app.editsChanged();
    }),
    (LucideIcons.arrowDown, l10n.editMoveDown, () async {
      await lib.moveGroup(group.uid, 1);
      app.editsChanged();
    }),
    null,
    (LucideIcons.trash2, l10n.editDeleteGroup, () async {
      await lib.deleteGroup(group.uid);
      app.editsChanged();
    }),
  ]);
}

/// A live channel: rename, hide, put into a group; inside a group
/// ([groupId]) also move or take out.
Future<void> showChannelMenu(BuildContext context, {required Offset at, required Item item, int? groupId}) async {
  final app = context.app;
  final lib = context.library;
  final sid = app.activeSource?.id;
  if (sid == null) return;
  final groups = await lib.userGroups(sid, Kind.live);
  if (!context.mounted) return;
  await _menu(context, at, [
    (LucideIcons.pencil, l10n.editRename, () async {
      final original = await lib.originalName(sid, item.uid, category: false);
      if (!context.mounted) return;
      final name = await askName(context, title: l10n.editRenameChannel, initial: item.name, original: original);
      if (name == null) return;
      await lib.renameChannel(item.id, name.isEmpty ? null : name);
      app.editsChanged();
    }),
    (LucideIcons.eyeOff, l10n.editHideChannel, () async {
      await lib.hideChannel(item.id, hidden: true);
      app.editsChanged();
    }),
    null,
    if (groupId != null) ...[
      (LucideIcons.arrowUp, l10n.editMoveUp, () async {
        await lib.moveInGroup(groupId, item.id, -1);
        app.editsChanged();
      }),
      (LucideIcons.arrowDown, l10n.editMoveDown, () async {
        await lib.moveInGroup(groupId, item.id, 1);
        app.editsChanged();
      }),
      (LucideIcons.folderMinus, l10n.editRemoveFromGroup, () async {
        await lib.removeFromGroup(groupId, item.id);
        app.editsChanged();
      }),
      null,
    ],
    for (final g in groups)
      if (g.uid != groupId)
        (LucideIcons.folderPlus, l10n.editAddToGroup(g.name), () async {
          await lib.addToGroup(g.uid, item.id);
          app.editsChanged();
        }),
    (LucideIcons.folderPlus, l10n.editNewGroup, () async {
      final name = await askName(context, title: l10n.editNewGroupTitle, initial: '');
      if (name == null || name.isEmpty) return;
      final id = await lib.createGroup(sid, Kind.live, name);
      await lib.addToGroup(id, item.id);
      app.editsChanged();
    }),
  ]);
}

/// Settings: what was hidden, each with "Göster".
class HiddenItemsSettings extends StatefulWidget {
  const HiddenItemsSettings({super.key});

  @override
  State<HiddenItemsSettings> createState() => _HiddenItemsSettingsState();
}

class _HiddenItemsSettingsState extends State<HiddenItemsSettings> {
  HiddenItems? _hidden;
  String? _loadedFor;
  int _version = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.app;
    final sid = app.activeSource?.id;
    if (sid != null && (sid != _loadedFor || app.catalogVersion != _version)) {
      _loadedFor = sid;
      _version = app.catalogVersion;
      context.library.hiddenItems(sid).then((h) {
        if (mounted) setState(() => _hidden = h);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hidden;
    final lib = context.library;
    final app = context.app;
    final sid = app.activeSource?.id;
    final empty = h == null || (h.categories.isEmpty && h.channels.isEmpty);
    Widget row(IconData icon, String name, Future<void> Function() show) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: KdColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          KdButton(
            label: l10n.editShow,
            icon: LucideIcons.eye,
            kind: KdButtonKind.ghost,
            onPressed: () async {
              await show();
              app.editsChanged();
            },
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.editHiddenTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(empty ? l10n.editHiddenNone : l10n.editHiddenBody, style: const TextStyle(color: KdColors.muted, height: 1.5)),
        if (!empty && sid != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 520,
            child: Column(
              children: [
                for (final c in h.categories) row(LucideIcons.folder, c.name, () => lib.hideCategory(sid, c.uid, hidden: false)),
                for (final c in h.channels) row(LucideIcons.tv, c.name, () => lib.hideChannel(c.id, hidden: false)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
