import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../l10n/l10n.dart';

enum _Type { xtream, m3uUrl, m3uFile }

/// Connect → sync → summary. Used for first run and from Settings.
class AddSourceForm extends StatefulWidget {
  const AddSourceForm({super.key, this.onDone, this.onCancel});

  final ValueChanged<SourceInfo>? onDone;
  final VoidCallback? onCancel;

  @override
  State<AddSourceForm> createState() => _AddSourceFormState();
}

class _AddSourceFormState extends State<AddSourceForm> {
  _Type _type = _Type.xtream;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _agent = TextEditingController();
  final _epg = TextEditingController();
  bool _insecure = false;
  bool _advanced = false;

  String? _stage;
  String? _error;
  SourceInfo? _done;
  StreamSubscription<SyncEvent>? _sub;

  bool get _busy => _stage != null;

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in [_name, _url, _user, _pass, _agent, _epg]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_url.text.trim().isEmpty) {
      return switch (_type) {
        _Type.xtream => l10n.addNeedServer,
        _Type.m3uUrl => l10n.addNeedListUrl,
        _Type.m3uFile => l10n.addNeedFile,
      };
    }
    if (_type == _Type.xtream && _user.text.trim().isEmpty) return l10n.addNeedUser;
    if (_type == _Type.xtream && _pass.text.isEmpty) return l10n.addNeedPassword;
    return null;
  }

  void _submit() {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final input = NewSourceInput(
      isXtream: _type == _Type.xtream,
      name: _name.text.trim(),
      url: _url.text.trim(),
      username: _type == _Type.xtream ? _user.text.trim() : null,
      password: _type == _Type.xtream ? _pass.text : null,
      userAgent: _agent.text.trim().isEmpty ? null : _agent.text.trim(),
      insecureTls: _insecure,
      epgUrl: _type != _Type.xtream && _epg.text.trim().isNotEmpty ? _epg.text.trim() : null,
    );
    setState(() {
      _error = null;
      _stage = l10n.syncConnecting;
    });
    _sub = context.library.addSource(input).listen((e) {
      if (!mounted) return;
      setState(() {
        switch (e) {
          case SyncEvent_Connecting():
            _stage = l10n.syncConnectingProvider;
          case SyncEvent_Downloading(:final what):
            _stage = l10n.syncDownloading(what);
          case SyncEvent_Saving():
            _stage = l10n.syncPreparing;
          case SyncEvent_Done(:final source):
            _stage = null;
            _done = source;
          case SyncEvent_Failed(:final message):
            _stage = null;
            _error = message;
        }
      });
    });
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.addPlaylistFiles, extensions: const ['m3u', 'm3u8', 'txt']),
      ],
    );
    if (file != null) setState(() => _url.text = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) return _Summary(source: done, onContinue: () => widget.onDone?.call(done));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _TypeCard(
              icon: LucideIcons.server,
              title: 'Xtream Codes',
              hint: l10n.addXtreamHint,
              selected: _type == _Type.xtream,
              onTap: () => setState(() => _type = _Type.xtream),
            ),
            const SizedBox(width: 10),
            _TypeCard(
              icon: LucideIcons.link,
              title: l10n.addM3uUrl,
              hint: l10n.addM3uUrlHint,
              selected: _type == _Type.m3uUrl,
              onTap: () => setState(() => _type = _Type.m3uUrl),
            ),
            const SizedBox(width: 10),
            _TypeCard(
              icon: LucideIcons.fileText,
              title: l10n.addM3uFile,
              hint: l10n.addM3uFileHint,
              selected: _type == _Type.m3uFile,
              onTap: () => setState(() => _type = _Type.m3uFile),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Row(label: l10n.addName, child: KdInput(controller: _name, hint: l10n.addNameHint)),
        if (_type == _Type.xtream) ...[
          _Row(label: l10n.addServer, child: KdInput(controller: _url, hint: l10n.addServerHint, mono: true)),
          _Row(label: l10n.addUser, child: KdInput(controller: _user)),
          _Row(label: l10n.addPassword, child: KdInput(controller: _pass, obscure: true, onSubmitted: (_) => _submit())),
        ] else if (_type == _Type.m3uUrl)
          _Row(label: l10n.addListUrl, child: KdInput(controller: _url, hint: 'https://…/playlist.m3u', mono: true, onSubmitted: (_) => _submit()))
        else
          _Row(
            label: l10n.addFile,
            child: Row(
              children: [
                Expanded(child: KdInput(controller: _url, hint: l10n.addNoFile, mono: true)),
                const SizedBox(width: 8),
                KdButton(label: l10n.addChoose, icon: LucideIcons.fileText, onPressed: _busy ? null : _pickFile),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 150, top: 2, bottom: 6),
          child: GestureDetector(
            onTap: () => setState(() => _advanced = !_advanced),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                _advanced ? l10n.addAdvancedHide : l10n.addAdvanced,
                style: const TextStyle(fontSize: KdType.small, color: KdColors.accent2),
              ),
            ),
          ),
        ),
        if (_advanced) ...[
          _Row(label: 'User-Agent', child: KdInput(controller: _agent, hint: l10n.addUserAgentHint, mono: true)),
          if (_type != _Type.xtream)
            _Row(
              label: l10n.addGuideUrl,
              child: KdInput(controller: _epg, hint: l10n.addGuideUrlHint, mono: true),
            ),
          _Row(
            label: '',
            child: KdCheck(
              value: _insecure,
              onChanged: (v) => setState(() => _insecure = v),
              label: l10n.addInsecure,
              hint: l10n.addInsecureHint,
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1, color: KdColors.line),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _busy
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stage!, style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
                        const SizedBox(height: 6),
                        const SizedBox(width: 220, child: KdIndeterminate()),
                      ],
                    )
                  : _error != null
                      ? Row(
                          children: [
                            const Icon(LucideIcons.circleAlert, size: 14, color: KdColors.err),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_error!, style: const TextStyle(fontSize: KdType.small, color: KdColors.err)),
                            ),
                          ],
                        )
                      : Text(
                          l10n.addPasswordNote,
                          style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
                        ),
            ),
            if (widget.onCancel != null) ...[
              KdButton(label: l10n.actionCancel, onPressed: _busy ? null : widget.onCancel),
              const SizedBox(width: 8),
            ],
            KdButton(
              label: l10n.addConnect,
              kind: KdButtonKind.cta,
              large: true,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: KdColors.muted))),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({required this.icon, required this.title, required this.hint, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel ? KdColors.accentAlpha(0.08) : (_hover ? KdColors.buttonHoverBg : KdColors.bg2),
              border: Border.all(color: sel ? KdColors.accentAlpha(0.45) : KdColors.line),
              borderRadius: BorderRadius.circular(KdRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, size: 18, color: sel ? KdColors.accent2 : KdColors.muted),
                const SizedBox(height: 10),
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(widget.hint, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.source, required this.onContinue});

  final SourceInfo source;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    Widget stat(String n, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: KdColors.bg2,
          border: Border.all(color: KdColors.line),
          borderRadius: BorderRadius.circular(KdRadius.card),
        ),
        child: Column(
          children: [
            Text(
              n,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
          ],
        ),
      ),
    );

    final expires = source.expiresAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.check, size: 18, color: KdColors.ok),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.addReady(source.name),
                style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            stat('${source.liveCount}', l10n.statLive),
            const SizedBox(width: 10),
            stat('${source.movieCount}', l10n.statMovies),
            const SizedBox(width: 10),
            stat('${source.seriesCount}', l10n.statSeries),
          ],
        ),
        if (expires != null) ...[
          const SizedBox(height: 10),
          Text(
            l10n.addAccountExpires(_date(expires)),
            style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
          ),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: KdButton(label: l10n.actionStart, kind: KdButtonKind.cta, large: true, autofocus: true, onPressed: onContinue),
        ),
      ],
    );
  }
}

String _date(int unix) => DateFormat.yMd(languageCode).format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

/// First-run page: KaradelikDev setup head + the form.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: KdColors.accentAlpha(0.5), blurRadius: 10)],
                    ),
                    child: Image.asset('assets/brand/logo.png', width: 44, height: 44),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Karadelik IPTV Player', style: TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(l10n.onboardHint, style: const TextStyle(color: KdColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KdColors.bg,
                  border: Border.all(color: KdColors.line),
                  borderRadius: BorderRadius.circular(KdRadius.card),
                ),
                child: AddSourceForm(onDone: (s) => context.app.sourceChanged(s)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: KdColors.accentAlpha(0.08),
                  border: Border.all(color: KdColors.accentAlpha(0.3)),
                  borderRadius: BorderRadius.circular(KdRadius.card),
                ),
                child: Text(
                  l10n.onboardDisclaimer,
                  style: const TextStyle(fontSize: KdType.small, color: KdColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
