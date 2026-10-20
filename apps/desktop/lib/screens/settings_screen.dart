import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import 'add_source.dart';

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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: KdColors.bg2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (t, label) in const [(_Tab.sources, 'Kaynaklar'), (_Tab.preferences, 'Tercihler'), (_Tab.shortcuts, 'Kısayollar'), (_Tab.about, 'Hakkında')])
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
              const Text('Kaynaklar', style: TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!_adding)
                KdButton(label: 'Kaynak ekle', icon: LucideIcons.plus, kind: KdButtonKind.primary, onPressed: () => setState(() => _adding = true)),
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
            const Padding(padding: EdgeInsets.all(20), child: Text('Henüz kaynak yok.', style: TextStyle(color: KdColors.muted))),
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _sync() {
    setState(() => _stage = 'Bağlanılıyor…');
    _sub = context.library.syncSource(widget.source.id).listen((e) {
      if (!mounted) return;
      switch (e) {
        case SyncEvent_Downloading(:final what):
          setState(() => _stage = '$what indiriliyor…');
        case SyncEvent_Saving():
          setState(() => _stage = 'Kaydediliyor…');
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
        title: Text('${widget.source.name} silinsin mi?', style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        content: const Text(
          'Kaynağın kataloğu, favorileri ve izleme geçmişi bu bilgisayardan silinir. Şifre anahtar deposundan kaldırılır.',
          style: TextStyle(color: KdColors.muted),
        ),
        actions: [
          KdButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context, false)),
          KdButton(label: 'Sil', kind: KdButtonKind.danger, onPressed: () => Navigator.pop(context, true)),
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
                    KdTag(s.isXtream ? 'Xtream' : 'M3U'),
                    if (widget.active) ...[const SizedBox(width: 6), const KdTag('etkin', ok: true)],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (s.username != null) s.username!,
                    _host(s.url),
                    '${s.liveCount} kanal · ${s.movieCount} film · ${s.seriesCount} dizi',
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
              ],
            ),
          ),
          if (!widget.active) KdButton(label: 'Etkinleştir', onPressed: () => context.app.selectSource(s.id)),
          const SizedBox(width: 6),
          KdButton(label: 'Eşitle', icon: LucideIcons.refreshCw, onPressed: _stage == null ? _sync : null),
          const SizedBox(width: 6),
          KdButton(label: 'Sil', icon: LucideIcons.trash2, kind: KdButtonKind.danger, onPressed: _stage == null ? _remove : null),
        ],
      ),
    );
  }
}

String _host(String url) {
  final u = Uri.tryParse(url);
  return (u != null && u.host.isNotEmpty) ? u.host : url;
}

/// Display names for region codes providers use.
const _regionNames = {
  'TR': 'Türkiye',
  'DE': 'Almanya',
  'AT': 'Avusturya',
  'CH': 'İsviçre',
  'UK': 'Birleşik Krallık',
  'US': 'ABD',
  'CA': 'Kanada',
  'FR': 'Fransa',
  'ES': 'İspanya',
  'PT': 'Portekiz',
  'IT': 'İtalya',
  'NL': 'Hollanda',
  'BE': 'Belçika',
  'PL': 'Polonya',
  'RO': 'Romanya',
  'BG': 'Bulgaristan',
  'GR': 'Yunanistan',
  'AL': 'Arnavutluk',
  'RS': 'Sırbistan',
  'HR': 'Hırvatistan',
  'BA': 'Bosna-Hersek',
  'MK': 'Kuzey Makedonya',
  'HU': 'Macaristan',
  'SE': 'İsveç',
  'NO': 'Norveç',
  'DK': 'Danimarka',
  'FI': 'Finlandiya',
  'RU': 'Rusya',
  'UA': 'Ukrayna',
  'AZ': 'Azerbaycan',
  'AR': 'Arapça',
  'IR': 'İran',
  'IN': 'Hindistan',
  'PK': 'Pakistan',
  'KU': 'Kürtçe',
  'EXYU': 'Eski Yugoslavya',
  'LAT': 'Latin Amerika',
};

String regionName(String code) => _regionNames[code] ?? code;

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
        const Text('Öne çıkan bölge', style: TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Bu bölgenin kategorileri ve kanalları her listede en başta gösterilir. Diğerleri sağlayıcının sırasıyla devam eder; '
          'yetişkin içerik her zaman en sondadır. Bölge, kategori adlarından okunur (ör. “TR: Ulusal”, “|DE| Sport”).',
          style: TextStyle(color: KdColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            KdPill(label: 'Kapalı', selected: current == null, onTap: () => _pick(null)),
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
          const Text(
            'Etkin kaynakta bölge etiketi bulunamadı; sıralama sağlayıcının kendi sırası olarak kalır.',
            style: TextStyle(fontSize: KdType.small, color: KdColors.muted),
          ),
        ],
      ],
    );
  }
}

class _ShortcutsTab extends StatelessWidget {
  const _ShortcutsTab();

  static const _rows = [
    ('Ctrl K', 'Ara'),
    ('Ctrl 1 … 6', 'Ana sayfa, Canlı TV, Yayın akışı, Filmler, Diziler, Favoriler'),
    ('Ctrl ,', 'Ayarlar'),
    ('↑ / ↓', 'Kanal değiştir'),
    ('PgUp / PgDn', 'Listede 10 kanal atla'),
    ('Enter', 'Tam ekran oynat'),
    ('Space', 'Oynat / duraklat'),
    ('← / →', '10 saniye geri / ileri (film ve dizi)'),
    ('F, çift tık', 'Pencereyi tam ekran yap'),
    ('A, S', 'Ses ve altyazı paneli'),
    ('L', 'Oynatıcıda kanal listesi'),
    ('M', 'Sesi kapat / aç'),
    ('Esc', 'Paneli kapat, oynatıcıdan çık'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final (k, d) in _rows)
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Karadelik IPTV Player', style: TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
                Text('Sürüm 0.1.0 · ön sürüm', style: TextStyle(color: KdColors.muted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Karadelik IPTV Player bir oynatıcıdır. Kanal, film veya yayın sağlamaz, satmaz ve barındırmaz. '
          'Eklediğiniz kaynakların yasal olduğundan ve erişim hakkınız bulunduğundan siz sorumlusunuz.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 14),
        const Text(
          'Gizlilik: kaynak şifreleri yalnızca bu bilgisayarın anahtar deposunda tutulur. Uygulama izleme veya reklam SDK’sı içermez.',
          style: TextStyle(height: 1.5, color: KdColors.muted),
        ),
      ],
    );
  }
}
