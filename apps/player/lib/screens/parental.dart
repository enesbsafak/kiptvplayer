import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show AnyhowException;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_category_rail.dart';
import '../design/widgets/kd_controls.dart';
import '../l10n/l10n.dart';

/// Asks for the parental PIN and unlocks adult content; true when unlocked.
Future<bool> askPinToUnlock(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(
      title: l10n.pinUnlockTitle,
      body: l10n.pinUnlockBody,
      submit: (pin) async => await context.app.unlockAdult(pin) ? null : l10n.pinWrong,
    ),
  );
  return ok ?? false;
}

/// Sets a new PIN (typed twice), changing or replacing the old one.
Future<void> askNewPin(BuildContext context) async {
  final app = context.app;
  String? current;
  if (app.parental.pinSet) {
    current = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(title: l10n.pinCurrentTitle, body: l10n.pinCurrentBody, returnPin: true),
    );
    if (current == null || !context.mounted) return;
  }
  final first = await showDialog<String>(
    context: context,
    builder: (_) => _PinDialog(title: l10n.pinNewTitle, body: l10n.pinNewBody, returnPin: true),
  );
  if (first == null || !context.mounted) return;
  await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(
      title: l10n.pinRepeatTitle,
      body: l10n.pinRepeatBody,
      submit: (pin) async {
        if (pin != first) return l10n.pinMismatch;
        await app.setPin(current: current, pin: pin);
        return null;
      },
    ),
  );
}

/// Removes the PIN after asking for it.
Future<void> askRemovePin(BuildContext context) async {
  final app = context.app;
  await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(
      title: l10n.pinRemoveTitle,
      body: l10n.pinCurrentBody,
      submit: (pin) async {
        await app.setPin(current: pin, pin: null);
        return null;
      },
    ),
  );
}

/// A PIN prompt. [submit] returns an error to show, or null when done;
/// with [returnPin] the dialog just hands the digits back.
class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, required this.body, this.submit, this.returnPin = false});

  final String title;
  final String body;
  final Future<String?> Function(String pin)? submit;
  final bool returnPin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final pin = _pin.text;
    if (pin.length < 4) {
      setState(() => _error = l10n.pinTooShort);
      return;
    }
    if (widget.returnPin) {
      Navigator.pop(context, pin);
      return;
    }
    setState(() => _busy = true);
    String? error;
    try {
      error = await widget.submit!(pin);
    } on AnyhowException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KdColors.bg2,
      shape: kdDialogShape,
      title: Row(
        children: [
          const Icon(LucideIcons.lock, size: 16, color: KdColors.accent),
          const SizedBox(width: 10),
          Text(widget.title, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body, style: const TextStyle(color: KdColors.muted, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '●',
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 10),
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _go(),
            ),
            if (_error case final e?) ...[
              const SizedBox(height: 8),
              Text(e, style: const TextStyle(color: KdColors.err, fontSize: KdType.small)),
            ],
          ],
        ),
      ),
      actions: [
        KdButton(label: l10n.actionCancel, onPressed: () => Navigator.pop(context)),
        KdButton(label: l10n.pinOk, kind: KdButtonKind.cta, onPressed: _busy ? null : _go),
      ],
    );
  }
}

/// At the foot of a category rail while the lock hides adult categories:
/// how many, and the way to open them.
class LockedCategoriesRow extends StatelessWidget {
  const LockedCategoriesRow({super.key, required this.kind});

  final Kind kind;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final sid = app.activeSource?.id;
    if (sid == null || !app.parental.locked) return const SizedBox.shrink();
    return FutureBuilder<int>(
      key: ValueKey('${app.catalogVersion}-$sid-$kind'),
      future: context.library.lockedCategories(sid, kind),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: KdCategoryRow(
            name: l10n.pinLockedCategories,
            count: n,
            icon: LucideIcons.lock,
            active: false,
            onTap: () => askPinToUnlock(context),
          ),
        );
      },
    );
  }
}

/// Settings: set, change or remove the PIN; lock again.
class ParentalSettings extends StatelessWidget {
  const ParentalSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.parental;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pinTitle, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          !p.pinSet ? l10n.pinBodyOff : (p.locked ? l10n.pinBodyLocked : l10n.pinBodyOpen),
          style: const TextStyle(color: KdColors.muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!p.pinSet) KdButton(label: l10n.pinSet, icon: LucideIcons.lock, onPressed: () => askNewPin(context)),
            if (p.pinSet && p.locked) KdButton(label: l10n.pinUnlock, icon: LucideIcons.lockOpen, onPressed: () => askPinToUnlock(context)),
            if (p.pinSet && !p.locked) KdButton(label: l10n.pinLockNow, icon: LucideIcons.lock, onPressed: app.lockAdult),
            if (p.pinSet) KdButton(label: l10n.pinChange, kind: KdButtonKind.ghost, onPressed: () => askNewPin(context)),
            if (p.pinSet) KdButton(label: l10n.pinRemove, kind: KdButtonKind.ghost, onPressed: () => askRemovePin(context)),
          ],
        ),
      ],
    );
  }
}
