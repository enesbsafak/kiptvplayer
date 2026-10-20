# Karadelik IPTV Player — UI spec and decision ledger

Status: v1 direction, 2026-10-20. Every decision below traces to a source.

## Reference lock

- **Primary:** KaradelikDev (`lokaldev/ui/css/app.css`). The product's own design system, chosen by the owner.
- **Preserve:** near-black layered surfaces (`#0b0b10 / #12121a / #1a1a24`), 1 px `#262633` lines instead of shadows,
  orange `#ff8a1f` used sparingly (active state, primary CTA, progress, focus), dense 13 px system type,
  44 px custom titlebar with glowing logo, Lucide stroke icons, radius 8 / 6 / 999.
- **Borrow only:** screen *patterns* from streaming products (below). Never their colours, type or imagery style.
- **Role rules:** accent = primary action, active/selected, live progress, focus ring. Never a surface fill.
  The `#ff8a1f → #ff5f1f` gradient is reserved for the single primary CTA on a screen (KaradelikDev "Start All").
  Green `#3ddc84` = healthy/live status only. Red `#ff5d5d` = errors only.
- **Reject:** cinematic full-bleed hero banners on every page, red "LIVE" Netflix/Prime styling, large marketing type,
  heavy drop shadows, glassmorphism everywhere, purple/indigo accents.
- **Media strategy:** channel logos (square, contained on `#12121a` tile), VOD posters 2:3, backdrops 16:9
  dimmed to 35 % behind text. Missing art = initials tile on `#1a1a24`, never a fake illustration.

## Decision ledger

| Decision | Source | Rule kept | Why |
|---|---|---|---|
| Titlebar 44 px, logo glow, window buttons, close hover `#c42b1c` | KaradelikDev `index.html:11-35`, app.css:39-65 | exact | Owner's brand |
| Left sidebar 216 px (collapsible to 56 px rail) with sections + source switcher | Tidal, Runway (Refero screens 5f5daca3, dc9d5dc5) | dark sidebar, wide main area | IPTV has 6+ top sections; a sidebar scales, KaradelikDev's menu-button doesn't |
| Live TV = categories · channel list · preview+now/next (3 panes) | TiviMate (competitor research), Prime Video live TV | — | Fastest zapping on desktop; preview avoids fullscreen for browsing |
| Channel row 44 px: number (tabular), 28 px logo tile, name, now-programme + 2 px accent progress | Prime Video EPG "x min left" + progress (Refero 52accfc5) | accent as progress only | Shows what's on without opening EPG |
| EPG grid: sticky channel column 200 px, "now" cell with remaining time + progress, tiles 4 px gap, radius 6, `#12121a` fill, `#262633` border, time ruler, accent now-line | Prime Video live TV grid (Refero 52accfc5, e63ddc26) | tiles flat, no shadow | Proven readable grid; KaradelikDev lines instead of Prime's filled cards |
| Player controls: bottom rail — left info, centre transport, right utilities; top-left badges; auto-hide 3 s | HBO Max player (Refero 4a1618ad, f43c24b9) | — | Standard desktop video layout users already know |
| Audio/subtitle picker: one panel, two columns with check marks | HBO Max (Refero 623f1687) | — | One click shows both track types |
| Episodes during playback: right side sheet over video | Netflix player (Refero ae69b47e) | — | Next episode without leaving the player |
| Zap list during playback: left side sheet with the current category | TiviMate behaviour | — | Keyboard ↑/↓ plus visual list |
| Detail page: dimmed backdrop, left text block, single gradient "Oynat" CTA, season pills, episode rows (16:9 thumb 160 px) | Prime Video / HBO Max detail (Refero c599da88, 118cbc47) + KaradelikDev CTA rule | one gradient CTA | Familiar VOD structure in our density |
| Onboarding = KaradelikDev setup page: 44 px logo head, three source-type cards, `.row` form (label 150 px), "Bağlantıyı test et" then summary | KaradelikDev `setup.html` + connector flows (Refero flows 12341, 6252) | `.row` layout, footer actions right | Connect → verify → confirm is the pattern for credential connectors |
| Settings = KaradelikDev prefs: tab bar on `#12121a`, rows, native-feeling checkboxes | KaradelikDev `prefs.html` | exact | Brand consistency |
| Search: Ctrl+K palette overlay + Search page grouped Live / Movies / Series | IPTVnator Ctrl+K (desktop research) | — | Keyboard-first desktop request |
| Motion: fades 120–200 ms, no bounces; OSD fade 160 ms | KaradelikDev (one transition, `.2s`), karadelik.net speeds 120/200 ms | restraint | Native, quiet feel |

## Screens (v1)

1. Onboarding / add source (Xtream, M3U URL/file, Stalker later)
2. Home: "Devam et" row, favourite channels, recently watched, sources health
3. Live TV (3 panes) → fullscreen player
4. Guide (EPG grid)
5. Movies, Series: category rail + poster grid; detail; seasons/episodes
6. Search page + Ctrl+K palette
7. Player: OSD, track panel, zap sheet, episodes sheet, mini player
8. Settings: Genel, Oynatma, Kaynaklar, Görünüm, Hakkında

## Keyboard map

| Key | Action |
|---|---|
| Ctrl+K | Search palette |
| Ctrl+1…5 | Home, Live, Guide, Movies, Series |
| ↑ / ↓ , PgUp / PgDn | Zap / move in lists |
| 0–9 | Channel number entry |
| Enter | Play / open |
| F, double-click | Fullscreen |
| Space | Pause |
| A, S | Audio, subtitle panel |
| Esc | Close overlay / leave fullscreen |
