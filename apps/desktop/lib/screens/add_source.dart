import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';

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
        _Type.xtream => 'Sunucu adresini girin',
        _Type.m3uUrl => 'Liste adresini girin',
        _Type.m3uFile => 'Bir M3U dosyası seçin',
      };
    }
    if (_type == _Type.xtream && _user.text.trim().isEmpty) return 'Kullanıcı adını girin';
    if (_type == _Type.xtream && _pass.text.isEmpty) return 'Şifreyi girin';
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
      _stage = 'Bağlanılıyor…';
    });
    _sub = context.library.addSource(input).listen((e) {
      if (!mounted) return;
      setState(() {
        switch (e) {
          case SyncEvent_Connecting():
            _stage = 'Sağlayıcıya bağlanılıyor…';
          case SyncEvent_Downloading(:final what):
            _stage = '$what indiriliyor…';
          case SyncEvent_Saving():
            _stage = 'Kütüphane hazırlanıyor…';
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
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Oynatma listesi', extensions: ['m3u', 'm3u8', 'txt']),
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
              hint: 'Sunucu, kullanıcı adı ve şifre',
              selected: _type == _Type.xtream,
              onTap: () => setState(() => _type = _Type.xtream),
            ),
            const SizedBox(width: 10),
            _TypeCard(
              icon: LucideIcons.link,
              title: 'M3U bağlantısı',
              hint: 'Oynatma listesi adresi',
              selected: _type == _Type.m3uUrl,
              onTap: () => setState(() => _type = _Type.m3uUrl),
            ),
            const SizedBox(width: 10),
            _TypeCard(
              icon: LucideIcons.fileText,
              title: 'M3U dosyası',
              hint: 'Bilgisayardaki liste',
              selected: _type == _Type.m3uFile,
              onTap: () => setState(() => _type = _Type.m3uFile),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Row(label: 'Ad', child: KdInput(controller: _name, hint: 'İsteğe bağlı, ör. Ev')),
        if (_type == _Type.xtream) ...[
          _Row(label: 'Sunucu adresi', child: KdInput(controller: _url, hint: 'http://sunucu:8080', mono: true)),
          _Row(label: 'Kullanıcı adı', child: KdInput(controller: _user)),
          _Row(label: 'Şifre', child: KdInput(controller: _pass, obscure: true, onSubmitted: (_) => _submit())),
        ] else if (_type == _Type.m3uUrl)
          _Row(label: 'Liste adresi', child: KdInput(controller: _url, hint: 'https://…/playlist.m3u', mono: true, onSubmitted: (_) => _submit()))
        else
          _Row(
            label: 'Dosya',
            child: Row(
              children: [
                Expanded(child: KdInput(controller: _url, hint: 'Dosya seçilmedi', mono: true)),
                const SizedBox(width: 8),
                KdButton(label: 'Seç…', icon: LucideIcons.fileText, onPressed: _busy ? null : _pickFile),
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
                _advanced ? 'Gelişmiş ayarları gizle' : 'Gelişmiş ayarlar',
                style: const TextStyle(fontSize: KdType.small, color: KdColors.accent2),
              ),
            ),
          ),
        ),
        if (_advanced) ...[
          _Row(label: 'User-Agent', child: KdInput(controller: _agent, hint: 'Sağlayıcı isterse', mono: true)),
          if (_type != _Type.xtream)
            _Row(
              label: 'Yayın akışı (XMLTV)',
              child: KdInput(controller: _epg, hint: 'Liste bildirmiyorsa: https://…/epg.xml.gz', mono: true),
            ),
          _Row(
            label: '',
            child: KdCheck(
              value: _insecure,
              onChanged: (v) => setState(() => _insecure = v),
              label: 'Geçersiz sertifikalara izin ver',
              hint: 'Yalnızca bu kaynak için. Sağlayıcının sertifikası kendinden imzalıysa gerekir.',
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
                      : const Text(
                          'Şifreniz bu bilgisayarın anahtar deposunda saklanır.',
                          style: TextStyle(fontSize: KdType.small, color: KdColors.muted),
                        ),
            ),
            if (widget.onCancel != null) ...[
              KdButton(label: 'Vazgeç', onPressed: _busy ? null : widget.onCancel),
              const SizedBox(width: 8),
            ],
            KdButton(
              label: 'Bağlan ve eşitle',
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
                '${source.name} hazır',
                style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            stat('${source.liveCount}', 'canlı kanal'),
            const SizedBox(width: 10),
            stat('${source.movieCount}', 'film'),
            const SizedBox(width: 10),
            stat('${source.seriesCount}', 'dizi'),
          ],
        ),
        if (expires != null) ...[
          const SizedBox(height: 10),
          Text(
            'Hesap bitiş tarihi: ${_date(expires)}',
            style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
          ),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: KdButton(label: 'Başla', kind: KdButtonKind.cta, large: true, autofocus: true, onPressed: onContinue),
        ),
      ],
    );
  }
}

String _date(int unix) {
  final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Karadelik IPTV Player', style: TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('Başlamak için bir kaynak ekleyin.', style: TextStyle(color: KdColors.muted)),
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
                child: const Text(
                  'Karadelik IPTV Player bir oynatıcıdır; kanal, film veya yayın sağlamaz ve satmaz. '
                  'Yalnızca erişim hakkınız olan kaynakları ekleyin.',
                  style: TextStyle(fontSize: KdType.small, color: KdColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
