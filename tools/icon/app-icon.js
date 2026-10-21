// Karadelik Player icon: the event horizon is a play button, an accretion
// disk of light passes behind and in front of it.
//
//   cd tools/icon && npm ci && node app-icon.js
//
// Writes design/brand/app-icon.svg, app-icon-1024.png (on its space
// background) and app-icon-foreground-1024.png (transparent: Android's
// adaptive icon layer and the in-app logo). tools/make-icons.py turns them
// into every platform's icons.
const fs = require('fs');
const { Resvg } = require('@resvg/resvg-js');

const C = 512;
// Rounded play triangle: centroid at (cx, cy), circumradius r, corner radius k.
function playPath(cx, cy, r, k) {
  const v = [0, 120, 240].map((a) => [cx + r * Math.cos((a * Math.PI) / 180), cy + r * Math.sin((a * Math.PI) / 180)]);
  const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  const side = Math.hypot(v[1][0] - v[0][0], v[1][1] - v[0][1]);
  const t = k / side;
  let d = '';
  for (let i = 0; i < 3; i++) {
    const p = v[i], prev = v[(i + 2) % 3], next = v[(i + 1) % 3];
    const a = lerp(p, prev, t), b = lerp(p, next, t);
    d += (i === 0 ? `M${a[0].toFixed(1)},${a[1].toFixed(1)}` : `L${a[0].toFixed(1)},${a[1].toFixed(1)}`) + ` Q${p[0].toFixed(1)},${p[1].toFixed(1)} ${b[0].toFixed(1)},${b[1].toFixed(1)}`;
  }
  return d + 'Z';
}

const cx = C + 26, cy = C;          // a triangle's mass sits left: nudge right
const hole = playPath(cx, cy, 300, 120);
const ring = playPath(cx, cy, 318, 128);
const tilt = -16;
const dx = cx - 8, dy = cy + 22;
const disk = (rx, ry) => `<ellipse cx="${dx}" cy="${dy}" rx="${rx}" ry="${ry}" transform="rotate(${tilt} ${dx} ${dy})"/>`;

const build = (background) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <radialGradient id="space" cx="0.5" cy="0.44" r="0.75">
    <stop offset="0" stop-color="#1b1324"/>
    <stop offset="0.55" stop-color="#0b0b10"/>
    <stop offset="1" stop-color="#050507"/>
  </radialGradient>
  <!-- Doppler: the approaching (left) side of the disk is brighter. -->
  <linearGradient id="band" x1="0" y1="0" x2="1" y2="0" gradientTransform="rotate(${tilt} 0.5 0.5)">
    <stop offset="0" stop-color="#ff8a1f" stop-opacity="0"/>
    <stop offset="0.14" stop-color="#ffb347" stop-opacity="0.9"/>
    <stop offset="0.36" stop-color="#fff1d6"/>
    <stop offset="0.62" stop-color="#ff8a1f"/>
    <stop offset="0.86" stop-color="#d9431a" stop-opacity="0.85"/>
    <stop offset="1" stop-color="#9c2410" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="rim" x1="0.15" y1="0.1" x2="0.85" y2="0.95">
    <stop offset="0" stop-color="#fff4dd"/>
    <stop offset="0.5" stop-color="#ffc77a"/>
    <stop offset="1" stop-color="#ff7a1f"/>
  </linearGradient>
  <radialGradient id="horizon" cx="0.42" cy="0.4" r="0.7">
    <stop offset="0" stop-color="#0d0d14"/>
    <stop offset="1" stop-color="#020203"/>
  </radialGradient>
  <filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="22"/></filter>
  <filter id="wide" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="60"/></filter>
  <filter id="core" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="3"/></filter>
  <!-- The part of the disk in front of the hole: below its tilted midline. -->
  <clipPath id="front"><rect x="-400" y="${dy}" width="1824" height="900" transform="rotate(${tilt} ${dx} ${dy})"/></clipPath>
</defs>

${background ? '<rect width="1024" height="1024" fill="url(#space)"/>' : ''}
<!-- Halo of light around everything. -->
<g opacity="0.55" filter="url(#wide)" fill="none" stroke="#ff7a1f" stroke-width="120">${disk(360, 108)}</g>
<path d="${ring}" fill="none" stroke="#ff8a1f" stroke-width="70" opacity="0.55" filter="url(#wide)"/>

<!-- Disk, far side (behind the hole). -->
<g fill="none" stroke="url(#band)">
  <g stroke-width="58" opacity="0.6" filter="url(#soft)">${disk(360, 108)}</g>
  <g stroke-width="16" filter="url(#core)">${disk(360, 108)}</g>
</g>

<!-- Photon ring and the event horizon. -->
<path d="${ring}" fill="none" stroke="#ffb347" stroke-width="30" opacity="0.8" filter="url(#soft)"/>
<path d="${ring}" fill="url(#rim)"/>
<path d="${hole}" fill="url(#horizon)"/>

<!-- Disk, near side (in front of the hole). -->
<g clip-path="url(#front)" fill="none" stroke="url(#band)">
  <g stroke-width="70" opacity="0.75" filter="url(#soft)">${disk(360, 108)}</g>
  <g stroke-width="20" filter="url(#core)">${disk(360, 108)}</g>
  <g stroke-width="6" stroke="#fff6e6" opacity="0.9">${disk(360, 108)}</g>
</g>
</svg>`;

const path = require('path');
const brand = path.join(__dirname, '..', '..', 'design', 'brand');
const render = (svg, file) => fs.writeFileSync(path.join(brand, file), new Resvg(svg, { fitTo: { mode: 'width', value: 1024 } }).render().asPng());
fs.writeFileSync(path.join(brand, 'app-icon.svg'), build(true));
render(build(true), 'app-icon-1024.png');
render(build(false), 'app-icon-foreground-1024.png');
console.log('written to', brand);
