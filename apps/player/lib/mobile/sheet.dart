import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import 'glass.dart';

/// Android's modal bottom sheet in glass: a drag handle, swiped down or
/// backed out of (with the predictive back), the content scrolling inside.
Future<T?> showKdSheet<T>(BuildContext context, {required WidgetBuilder builder, double? heightFactor}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x99000000),
    builder: (sheet) {
      final body = builder(sheet);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: KdGlass(
          borderRadius: BorderRadius.circular(KdGlassTokens.radiusSheet),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Handle(),
                if (heightFactor == null)
                  Flexible(child: body)
                else
                  SizedBox(height: MediaQuery.sizeOf(sheet).height * heightFactor, child: body),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: const Color(0x55FFFFFF), borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// An item's actions (a long press on a channel, a category) as a sheet of
/// rows, Android's answer to a right-click menu. Null entries are dividers.
Future<int?> showKdActionSheet(BuildContext context, {String? title, required List<(IconData, String)?> entries}) {
  return showKdSheet<int>(
    context,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
          ),
        for (final (i, e) in entries.indexed)
          if (e == null)
            const Divider(height: 9, indent: 24, endIndent: 24, color: Color(0x1FFFFFFF))
          else
            _ActionRow(icon: e.$1, label: e.$2, onTap: () => Navigator.of(sheet).pop(i)),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: KdRipple(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: KdColors.muted),
                  const SizedBox(width: 18),
                  Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
