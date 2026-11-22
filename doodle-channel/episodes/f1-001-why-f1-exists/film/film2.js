// F1 Ep. 001 v2 — camera moves, parallax, roller-wipe transitions, period cars. Driven by timeline2.json.
import { C, clamp, lerp, seg, eo, eio, pop, rng, poly, circ, line, curve, rrect, tint, paper, text, stamp, fig,
  hills, sun, tree, building, crowd, europe, proj, CITY, pin, route } from './draw.js';
import { W, H, layer, camAt, cloud, clouds, shadow, vignette, poplar, pole, wires, fence, bales, drums, tufts, speedLines,
  wellington, car2, dust } from './draw2.js';

const M = 124;
const cv = document.getElementById('c'), g = cv.getContext('2d');
const T = await (await fetch('timeline2.json')).json();
const CUES = await (await fetch('cues2.json')).json();
await Promise.all(['500', '600', '700', '800'].map(w => document.fonts.load(`${w} 40px Jost`)));

// ---------- helpers ----------
const apex = (x, y, s, o = {}) => fig(g, x, y, s, { apex: true, ...o });
const cap = (s, lt, at, x = M, y = 190, size = 64, o = {}) => text(g, s, x, y, { size, weight: 800, t: (lt - at) / .45, mis: o.mis ?? C.orange, ...o });
const small = (s, lt, at, x = M, y = 250, o = {}) => text(g, s, x, y, { size: 34, weight: 600, t: (lt - at) / .45, ...o });
const card = (x, y, w, h, col = C.paper) => rrect(g, x, y, w, h, 14, col, C.ink, 6);
const fill = (col) => { g.fillStyle = col; g.fillRect(-W, -H, W * 3, H * 3); };
const ground = (y, col, edge = true) => { g.save(); g.translate(4, 3); g.fillStyle = col; g.fillRect(-W, y, W * 3, H * 2); g.restore(); if (edge) line(g, [[-W, y], [W * 2, y]], C.ink, 6); };
const L = (cam, k, fn) => layer(g, cam, k, fn);

function horse(x, y, s, t, col = C.brown) {
  g.save(); g.translate(x, y); g.scale(s, s); const ph = t * 7;
  for (let i = 0; i < 4; i++) { const lx = [-70, -40, 50, 80][i], sw = Math.sin(ph + i * 1.7) * 18; line(g, [[lx, -100], [lx + sw, -4]], C.ink, 9); }
  poly(g, [[-100, -100], [-90, -170], [80, -175], [110, -110], [90, -90], [-80, -88]], col, C.ink, 6);
  poly(g, [[80, -170], [120, -240], [170, -235], [180, -205], [130, -190], [110, -140]], col, C.ink, 6);
  circ(g, 150, -222, 5, C.ink, null, 0, false); line(g, [[-100, -150], [-140, -100]], C.ink, 8);
  g.restore();
}
function parisRow(x0, y, n, s, seed) {
  const r = rng(seed);
  for (let i = 0; i < n; i++) {
    const x = x0 + i * 260 * s, h = (300 + r() * 80) * s, w = 250 * s;
    poly(g, [[x, y], [x, y - h], [x + w, y - h], [x + w, y]], i % 2 ? '#EADBC0' : '#E2CFAE', C.ink, 5);
    poly(g, [[x - 8, y - h], [x + 20, y - h - 70 * s], [x + w - 20, y - h - 70 * s], [x + w + 8, y - h]], '#6E7B8C', C.ink, 5);
    for (let k = 0; k < 3; k++) for (let j = 0; j < 3; j++) { rrect(g, x + 30 * s + k * 75 * s, y - h + 40 * s + j * 85 * s, 36 * s, 56 * s, 3, '#9FB3C7', C.ink, 3, false); }
    line(g, [[x + 10, y - h + 120 * s], [x + w - 10, y - h + 120 * s]], C.ink, 4);
    rrect(g, x + w / 2 - 28 * s, y - 90 * s, 56 * s, 90 * s, 3, C.brown, C.ink, 4, false);
  }
}
function pine(x, y, s, col = '#2F5A3C') { line(g, [[x, y], [x, y - 40 * s]], C.brown, 8 * s); for (let i = 0; i < 3; i++) poly(g, [[x - (70 - i * 16) * s, y - (30 + i * 70) * s], [x, y - (130 + i * 70) * s], [x + (70 - i * 16) * s, y - (30 + i * 70) * s]], col, C.ink, 4 * s); }
function grandstand(x, y, w, h, t, roof = C.blue, seed = 3) {
  poly(g, [[x, y], [x, y - h], [x + w, y - h], [x + w, y]], C.light, C.ink, 6);
  poly(g, [[x - 40, y - h], [x + w + 40, y - h], [x + w - 40, y - h - 70], [x + 40, y - h - 70]], roof, C.ink, 6);
  crowd(g, x + 20, x + w - 20, y - 20, Math.floor(w / 62), .26, seed, t, { cheer: true });
  for (let i = 0; i < Math.floor(w / 220); i++) { const fx = x + 80 + i * 220; line(g, [[fx, y - h - 70], [fx, y - h - 170]], C.ink, 5); const wv = Math.sin(t * 6 + i) * 6; poly(g, [[fx, y - h - 170], [fx + 80, y - h - 160 + wv], [fx + 80, y - h - 120 + wv], [fx, y - h - 130]], [C.red, C.mustard, C.white, C.blue][i % 4], C.ink, 4); }
}
function checklist(lt, n, all = false) {
  fill(C.paper); paper(g, W, H);
  const items = ['PROVE THE MACHINE WORKS', 'A SAFE PLACE TO RACE', 'MAKE IT FAIR', 'CROWN ONE CHAMPION'];
  const x = 220, y = 200, k = eo(lt / .5); g.save(); g.translate(0, (1 - k) * 60); g.globalAlpha = k;
  card(x, y, 1020, 590, C.white); text(g, 'WHY F1 EXISTS', x + 50, y + 95, { size: 58, weight: 800, mis: C.orange });
  items.forEach((s, i) => {
    const yy = y + 200 + i * 96, shown = i < n || all, tk = all ? lt - .8 - i * .55 : (i === n - 1 ? lt - .7 : 9);
    rrect(g, x + 50, yy - 44, 56, 56, 8, C.paper, C.ink, 5, false);
    if (shown) { text(g, s, x + 135, yy, { size: 46, weight: 700, color: (i === n - 1 || all) ? C.ink : C.grey, t: 1 });
      if (tk > 0) { const kk = eo(tk / .3); line(g, [[x + 60, yy - 20], [x + 76, yy - 2], [x + 76 + 44 * kk, yy - 2 - 56 * kk]], C.orange, 12); } }
    else text(g, '?  ?  ?', x + 135, yy, { size: 42, weight: 600, color: C.light });
  });
  g.restore();
  apex(1540, 830, .8, { pose: 'cheer', expr: 'happy', t: lt });
}
function newspaper(cx, cy, s, rot, head = 'LE PETIT JOURNAL', model = 'peugeot1894') {
  g.save(); g.translate(cx, cy); g.rotate(rot); g.scale(s, s);
  rrect(g, -380, -300, 760, 600, 6, C.white, C.ink, 6); rrect(g, -340, -260, 680, 70, 4, C.ink, null, 0, false);
  text(g, head, 0, -208, { size: 46, weight: 800, color: C.white, align: 'center' });
  for (let i = 0; i < 9; i++) line(g, [[-340, -150 + i * 28], [-40, -150 + i * 28]], C.grey, 6);
  rrect(g, 0, -160, 340, 230, 4, C.light, C.ink, 4, false); car2(g, 170, 40, .4, { model, color: C.red });
  for (let i = 0; i < 5; i++) line(g, [[-340, 120 + i * 28], [340, 120 + i * 28]], C.grey, 6);
  g.restore();
}
function mapScene(box, lt, o = {}) { fill('#A9C3D6'); g.fillStyle = tint(g, C.blue, .12, 10); g.fillRect(0, 0, W, H); europe(g, box, { land: '#EDE3CF' }); }
const P = (n, box) => proj(...CITY[n], box);

// ---------- shots ----------
const SH = {
  P00_1: { cam: [[960, 560, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .5, () => { fill('#E4E1DA'); const cols = [C.red, C.orange, '#2E8B8B', C.silver, C.blue, C.green, '#E6E6E6']; for (let i = 0; i < 7; i++) { poly(g, [[-200 + i * 380, 640], [-200 + i * 380, 300], [140 + i * 380, 300], [140 + i * 380, 640]], C.light, C.ink, 6); rrect(g, -200 + i * 380, 300, 340, 50, 0, cols[i], C.ink, 5, false); } });
    L(cam, 1, () => { ground(640, '#9A9690'); for (let i = 0; i < 4; i++) car2(g, 420 + i * 420, 840 + (i % 2) * 110, .5, { model: 'modern', color: [C.red, C.orange, '#2E8B8B', C.blue][i], t: lt + i, driver: { hat: 'helmet' } });
      apex(1760, 1000, .5, { suit: 'pit', hat: 'headset', pose: lt > d * .55 ? 'shock' : 'think', expr: lt > d * .55 ? 'shock' : 'think', t: lt }); });
    card(M - 30, 90, 1120, 300, C.white);
    text(g, 'F1 STARTED IN 1950?', M, 190, { size: 64, weight: 800, t: lt / .4, mis: C.orange });
    if (lt > d * .45) { const k = eo((lt - d * .45) / .3); line(g, [[M - 10, 168], [lerp(M - 10, M + 700, k), 168]], C.red, 12); }
    if (lt > d * .55) { text(g, '1894', M, 330, { size: 120, weight: 800, t: (lt - d * .55) * 3, mis: C.red }); small('the 56 years nobody tells you about', lt, d * .65, M + 330, 320, { weight: 700 }); }
  } },
  P01_1: { cam: [[960, 540, 1.0], [980, 520, 1.12]], draw(lt, d, cam) {
    L(cam, 1, () => { fill('#6E9A5A'); g.fillStyle = tint(g, '#3E6B3A', .3, 12); g.fillRect(-W, -H, 3 * W, 3 * H);
      for (const [a, b] of [[[-400, 760], [2300, 820]], [[-200, 980], [1300, -200]], [[2200, 1000], [700, -200]]]) line(g, [a, b], '#CFC9BB', 120);
      wellington(g, 640, 520, .4, 0); wellington(g, 1120, 640, .4, 0); wellington(g, 1500, 420, .4, 0);
      for (let i = 0; i < 6; i++) fig(g, 300 + ((lt * 40 + i * 200) % 1500), 900, .16, { pose: 'walk', t: lt + i, suitColor: '#5E6A4F', lw: 12 });
    });
    card(M - 30, 100, 700, 180); cap('RAF SILVERSTONE', lt, .4, M, 180, 66); small('1943 · a training base for bomber crews', lt, 1.1, M, 240);
  } },
  P01_2: { cam: [[960, 540, 1.12], [960, 560, 1.0]], draw(lt, d, cam) {
    L(cam, 1, () => { fill('#6E9A5A'); g.fillStyle = tint(g, '#3E6B3A', .3, 12); g.fillRect(-W, -H, 3 * W, 3 * H);
      for (const [a, b] of [[[-400, 760], [2300, 820]], [[-200, 980], [1300, -200]], [[2200, 1000], [700, -200]]]) line(g, [a, b], '#CFC9BB', 120);
      route(g, [[-300, 700], [400, 900], [1700, 920], [2150, 760], [1500, 300], [900, -100], [300, 200], [-300, 700]], eo(lt / 2.5), C.orange, 14);
      const r = rng(5); for (let i = 0; i < 80; i++) { const k = i / 80, x = lerp(-200, 2100, k), y = lerp(780, 830, k) + 70; (i % 2 ? (xx, yy) => rrect(g, xx, yy - 18, 30, 18, 3, C.mustard, C.ink, 2) : (xx, yy) => rrect(g, xx, yy - 26, 18, 26, 3, C.red, C.ink, 2))(x, y); }
      const n = Math.floor(seg(lt, 0, d) * 600); for (let i = 0; i < n; i++) circ(g, r() * 2400 - 240, 950 + r() * 260, 7, [C.red, C.blue, C.mustard, C.paper][i % 4], null, 0, false);
    });
    card(M - 30, 100, 1000, 180); cap('13 MAY 1950', lt, .3, M, 190, 90); small('perimeter roads · oil drums · straw bales · ≈100,000 fans', lt, 1.2, M, 250);
  } },
  P01_3: { cam: [[760, 520, 1.15], [1000, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#CFE0E8'); clouds(g, lt, 3, 5, 120); });
    L(cam, .7, () => { crowd(g, -300, 2200, 520, 30, .3, 4, lt, { cheer: true }); });
    L(cam, 1, () => { crowd(g, -300, 2200, 610, 26, .36, 9, lt);
      poly(g, [[420, 900], [420, 610], [1260, 610], [1260, 900]], C.red, C.ink, 7);
      for (let i = 0; i < 8; i++) poly(g, [[420 + i * 105, 610], [472 + i * 105, 664], [525 + i * 105, 610]], i % 2 ? C.white : C.blue, C.ink, 4);
      fig(g, 720, 650, .55, { suit: 'suit', hat: 'crown', expr: 'smug', t: lt, mustache: true, pose: lt > 2 ? 'wave' : 'stand' });
      fig(g, 960, 650, .55, { suit: 'royal', hat: 'crown', expr: 'happy', t: lt + 1 });
      apex(1560, 900, .62, { suit: 'tweed', hat: 'flat', pose: lt > 1.6 ? 'shock' : 'stand', expr: lt > 1.6 ? 'shock' : 'happy', t: lt, look: -1 }); });
    cap('THE KING & QUEEN', lt, .6, M, 170, 70); small('the only motor race a reigning British monarch has attended', lt, 2.2, M, 230);
  } },
  P02_1: { cam: [[1150, 600, 1.2], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#D6E4EA'); clouds(g, lt, 7, 4, 140); hills(g, W * 2, 520, '#8FB07A', 30, .003, 4); });
    L(cam, .7, () => { grandstand(-200, 560, 2400, 140, lt, C.green, 21); });
    L(cam, 1, () => { ground(640, '#BDB6A8'); for (let i = 0; i < 40; i++) line(g, [[-200 + i * 120, 760], [-140 + i * 120, 760]], C.white, 6);
      for (let i = 0; i < 4; i++) car2(g, 360 + i * 420 - (i % 2) * 60, 760 + (i % 2) * 120, .62, { model: 'alfa158', color: C.red, t: lt + i, num: 1, driver: { hat: 'leather', expr: 'determined' } });
      fig(g, 1780, 930, .4, { suit: 'plain', suitColor: C.blue, t: lt, prop: 'wrench', pose: 'hold' }); });
    card(M - 30, 100, 760, 180); cap('4 × ALFA ROMEO 158', lt, .4, M, 180, 64); small('Ferrari: absent, after a row over starting money', lt, 1.6, M, 240);
  } },
  P02_2: { cam: [[960, 540, 1.0], [960, 540, 1.06]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#D6E4EA'); clouds(g, lt, 8, 4, 140, C.paper, 30); hills(g, W * 2, 520, '#8FB07A', 30, .003, 4); });
    L(cam, .6, () => { grandstand(-600 + ((lt * 300) % 1000) - 1000, 560, 4400, 120, lt, C.green, 22); });
    L(cam, 1, () => { ground(640, '#BDB6A8'); g.fillStyle = C.grass; g.fillRect(-W, 900, 3 * W, H);
      for (let i = 0; i < 3; i++) { const x = ((lt * 900 + i * 520) % 3200) - 800; car2(g, x, 860 - i * 60, .72 - i * .06, { model: 'alfa158', color: C.red, spin: lt * 18, speed: 1, t: lt + i, num: 1, driver: { hat: 'leather', expr: 'determined' } }); }
      speedLines(g, lt, 650, 880, 12, C.white);
      const bx = -((lt * 1400) % 240); bales(g, bx - 240, W + 240, 960, 1); drums(g, bx - 100, W + 240, 1000, .9); });
    if (lt > d * .55) { const k = lt - d * .55; rrect(g, 1180, 120, 640, 200, 14, C.paper, C.ink, 6); cap('GIUSEPPE FARINA', k, .1, 1220, 200, 56); small('takes the chequered flag', k, .5, 1220, 260); }
    else { card(M - 30, 100, 560, 160); cap('70 LAPS', lt, .4, M, 200, 90); }
  } },
  P02_3: { cam: [[960, 540, 1.0], [960, 540, 1.0]], draw(lt, d, cam) {
    const tear = eio(seg(lt, d * .45, d * .7));
    newspaper(1260, 520, 1, -.06, 'LE PETIT JOURNAL', 'peugeot1894');
    fill(C.paper); paper(g, W, H); newspaper(1260, 520, 1, -.06, 'LE PETIT JOURNAL', 'peugeot1894');
    g.save(); g.beginPath(); g.moveTo(0, 0); g.lineTo(W * (1 - tear) + 200, 0);
    for (let y = 0; y <= H; y += 60) g.lineTo(W * (1 - tear) + 100 + Math.sin(y * .05) * 40, y);
    g.lineTo(0, H); g.closePath(); g.clip();
    fill('#D6E4EA'); g.save(); g.translate(0, 0); hills(g, W, 520, '#8FB07A', 30, .003, 4); ground(640, '#BDB6A8'); car2(g, 900, 860, .9, { model: 'alfa158', color: C.red, num: 1, driver: { hat: 'leather', expr: 'grin' } });
    g.fillStyle = 'rgba(243,237,226,.45)'; g.fillRect(0, 0, W, H); stamp(g, 'RACE Nº1', 1380, 330, lt - .4, { size: 120 }); g.restore(); g.restore();
    const yr = Math.round(lerp(1950, 1894, eio(seg(lt, d * .5, d * .95))));
    if (tear > .3) { text(g, String(yr), M, 420, { size: 220, weight: 800, mis: C.orange }); small('56 years of problems', lt, d * .7, M, 490); }
  } },
  TITLE: { cam: [[960, 540, 1], [960, 540, 1]], draw(lt, d) {
    fill(C.paper); paper(g, W, H);
    for (let x = 0; x < W; x += 60) { g.fillStyle = (x / 60) % 2 ? C.ink : C.white; g.fillRect(x, 960, 60, 30); g.fillStyle = (x / 60) % 2 ? C.white : C.ink; g.fillRect(x, 990, 60, 30); }
    text(g, 'WHY DOES F1', W / 2, 400, { size: 150, weight: 800, align: 'center', t: lt / .5, mis: C.orange });
    text(g, 'EVEN EXIST?', W / 2, 560, { size: 150, weight: 800, align: 'center', t: (lt - .35) / .5, mis: C.red });
    apex(lerp(-200, W + 200, seg(lt, 0, d)), 930, .55, { pose: 'run', prop: 'flag', expr: 'grin', t: lt });
  } },
  P03_1: { cam: [[700, 560, 1.1], [1200, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#DCE6E8'); clouds(g, lt, 11, 4, 120); });
    L(cam, .7, () => parisRow(-300, 700, 12, 1, 3));
    L(cam, 1, () => { ground(700, '#CBBFA8'); for (let i = 0; i < 30; i++) line(g, [[-300 + i * 110, 820], [-260 + i * 110, 820]], '#B3A68C', 5);
      const hx = lerp(2300, -400, seg(lt, 0, d)); horse(hx, 900, .7, lt); rrect(g, hx - 340, 760, 220, 110, 10, C.ink, C.ink, 4); circ(g, hx - 300, 870, 50, null, C.ink, 6, false); circ(g, hx - 160, 870, 50, null, C.ink, 6, false); line(g, [[hx - 120, 820], [hx - 70, 820]], C.ink, 6);
      const x = lerp(-300, 1300, seg(lt, 0, d * .9)); car2(g, x, 930, .72, { model: 'peugeot1894', color: C.red, spin: lt * 6, speed: .2, t: lt, driver: { suit: 'suit', hat: 'top', mustache: true, expr: 'smug' } });
      for (let i = 0; i < 5; i++) { const k = (lt * .8 + i * .2) % 1; circ(g, x - 200 - k * 160, 780 - k * 90, 18 + k * 30, '#CFC6B5', null, 0, false); }
      crowd(g, 1450, 2000, 900, 4, .5, 21, lt, { expr: 'happy' }); apex(200, 930, .6, { hat: 'flat', suit: 'plain', suitColor: C.tan, prop: 'paper', pose: 'point2', expr: 'grin', t: lt }); });
    card(M - 30, 100, 600, 180); cap('PARIS · 1894', lt, .3, M, 190, 80); small('cars: loud, fragile, a rich man’s toy', lt, 1.4, M, 250);
  } },
  P03_2: { cam: [[960, 540, 1.08], [960, 540, 1.0]], draw(lt, d, cam) {
    fill('#E7DDC8'); paper(g, W, H);
    L(cam, 1, () => { rrect(g, 200, 500, 760, 380, 16, C.grey, C.ink, 7); for (let i = 0; i < 3; i++) { const a = lt * 4 + i; circ(g, 330 + i * 250, 640, 80, C.silver, C.ink, 6); line(g, [[330 + i * 250, 640], [330 + i * 250 + Math.cos(a) * 70, 640 + Math.sin(a) * 70]], C.ink, 6); }
      for (let i = 0; i < 4; i++) { const k = (lt * .5 + i * .25) % 1; g.save(); g.translate(lerp(900, 1700, k), lerp(560, 300 - i * 30, k)); g.rotate(k * 1.2 - .3); rrect(g, -90, -60, 180, 120, 4, C.white, C.ink, 4); line(g, [[-70, -30], [70, -30]], C.ink, 8); for (let j = 0; j < 3; j++) line(g, [[-70, j * 20], [70, j * 20]], C.grey, 4); g.restore(); }
      fig(g, 1100, 900, .55, { suit: 'plain', suitColor: C.white, hat: 'flat', expr: 'happy', t: lt, pose: 'hold' }); });
    card(1180, 560, 620, 300, C.white); text(g, 'PARIS → ROUEN', 1220, 650, { size: 56, weight: 800, mis: C.orange, t: (lt - 1) * 2 });
    text(g, '≈ 126 km · prove they work', 1220, 720, { size: 34, weight: 600, t: (lt - 1.6) * 2 }); text(g, 'Le Petit Journal, 1894', 1220, 790, { size: 30, weight: 500, color: C.grey, t: (lt - 2.2) * 2 });
  } },
  P03_3: { cam: [[960, 540, 1.0], [1060, 560, 1.1]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#DCE6E8'); clouds(g, lt, 13, 4, 120); parisRow(-200, 640, 12, .7, 8); });
    L(cam, 1, () => { ground(700, '#CBBFA8'); line(g, [[100, 470], [1820, 470]], C.ink, 4); for (let i = 0; i < 20; i++) poly(g, [[100 + i * 86, 470], [143 + i * 86, 520], [186 + i * 86, 470]], [C.red, C.white, C.blue][i % 3], C.ink, 3);
      const models = [['dedion', C.blue], ['peugeot1894', C.red], ['panhard1895', C.mustard], ['peugeot1894', C.green], ['panhard1895', C.red]];
      models.forEach(([m, c], i) => car2(g, 1700 - i * 380, 820 + (i % 2) * 70, m === 'dedion' ? .42 : .5, { model: m, color: c, t: lt + i, driver: { hat: i % 2 ? 'bowler' : 'top', mustache: i % 2 === 0 } }));
      crowd(g, -200, 2100, 1060, 26, .34, 31, lt); });
    const n = Math.round(lerp(102, 21, eio(seg(lt, 1.2, d - 1))));
    card(M - 30, 100, 640, 210); cap(`${n}`, lt, .2, M, 220, 110); small(n > 21 ? 'entries…' : 'made it to the start', lt, .4, M + (n > 99 ? 210 : 140), 210);
  } },
  P04_1: { cam: [[1100, 560, 1.1], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#E3EBDD'); clouds(g, lt, 17, 4, 120); hills(g, W * 2, 560, '#9DB56B', 40, .004, 6); for (let i = 0; i < 12; i++) poplar(g, -200 + i * 220, 640, .55); });
    L(cam, 1, () => { ground(660, C.dust); line(g, [[1500, 660], [1500, 920]], C.ink, 7); line(g, [[1760, 660], [1760, 920]], C.ink, 7); rrect(g, 1480, 600, 300, 70, 6, C.white, C.ink, 5); text(g, 'ROUEN', 1630, 650, { size: 40, weight: 800, align: 'center' });
      car2(g, lerp(-500, 1180, eo(seg(lt, 0, d * .45))), 900, .5, { model: 'dedion', color: C.blue, spin: lt * 6, speed: .3, t: lt, driver: { hat: 'bowler', expr: 'grin' }, mech: { hat: 'flat', expr: 'sad' } });
      for (let i = 0; i < 3; i++) fig(g, 1560 + i * 110, 960, .38, { suit: 'suit', hat: 'bowler', expr: lt > d * .3 ? 'sad' : 'neutral', look: Math.sin(lt * 9 + i) * (lt > d * .3 ? 1 : 0), t: lt + i });
      if (lt > d * .6) { car2(g, lerp(-300, 700, eo(seg(lt, d * .6, d))), 960, .5, { model: 'peugeot1894', color: C.red, spin: lt * 6, t: lt, driver: { hat: 'top' } }); car2(g, lerp(-700, 320, eo(seg(lt, d * .65, d))), 1000, .5, { model: 'panhard1895', color: C.mustard, spin: lt * 6, t: lt, driver: { hat: 'flat' } }); } });
    card(M - 30, 100, 760, 300, C.white); cap('THE PRIZE WAS FOR:', lt, .3, M, 170, 46, { mis: C.red });
    ['• SAFE', '• EASY TO HANDLE', '• CHEAP TO RUN'].forEach((s, i) => small(s, lt, 1 + i * .5, M, 230 + i * 48, { weight: 700 }));
    if (lt > d * .4) small('steam = needs a stoker → ✕', lt, d * .4, M, 380, { color: C.red, size: 30 });
    if (lt > d * .65) { card(1100, 100, 700, 120, C.mustard); text(g, 'PEUGEOT + PANHARD share it', 1130, 180, { size: 40, weight: 800, t: (lt - d * .65) * 2 }); }
  } },
  P04_2: { cam: [[1100, 520, 1.05], [960, 540, 1.0]], draw(lt, d, cam) {
    fill(C.night); const r = rng(2); for (let i = 0; i < 120; i++) circ(g, r() * W, r() * H, 1.5 + r() * 2, C.paper, null, 0, false);
    const box = [600, 40, 1160, 900, -10, 9, 39.5, 49.5];
    L(cam, 1, () => { europe(g, box, { land: '#2E3F70' }); const a = P('Paris', box), b = P('Bordeaux', box);
      route(g, [a, [a[0] - 80, (a[1] + b[1]) / 2], b, [b[0] + 90, (a[1] + b[1]) / 2 + 40], a], seg(lt, .5, d - .8), C.mustard, 10);
      pin(g, a[0], a[1], lt - .3, C.blue, 'PARIS', { dx: 24, dy: 30 }); pin(g, b[0], b[1], lt - .6, C.red, 'BORDEAUX', { align: 'right', dx: -26 }); });
    const hrs = Math.floor(lerp(0, 48.78, seg(lt, .5, d - .8))), mins = Math.floor((lerp(0, 48.78, seg(lt, .5, d - .8)) % 1) * 60);
    card(M - 30, 100, 620, 280); cap('1895', lt, .2, M, 190, 80, { mis: C.mustard }); small('≈ 1,200 km · there and back', lt, .8, M, 250);
    text(g, `${String(hrs).padStart(2, '0')}h ${String(mins).padStart(2, '0')}m`, M, 340, { size: 64, weight: 800, color: C.orange, t: (lt - 1) * 2 });
  } },
  P04_3: { cam: [[900, 600, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#E3EBDD'); for (let i = 0; i < 12; i++) poplar(g, -200 + i * 220, 640, .55); });
    L(cam, 1, () => { ground(660, C.dust); car2(g, 760, 900, .75, { model: 'panhard1895', color: C.mustard, t: lt, driver: { hat: 'leather', expr: lt > 2 ? 'sad' : 'sleepy' } });
      fig(g, 1260, 910, .55, { suit: 'suit', hat: 'bowler', pose: 'point', dir: -1, expr: 'smug', t: lt, mustache: true });
      if (lt > d * .55) car2(g, lerp(2400, 1600, eo(seg(lt, d * .55, d))), 990, .55, { model: 'peugeot1894', color: C.red, t: lt, spin: lt * 5, driver: { hat: 'top', expr: 'grin' } }); });
    card(M - 30, 100, 760, 200, C.white); cap('RULE: 4 SEATS', lt, .4, M, 180, 66, { mis: C.red }); small('Levassor’s Panhard had 2', lt, 1.4, M, 245);
    stamp(g, '2 SEATS ✕', 1350, 330, lt - 2, { size: 80 });
    if (lt > d * .55) small('official win → a Peugeot, hours later', lt, d * .55, M, 360, { color: C.orange, weight: 700 });
  } },
  P05_1: { cam: [[960, 560, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    fill('#E7DDC8'); paper(g, W, H);
    L(cam, 1, () => { ground(880, '#CBBFA8'); car2(g, 860, 880, .9, { model: 'panhard1895', color: C.mustard, mud: 1 });
      apex(330, 880, .7, { suit: 'suit', hat: 'bowler', pose: 'point', expr: 'grin', t: lt });
      fig(g, 1380, 880, .55, { suitColor: C.blue, hat: 'flat', expr: 'happy', t: lt, look: Math.sin(lt * 4) > .3 ? 1 : 0 }); fig(g, 1580, 880, .5, { suitColor: C.tan, hat: 'bowler', expr: 'smug', t: lt + 1 }); });
    cap('RACING = THE BEST ADVERT', lt, .5, M, 190, 66); small('survives 1,200 km → sells itself', lt, 1.8, M, 250);
  } },
  P05_2: { cam: [[960, 540, 1], [960, 540, 1]], draw(lt) { checklist(lt, 1); } },
  P06_1: { cam: [[960, 540, 1.0], [960, 540, 1.08]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#EBDDB8'); hills(g, W * 2, 560, '#C9B98F', 30, .004, 5); });
    L(cam, .7, () => { for (let i = 0; i < 16; i++) poplar(g, ((i * 260 - lt * 700) % 4160 + 4160) % 4160 - 400, 690, .7); });
    L(cam, 1, () => { ground(700, C.dust); car2(g, 900, 900, .9, { model: 'renault1903', color: C.blue, spin: lt * 22, speed: 1, t: lt, driver: { hat: 'leather', expr: 'determined' }, mech: { hat: 'flat', expr: 'shock' } }); dust(g, 600, 860, 1, lt); speedLines(g, lt, 720, 900, 10, C.white); });
    const v = Math.min(105, lerp(20, 108, eo(seg(lt, .3, d * .7))));
    g.save(); g.translate(1620, 280); circ(g, 0, 0, 170, C.paper, C.ink, 8); for (let i = 0; i <= 12; i++) { const a = Math.PI * .75 + i / 12 * Math.PI * 1.5; line(g, [[Math.cos(a) * 140, Math.sin(a) * 140], [Math.cos(a) * 160, Math.sin(a) * 160]], C.ink, 5); }
    const a = Math.PI * .75 + v / 120 * Math.PI * 1.5; line(g, [[0, 0], [Math.cos(a) * 130, Math.sin(a) * 130]], C.red, 9); circ(g, 0, 0, 14, C.ink, null, 0, false);
    text(g, `${Math.round(v)} km/h`, 0, 90, { size: 44, weight: 800, align: 'center' }); g.restore();
    card(M - 30, 100, 560, 160); cap('1903', lt, .3, M, 210, 100);
  } },
  P06_2: { cam: [[1300, 560, 1.15], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#F2C98A'); sun(g, 1500, 520, 170, C.orange); clouds(g, lt, 19, 4, 160, '#F7E3BF'); });
    L(cam, .7, () => { parisRow(-300, 650, 14, .7, 12); crowd(g, -300, 2300, 690, 34, .26, 41, lt, { cheer: true }); });
    L(cam, 1, () => { ground(700, '#CBBFA8'); const cols = [C.blue, C.red, C.white, C.green, C.mustard, C.blue, C.red];
      for (let i = 6; i >= 0; i--) car2(g, 1800 - i * 330 + Math.max(0, lt - 2 - i * .3) * 120, 800 + (i % 3) * 80, .48, { model: i % 2 ? 'renault1903' : 'panhard1895', color: cols[i], spin: lt * 4, t: lt + i, driver: { hat: 'leather' }, mech: { hat: 'flat' } });
      crowd(g, -300, 2300, 1080, 24, .4, 43, lt); });
    card(M - 30, 100, 700, 200); cap('VERSAILLES → MADRID', lt, .3, M, 190, 66); small('24 May 1903 · dawn · 200+ cars', lt, 1.1, M, 250);
  } },
  P06_3: { cam: [[960, 540, 1.0], [960, 520, 1.1]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#E9DDBF'); hills(g, W * 2, 560, '#C9B98F', 30, .004, 5); });
    L(cam, .7, () => { for (let i = 0; i < 14; i++) poplar(g, -300 + i * 220, 690, .6, '#5E7A4A'); crowd(g, -300, 2300, 700, 30, .3, 31, lt); });
    L(cam, 1, () => { ground(700, C.dust); const x = lerp(-300, 2400, (lt % 4) / 4); car2(g, x, 880, .8, { model: 'renault1903', color: C.blue, spin: lt * 20, speed: 1, t: lt, driver: { hat: 'leather', expr: 'determined' }, mech: { hat: 'flat', expr: 'shock' } }); dust(g, x - 200, 850, 1.2, lt, C.dust, 900);
      for (let i = 0; i < 3; i++) fig(g, 1200 + i * 160, 960 + Math.sin(lt + i) * 4, .5, { suitColor: [C.tan, C.blue, C.brown][i], hat: i % 2 ? 'flat' : 'bowler', pose: i === 1 ? 'point2' : 'stand', expr: 'happy', t: lt + i }); });
    g.fillStyle = 'rgba(217,199,163,.35)'; g.fillRect(0, 0, W, H);
    card(M - 30, 100, 640, 160); cap('BLINDING DUST', lt, .4, M, 200, 74);
  } },
  P07_1: { cam: [[960, 540, 1.0], [1100, 560, 1.12]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#2C2F3A'); hills(g, W * 2, 650, '#22252E', 30, .004, 7); });
    L(cam, 1, () => { ground(740, '#4A4A52'); line(g, [[1300, 900], [1300, 520]], '#111', 26); circ(g, 1300, 460, 160, '#1E2127', null, 0, false);
      g.save(); g.translate(1050, 880); g.rotate(-.5); circ(g, 0, 0, 90, null, '#BBB', 12, false); for (let i = 0; i < 12; i++) line(g, [[0, 0], [Math.cos(i * .52) * 80, Math.sin(i * .52) * 80]], '#BBB', 4); g.restore();
      for (let i = 0; i < 6; i++) { const k = (lt * .25 + i / 6) % 1; g.globalAlpha = (1 - k) * .5; circ(g, 1150 - k * 80, 780 - k * 420, 40 + k * 90, '#777', null, 0, false); } g.globalAlpha = 1; });
    cap('"THE RACE OF DEATH"', lt, .5, M, 190, 76, { color: C.paper, mis: C.red });
    small('Marcel Renault · co-founder of Renault · 1872–1903', lt, 2.5, M, 250, { color: '#C8C2B6' });
  } },
  P07_2: { cam: [[960, 540, 1.05], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#DCE6E8'); parisRow(-200, 640, 12, .6, 21); });
    L(cam, 1, () => { ground(700, '#CBBFA8'); rrect(g, 1250, 520, 500, 80, 6, C.white, C.ink, 5); text(g, 'BORDEAUX', 1500, 575, { size: 44, weight: 800, align: 'center' });
      car2(g, 760, 900, .75, { model: 'renault1903', color: C.blue, t: lt, driver: { hat: 'leather', expr: lt > d * .45 ? 'sad' : 'happy' } });
      fig(g, lerp(1900, 1300, eo(seg(lt, 1, 3))), 920, .52, { pose: lt < 3 ? 'run' : 'hold', prop: 'paper', suitColor: C.blue, hat: 'kepi', expr: 'sad', dir: -1, t: lt }); });
    card(M - 30, 100, 700, 200); cap('LOUIS RENAULT', lt, .3, M, 180, 66); small('1st in his class · then the news', lt, 1.2, M, 245);
  } },
  P07_3: { cam: [[960, 560, 1.1], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#C9CFD6'); parisRow(-200, 640, 12, .6, 22); });
    L(cam, 1, () => { ground(700, '#BDB3A0');
      fig(g, 1650, 920, .58, { suit: 'uniform', hat: 'kepi', pose: 'stop', expr: 'determined', dir: -1, t: lt, mustache: true });
      for (let i = 0; i < 3; i++) { const x = lerp(-300, 1400, seg(lt, 0, d)) - i * 520; horse(x + 240, 930, .55, lt); line(g, [[x + 170, 880], [x + 220, 880]], C.ink, 5); car2(g, x, 930, .45, { model: i % 2 ? 'panhard1895' : 'renault1903', color: [C.blue, C.red, C.green][i], spin: lt * 2, t: lt, driver: { hat: 'leather', expr: 'sad' } }); } });
    stamp(g, 'STOPPED', 1300, 280, lt - .8, { size: 100 }); small('engines off · horses tow the cars to the station', lt, 2.5, M, 200, { weight: 700 });
  } },
  P08_1: { cam: [[960, 540, 1.0], [960, 540, 1.0]], draw(lt, d) {
    const box = [600, 40, 1160, 900, -10, 9, 39.5, 49.5]; mapScene(box, lt);
    const kOld = 1 - seg(lt, d * .35, d * .5);
    g.globalAlpha = kOld; route(g, [P('Paris', box), P('Bordeaux', box), P('Madrid', box)], seg(lt, 0, 1.5), C.red, 10); g.globalAlpha = 1;
    if (lt > d * .35) { const c = P('Le Mans', box), k = eo((lt - d * .4) / 1.2); g.beginPath(); g.ellipse(c[0], c[1], 80 * k, 50 * k, -.3, 0, 7); g.strokeStyle = C.orange; g.lineWidth = 14; g.stroke(); cap('CLOSED CIRCUITS', lt, d * .4, M, 200, 70); }
    else { cap('CITY-TO-CITY', lt, .2, M, 200, 70, { mis: C.red }); }
  } },
  P08_2: { cam: [[960, 540, 1], [960, 540, 1]], draw(lt) { checklist(lt, 2); } },
  P09_1: { cam: [[960, 560, 1.1], [960, 540, 1.0]], draw(lt, d, cam) {
    fill(C.paper); paper(g, W, H);
    L(cam, 1, () => { ground(860, C.light); g.save(); g.translate(960, 640); g.scale(2.2, 2.2); poly(g, [[-50, -120], [50, -120], [36, -50], [10, -30], [10, 0], [34, 14], [-34, 14], [-10, 0], [-10, -30], [-36, -50]], C.mustard, C.ink, 4); g.restore();
      fig(g, 660, 860, .55, { suit: 'suit', hat: 'top', mustache: true, expr: 'smug', pose: 'point', t: lt });
      [[C.blue, 'FRANCE'], [C.white, 'GERMANY'], [C.mustard, 'BELGIUM'], [C.red, 'USA'], [C.ink, 'ITALY*']].forEach(([col, n], i) => { const x = 1180 + i * 150, k = lt - 1 - i * .35; if (k < 0) return;
        fig(g, x, 860, .32 * pop(k * 1.3), { suitColor: col, expr: 'happy', pose: 'hold', t: lt + i }); rrect(g, x + 8, 860 - 230, 70, 46, 4, col, C.ink, 4); line(g, [[x + 8, 860 - 184], [x + 8, 860 - 120]], C.ink, 4); text(g, n, x, 910, { size: 22, weight: 700, align: 'center', t: k * 2 }); }); });
    cap('GORDON BENNETT CUP', lt, .3, M, 180, 70); small('1900–1905 · countries, not companies', lt, 1, M, 240); small('*Italy raced in black at first', lt, 3, 1180, 560, { size: 26, color: C.grey });
  } },
  P09_2: { cam: [[960, 540, 1], [960, 540, 1.04]], draw(lt, d, cam) {
    fill(C.paper); paper(g, W, H);
    [[C.blue, 'FRANCE'], [C.white, 'GERMANY'], [C.mustard, 'BELGIUM'], [C.red, 'USA']].forEach(([col, n], i) => {
      const at = .6 + i * .9, k = eo((lt - at) / 1.1), y = 360 + i * 185; line(g, [[0, y + 4], [W, y + 4]], C.light, 6);
      car2(g, lerp(-500, 1150, k), y, .42, { model: 'renault1903', color: col, spin: lt * 12, speed: 1 - k, t: lt, driver: { hat: 'leather' }, mech: { hat: 'flat' } });
      text(g, n, 1540, y - 40, { size: 46, weight: 800, t: (lt - at - .5) * 2, mis: col === C.white ? C.grey : col }); });
    cap('ONE COLOUR PER NATION · 1900', lt, .2, M, 170, 60);
  } },
  P09_3: { cam: [[960, 560, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#CFE0E8'); clouds(g, lt, 23, 3, 140); g.save(); g.translate(1380, 220); const sk = pop(seg(lt, d * .5, d * .6) * 1.6); g.scale(sk, sk); for (const [dx, dy] of [[-50, 0], [50, 0], [0, -70]]) circ(g, dx, dy, 62, '#4C9A5F', C.ink, 6); line(g, [[0, 40], [20, 140]], C.ink, 10); g.restore(); });
    L(cam, .6, () => { hills(g, W * 2, 560, '#3E7A4E', 50, .003, 3); fence(g, -300, 2300, 700); });
    L(cam, 1, () => { hills(g, W * 2, 700, C.green, 30, .005, 9); ground(780, C.dust, false); car2(g, lerp(-400, 900, eo(lt / (d * .7))), 920, .7, { model: 'renault1903', color: C.green, spin: lt * 14, speed: 1, t: lt, driver: { hat: 'leather', expr: 'happy' }, mech: { hat: 'flat' } }); dust(g, lerp(-400, 900, eo(lt / (d * .7))) - 200, 900, .6, lt);
      apex(1640, 930, .6, { prop: 'pot', pose: 'hold', expr: lt > d * .7 ? 'grin' : 'think', t: lt }); });
    card(M - 30, 100, 760, 200); cap('1903 · IRELAND', lt, .3, M, 180, 64); small('road racing was illegal in Britain', lt, 1.2, M, 245);
    if (lt > d * .78) { card(M - 30, 330, 860, 120, C.green); text(g, 'BRITISH RACING GREEN', M, 410, { size: 60, weight: 800, color: C.paper, t: (lt - d * .78) * 2 }); }
  } },
  P09_4: { cam: [[960, 540, 1], [960, 540, 1.05]], draw(lt, d, cam) {
    fill(C.paper); paper(g, W, H); ground(820, C.light);
    const k = eio(seg(lt, d * .3, d * .6));
    car2(g, lerp(960, 500, k), 820, .8, { model: 'renault1906', color: C.red, t: lt });
    if (k > 0) { g.globalAlpha = k; car2(g, lerp(960, 1400, k), 820, .66, { model: 'modern', color: C.red, t: lt, driver: { hat: 'helmet' } }); g.globalAlpha = 1; }
    text(g, '1906', lerp(960, 500, k), 920, { size: 44, weight: 800, align: 'center', t: 1 }); text(g, 'TODAY', 1400, 920, { size: 44, weight: 800, align: 'center', t: (lt - d * .55) * 2 });
    card(M - 30, 100, 960, 180); cap('ITALY = RED', lt, .5, M, 190, 90, { color: C.red, mis: C.mustard }); small('black at first · red later · Ferrari still races in it', lt, 1.6, M, 250);
  } },
  P10_1: { cam: [[960, 420, 1.15], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .2, () => { fill('#F0DDB0'); sun(g, 1550, 240, 140); clouds(g, lt, 29, 3, 120, '#F7E9C8'); });
    L(cam, .5, () => { hills(g, W * 2, 560, '#9DB56B', 50, .003, 4); for (let i = 0; i < 18; i++) poplar(g, -300 + i * 170, 600 + (i % 3) * 10, .42, '#4E7A44'); });
    L(cam, 1, () => { hills(g, W * 2, 700, '#6E9550', 40, .005, 11); g.beginPath(); g.ellipse(960, 860, 1100, 150, 0, 0, 7); g.strokeStyle = C.dust; g.lineWidth = 40; g.stroke(); g.strokeStyle = C.ink; g.lineWidth = 4; g.stroke();
      grandstand(700, 860, 520, 110, lt, C.blue, 51); for (let i = 0; i < 6; i++) pole(g, 200 + i * 300, 980, .6); });
    card(M - 30, 100, 840, 260); cap('GRAND PRIX', lt, .4, M, 230, 130, { mis: C.blue }); small('= French for "big prize" · 1906 · near Le Mans', lt, 1.4, M, 310, { weight: 700, color: C.red });
  } },
  P10_2: { cam: [[960, 540, 1.04], [960, 540, 1.0]], draw(lt, d) {
    fill(C.paper); paper(g, W, H); sun(g, 1700, 200, 110, C.orange);
    const loop = [[700, 820], [1500, 840], [1650, 700], [1300, 260], [1150, 250], [700, 700], [700, 820]];
    poly(g, loop, null, C.light, 40, true, false); route(g, loop, seg(lt, .3, 3), C.orange, 14);
    for (const [x, y, n] of [[700, 820, 'Saint-Calais'], [1650, 700, 'Vibraye'], [1300, 260, 'Le Mans']]) { circ(g, x, y, 14, C.ink, null, 0, false); text(g, n, x + 26, y - 18, { size: 28, weight: 600, t: lt - 1 }); }
    const laps = Math.min(12, 1 + Math.floor(seg(lt, 3, d - .5) * 12));
    cap('≈ 103 km PER LAP', lt, .5, M, 200, 60); small('2 DAYS · SUMMER HEAT', lt, 2, M, 290, { size: 44, weight: 700 }); small(`LAP ${laps} / 12`, lt, 3, M, 360, { size: 50, weight: 800, color: C.orange }); small('≈ 1,238 km', lt, 4, M, 430, { size: 40 });
  } },
  P10_3: { cam: [[960, 600, 1.15], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .4, () => { fill('#F0DDB0'); sun(g, 1600, 220, 140, C.orange); hills(g, W * 2, 600, '#9DB56B', 40, .004, 2); });
    L(cam, 1, () => { ground(720, C.dust); car2(g, 760, 900, .8, { model: 'renault1906', color: C.mustard, t: lt, driver: { hat: 'leather', expr: 'sad' } });
      fig(g, 1240, 930, .55, { pose: 'duck', hat: 'flat', suitColor: C.tan, expr: 'determined', t: lt });
      g.save(); g.translate(1350, 880); g.rotate(lt * .3); circ(g, 0, 0, 70, null, C.ink, 16, false); g.restore();
      for (let i = 0; i < 5; i++) { const k = (lt * .6 + i * .2) % 1; g.globalAlpha = 1 - k; circ(g, 1350 + Math.cos(i) * k * 120, 860 - k * 140, 10 + k * 26, '#BBB', null, 0, false); } g.globalAlpha = 1;
      if (Math.floor(lt * 2) % 4 === 0) stamp(g, 'BANG!', 1500, 600, (lt * 2 % 1) * .8, { size: 70, box: false, color: C.red }); });
    card(M - 30, 100, 700, 200); cap('TYRES EXPLODE', lt, .3, M, 180, 66, { mis: C.red }); small('cut off by hand · 10+ minutes each', lt, 1.3, M, 245);
  } },
  P11_1: { cam: [[960, 560, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    fill('#F0DDB0'); paper(g, W, H);
    L(cam, 1, () => { ground(860, C.dust); car2(g, 820, 860, .9, { model: 'renault1906', color: C.blue, t: lt, driver: { hat: 'leather', mustache: true, expr: 'determined' } });
      const k = seg(lt % 4, .5, 2.5); g.save(); g.translate(lerp(1500, 980, eio(k)), 760); g.rotate(lt * 3); circ(g, 0, 0, 80, null, C.ink, 18, false); circ(g, 0, 0, 62, null, C.grey, 6, false); g.restore();
      fig(g, 1500, 880, .55, { pose: 'hold', suitColor: C.blue, hat: 'flat', expr: 'grin', t: lt }); });
    card(M - 30, 100, 900, 330, C.white); cap('SECRET WEAPON', lt, .3, M, 175, 60); small('Michelin detachable rims · Renault & Fiat', lt, .9, M, 230, { weight: 700, color: C.orange });
    text(g, 'WITH RIMS   a few min', M, 320, { size: 44, weight: 800, t: (lt - 1.6) * 2 }); text(g, 'WITHOUT     10+ min', M, 390, { size: 44, weight: 800, color: C.grey, t: (lt - 2.2) * 2 });
  } },
  P11_2: { cam: [[960, 540, 1.0], [960, 540, 1.08]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#F0DDB0'); sun(g, 1600, 220, 120); hills(g, W * 2, 600, '#9DB56B', 40, .004, 2); });
    L(cam, .7, () => { for (let i = 0; i < 16; i++) poplar(g, ((i * 260 - lt * 800) % 4160 + 4160) % 4160 - 400, 700, .62); });
    L(cam, 1, () => { ground(740, C.dust); car2(g, 900, 920, .95, { model: 'renault1906', color: C.blue, spin: lt * 22, speed: 1, t: lt, driver: { hat: 'leather', mustache: true, expr: 'determined' }, mech: { apex: true, hat: 'leather', expr: lt > d * .5 ? 'shock' : 'grin' } }); dust(g, 560, 880, 1, lt); speedLines(g, lt, 760, 920, 10, C.paper); });
    card(M - 30, 100, 640, 200); cap('FERENC SZISZ', lt, .4, M, 180, 66); small('Hungarian mechanic · Renault', lt, 1, M, 245);
    if (lt > d * .45) { card(1240, 100, 560, 200, C.white); cap('≈ 101 km/h', lt, d * .45, 1280, 200, 84, { mis: C.red }); small('on dirt roads · 1906', lt, d * .6, 1280, 260); }
  } },
  P11_3: { cam: [[960, 540, 1.05], [960, 540, 1.0]], draw(lt, d) {
    fill(C.paper); paper(g, W, H); ground(860, C.light);
    const tilt = eio(seg(lt, 1.5, 4)) * 1.2; g.save(); g.translate(900, 860); g.rotate(tilt * .9);
    for (let i = 0; i < 7; i++) { g.save(); g.translate(Math.sin(i * 2.3) * 20, -40 - i * 66); g.rotate(tilt * (i % 2 ? .15 : -.1)); rrect(g, -150, -30, 300, 60, 6, [C.red, C.blue, C.green, C.mustard, C.tan, C.orange, C.light][i], C.ink, 5); g.restore(); }
    g.restore(); apex(1500, 860, .62, { pose: 'shrug', expr: 'sad', t: lt });
    cap('EVERY RACE, ITS OWN RULES', lt, .4, M, 190, 64); if (lt > d * .5) small('… and no overall champion', lt, d * .5, M, 250, { size: 44 });
  } },
  P12_1: { cam: [[960, 600, 1.15], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#9FB3D6'); g.fillStyle = tint(g, C.blue, .25); g.fillRect(-W, -H, 3 * W, H + 520); clouds(g, lt, 31, 3, 100, '#C7D3EA'); });
    L(cam, 1, () => { grandstand(150, 760, 1620, 300, lt, C.blue, 61); ground(760, '#8F8A80'); });
    card(M - 30, 80, 820, 180); cap('THE 1930s', lt, .4, M, 170, 86, { mis: C.blue }); small('a European Championship · and politics', lt, 1.4, M, 230);
  } },
  P12_2: { cam: [[960, 540, 1.0], [960, 540, 1.05]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#B7C6DE'); hills(g, W * 2, 560, '#6F8A6A', 30, .004, 7); });
    L(cam, .6, () => grandstand(-200 - ((lt * 400) % 900), 640, 4000, 120, lt, C.silver, 62));
    L(cam, 1, () => { ground(660, '#A9A49A'); car2(g, lerp(-700, 2600, seg((lt + 2.5) % 5, 0, 2.4)), 860, .72, { model: 'mercedesW25', color: C.silver, spin: lt * 24, speed: 1, t: lt, driver: { hat: 'helmet' } });
      car2(g, lerp(-700, 2600, seg((lt + 1.7) % 5, 0, 2.4)), 960, .72, { model: 'autounion', color: '#CDD2D8', spin: lt * 24, speed: 1, t: lt, driver: { hat: 'helmet' } }); speedLines(g, lt, 700, 1000, 16, C.white); });
    card(M - 30, 100, 760, 200); cap('SILVER ARROWS', lt, .6, M, 190, 84, { mis: C.silver }); small('Mercedes-Benz & Auto Union · state-backed', lt, 1.4, M, 250);
  } },
  P12_3: { cam: [[1100, 600, 1.1], [960, 540, 1.0]], draw(lt, d, cam) {
    fill(C.paper); paper(g, W, H);
    L(cam, 1, () => { ground(860, C.light); car2(g, 820, 860, .95, { model: 'mercedesW25', color: lt > d * .3 ? C.silver : C.white });
      fig(g, 400, 870, .58, { suit: 'plain', suitColor: C.blue, prop: 'sander', pose: 'hold', expr: 'determined', t: lt });
      const r = rng(6); for (let i = 0; i < 16; i++) { const k = (lt * .6 + r()) % 1; poly(g, [[600 + r() * 360, 700 + k * 160], [618 + r() * 360, 700 + k * 160], [612 + r() * 360, 714 + k * 160]], C.white, C.ink, 2); }
      apex(1660, 870, .6, { hat: 'deerstalker', prop: 'magnifier', pose: 'hold', expr: lt > d * .45 ? 'smug' : 'think', t: lt }); });
    cap('PAINT SCRAPED OFF?', lt, .3, M, 190, 70); stamp(g, 'MYTH?', 1240, 330, lt - d * .45, { size: 120 });
    if (lt > d * .6) small('that weight limit didn’t even apply at the race', lt, d * .6, M, 250, { weight: 600 });
  } },
  P13_1: { cam: [[960, 540, 1.0], [1000, 540, 1.1]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#C9D6E3'); clouds(g, lt, 37, 4, 120); hills(g, W * 2, 520, '#4E6E4A', 60, .003, 9); crowd(g, -300, 2300, 520, 40, .18, 71, lt, { cheer: true }); });
    L(cam, .7, () => { for (let i = 0; i < 22; i++) pine(((i * 180 - lt * 500) % 3960 + 3960) % 3960 - 400, 690, .9); });
    L(cam, 1, () => { ground(700, '#9E998E'); const lead = seg(lt, d * .4, d * .85);
      car2(g, 1100 + lead * 200, 900, .62, { model: 'mercedesW25', color: C.silver, spin: lt * 22, speed: 1, t: lt, driver: { hat: 'helmet', expr: lt > d * .7 ? 'shock' : 'neutral' } });
      car2(g, 700 + lead * 800, 980, .62, { model: 'alfaP3', color: C.red, spin: lt * 22, speed: 1, t: lt, driver: { hat: 'leather', expr: 'determined' } }); speedLines(g, lt, 720, 1000, 12, C.white); });
    card(M - 30, 100, 900, 220); cap('NUVOLARI · 1935', lt, .3, M, 190, 76, { mis: C.red }); small('old red Alfa vs the Silver Arrows · ≈300,000 fans', lt, 1.2, M, 250);
    if (lt > d * .75) stamp(g, 'LAST-LAP WIN', 1420, 380, lt - d * .75, { size: 64 });
  } },
  P13_2: { cam: [[960, 540, 1.0], [960, 560, 1.08]], draw(lt, d, cam) {
    fill('#BDB8AE'); L(cam, 1, () => { ground(760, '#8F8A80'); const r = rng(8); for (let i = 0; i < 120; i++) { const x = r() * W, h = 20 + r() * 60; line(g, [[x, 760 + r() * 160], [x + 6, 760 + r() * 160 - h]], '#5D6B4E', 4); }
      line(g, [[600, 900], [600, 560]], C.ink, 12); line(g, [[1320, 900], [1320, 560]], C.ink, 12); curve(g, [600, 640], [960, 760 + Math.sin(lt) * 6], [1320, 640], '#555', 10);
      rrect(g, 860, 660, 200, 90, 6, C.paper, C.ink, 5); text(g, 'CLOSED', 960, 720, { size: 40, weight: 800, align: 'center', color: C.red, t: 1 }); });
    cap('1939–1945', lt, .4, M, 200, 100, { mis: C.grey });
  } },
  P13_3: { cam: [[1000, 600, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    fill('#6B4A2E'); L(cam, 1, () => { for (let i = 0; i < 16; i++) line(g, [[i * 130 - 60, 0], [i * 130 - 60, 860]], '#5A3D25', 8);
      ground(860, '#C9A85E'); for (let i = 0; i < 7; i++) poly(g, [[60 + i * 300, 860], [140 + i * 300, 700], [260 + i * 300, 860]], C.mustard, C.ink, 4);
      car2(g, 960, 880, .85, { model: 'alfa158', color: C.red, num: 1 }); for (let i = 0; i < 6; i++) rrect(g, 660 + i * 66, 650 + (i % 2) * 40, 300, 34, 16, C.tan, C.ink, 5);
      const px = lerp(1700, 1400, eo(seg(lt, 1, 4))); poly(g, [[px - 110, 900], [px - 120, 820], [px - 60, 780], [px + 80, 790], [px + 110, 840], [px + 100, 900]], '#E9A9A0', C.ink, 6); circ(g, px - 128, 846, 22, '#E9A9A0', C.ink, 5); circ(g, px - 70, 815, 6, C.ink, null, 0, false);
      apex(330, 900, .6, { pose: 'hush', expr: 'smug', t: lt, hat: 'flat' }); });
    card(M - 30, 100, 760, 200); cap('ALFA ROMEO 158', lt, .4, M, 180, 70, { mis: C.red }); small('hidden near Milan: cheese factory? pig farm?', lt, d * .3, M, 245);
  } },
  P14_1: { cam: [[960, 600, 1.1], [960, 540, 1.0]], draw(lt, d, cam) {
    fill('#D6CBB4'); L(cam, 1, () => { rrect(g, 1300, 120, 460, 300, 8, '#E9E0CC', C.ink, 6); line(g, [[1530, 120], [1530, 420]], C.ink, 5); line(g, [[1300, 270], [1760, 270]], C.ink, 5);
      for (let i = 0; i < 4; i++) fig(g, 520 + i * 300, 880, .62, { suit: 'suit', hat: i % 2 ? 'bowler' : null, mustache: i % 2 === 0, expr: 'think', t: lt + i, look: Math.sin(lt + i) });
      poly(g, [[300, 900], [300, 790], [1620, 790], [1620, 900]], C.brown, C.ink, 7);
      g.save(); g.translate(960, 770); const k = pop(seg(lt, .8, 2.2) * 1.6); g.scale(k, k); rrect(g, -170, -110, 340, 120, 8, C.red, C.ink, 6); text(g, 'THE FORMULA', 0, -32, { size: 40, weight: 800, align: 'center', color: C.paper }); g.restore(); });
    card(M - 30, 100, 760, 200); cap('1946 · ONE RULEBOOK', lt, .3, M, 180, 64); small('formula = the rules every car must follow', lt, d * .4, M, 245);
  } },
  P14_2: { cam: [[960, 540, 1.0], [960, 560, 1.06]], draw(lt, d) {
    fill(C.paper); paper(g, W, H); const tilt = Math.sin(lt * 1.6) * .04 * (1 - seg(lt, 2.5, 5));
    poly(g, [[900, 880], [1020, 880], [960, 560]], C.tan, C.ink, 6); g.save(); g.translate(960, 560); g.rotate(tilt); line(g, [[-560, 0], [560, 0]], C.ink, 14);
    for (const [sx, big] of [[-480, 1], [480, 0]]) { line(g, [[sx - 120, 0], [sx - 120, 160]], C.ink, 4); line(g, [[sx + 120, 0], [sx + 120, 160]], C.ink, 4); poly(g, [[sx - 170, 160], [sx + 170, 160], [sx + 120, 200], [sx - 120, 200]], C.light, C.ink, 6);
      if (big) { rrect(g, sx - 120, 0, 240, 150, 10, C.grey, C.ink, 6); for (let i = 0; i < 4; i++) circ(g, sx - 80 + i * 54, 20, 16, C.silver, C.ink, 3, false); }
      else { rrect(g, sx - 90, 60, 150, 100, 10, C.grey, C.ink, 6); circ(g, sx + 90, 100, 44, C.mustard, C.ink, 6); for (let i = 0; i < 6; i++) line(g, [[sx + 90, 100], [sx + 90 + Math.cos(lt * 8 + i) * 40, 100 + Math.sin(lt * 8 + i) * 40]], C.ink, 4); } }
    g.restore(); text(g, '4.5 L', 480, 360, { size: 80, weight: 800, align: 'center', t: (lt - .6) * 2, mis: C.orange }); text(g, '1.5 L + SUPERCHARGER', 1440, 360, { size: 52, weight: 800, align: 'center', t: (lt - 1.6) * 2, mis: C.orange });
    cap('THE FIRST FORMULA', lt, .2, M, 170, 60);
  } },
  P14_3: { cam: [[960, 540, 1.05], [960, 540, 1.0]], draw(lt, d) {
    fill(C.paper); paper(g, W, H); ground(900, C.light); const k = seg(lt, 0, d * .4);
    car2(g, lerp(-300, 300, eo(k)), 900, 1.2, { model: 'autounion', color: C.ink, spin: lt * 4, t: lt, driver: { hat: 'top', expr: 'smug' } });
    if (lt > d * .3) { g.save(); g.translate(820, 900); const s = pop(seg(lt, d * .3, d * .45) * 1.6); g.scale(s, s); for (let i = 0; i < 5; i++) rrect(g, -60, -80 - i * 80, 120, 76, 6, [C.red, C.blue, C.mustard, C.green, C.orange][i], C.ink, 5); text(g, 'RULES', 0, -450, { size: 44, weight: 800, align: 'center', t: 1 }); g.restore(); }
    if (lt > d * .5) { const x = lerp(1100, 1700, seg(lt, d * .5, d)); car2(g, x, 880, .5, { model: 'alfa158', color: C.red, spin: lt * 14, speed: 1, t: lt, driver: { hat: 'leather' } }); car2(g, x + 40, 990, .5, { model: 'alfa158', color: C.green, spin: lt * 14, speed: 1, t: lt + 1, driver: { hat: 'leather' } }); }
    cap(lt < d * .5 ? 'NO RULES → THE RICHEST WINS' : 'ONE FORMULA → A FAIR FIGHT', lt, lt < d * .5 ? .3 : d * .5, M, 190, 62);
  } },
  P14_4: { cam: [[960, 540, 1], [960, 540, 1]], draw(lt) { checklist(lt, 3); } },
  P15_1: { cam: [[960, 540, 1.0], [960, 540, 1.05]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#DCE6E8'); clouds(g, lt, 41, 4, 120); hills(g, W * 2, 560, '#8FB07A', 30, .004, 4); });
    L(cam, 1, () => { ground(640, '#BDB6A8'); g.fillStyle = C.grass; g.fillRect(-W, 880, 3 * W, H);
      car2(g, lerp(-300, 2300, seg(lt, .3, 3)), 860, .62, { model: 'bike', color: C.blue, spin: lt * 18, speed: 1, t: lt, driver: { hat: 'leather', prop: 'trophy', pose: 'hold', expr: 'grin' } });
      car2(g, 1150, 900, .72, { model: 'alfa158', color: C.red, t: lt, num: 1, driver: { hat: 'leather', expr: lt > 2 ? 'sad' : 'neutral', look: -1 } }); });
    card(M - 30, 100, 900, 200); cap('1949', lt, .3, M, 190, 100); small('MOTORCYCLE WORLD CHAMPIONSHIP', lt, .9, M, 250, { weight: 800 });
  } },
  P15_2: { cam: [[960, 540, 1.0], [1000, 520, 1.08]], draw(lt, d, cam) {
    const box = [500, 0, 1220, 990, -4, 16, 42.5, 53.5]; L(cam, 1, () => { mapScene(box, lt);
      const pts = ['Silverstone', 'Monaco', 'Bern', 'Spa', 'Reims', 'Monza'].map(n => P(n, box)); route(g, pts, seg(lt, d * .3, d * .8), C.orange, 10); pts.forEach((p, i) => pin(g, p[0], p[1], lt - .8 - i * .35, C.red)); });
    fig(g, 260, 920, .6, { suit: 'suit', mustache: true, pose: 'point', expr: 'smug', t: lt });
    card(M - 30, 100, 820, 280); cap('ONE SEASON. ONE CHAMPION.', lt, .4, M, 180, 54); small('proposed by Count Antonio Brivio, 1950', lt, 1.2, M, 235);
    text(g, '8 · 6 · 4 · 3 · 2  + 1 fastest lap', M, 320, { size: 40, weight: 800, color: C.orange, t: (lt - d * .55) * 2 });
  } },
  P15_3: { cam: [[960, 540, 1.0], [960, 540, 1.0]], draw(lt, d) {
    const box = [200, 0, 1220, 990, -4, 16, 42.5, 53.5]; mapScene(box, lt);
    const races = [['Silverstone', 'BRITAIN'], ['Monaco', 'MONACO'], [null, 'INDIANAPOLIS 500 (USA)'], ['Bern', 'SWITZERLAND'], ['Spa', 'BELGIUM'], ['Reims', 'FRANCE'], ['Monza', 'ITALY']];
    card(1340, 140, 520, 780); text(g, '1950 · 7 RACES', 1380, 215, { size: 42, weight: 800, t: lt * 2 });
    races.forEach(([c, n], i) => { const k = lt - .4 - i * .45; if (c) { const p = P(c, box); pin(g, p[0], p[1], k, C.red); } text(g, `${i + 1}. ${n}`, 1380, 295 + i * 84, { size: 32, weight: c ? 600 : 800, color: c ? C.ink : C.blue, t: k * 2 }); });
    if (lt > 3.4) { rrect(g, 80, 780, 360, 110, 12, C.blue, C.ink, 5); text(g, '← USA', 120, 852, { size: 48, weight: 800, color: C.paper, t: (lt - 3.4) * 2 }); }
  } },
  P16_1: { cam: [[960, 540, 1.0], [960, 540, 1.0]], draw(lt, d, cam) {
    const sw = d * .38;
    if (lt < sw) { fill('#6B4A2E'); ground(860, '#C9A85E'); const k = eo(seg(lt, .4, 1.4));
      car2(g, 960 + Math.max(0, lt - 1.2) * 1000, 900, .8, { model: 'alfa158', color: C.red, num: 1, spin: lt * 16, speed: 1, t: lt, driver: { hat: 'leather', expr: 'determined' } }); dust(g, 760 + Math.max(0, lt - 1.2) * 1000, 880, seg(lt, 1.2, 1.6), lt, C.mustard);
      poly(g, [[560 - k * 420, 240], [960 - k * 420, 240], [960 - k * 420, 860], [560 - k * 420, 860]], C.brown, C.ink, 8); poly(g, [[960 + k * 420, 240], [1360 + k * 420, 240], [1360 + k * 420, 860], [960 + k * 420, 860]], C.brown, C.ink, 8); }
    else { L(cam, .3, () => { fill('#D6E4EA'); clouds(g, lt, 8, 4, 140); hills(g, W * 2, 520, '#8FB07A', 30, .003, 4); }); L(cam, .7, () => grandstand(-300, 560, 2600, 130, lt, C.green, 23));
      L(cam, 1, () => { ground(640, '#BDB6A8'); g.fillStyle = C.grass; g.fillRect(-W, 900, 3 * W, H); line(g, [[1500, 640], [1500, 900]], C.ink, 10); for (let i = 0; i < 6; i++) { g.fillStyle = i % 2 ? C.ink : C.white; g.fillRect(1490, 640 + i * 43, 20, 43); }
        car2(g, lerp(-300, 1400, eo((lt - sw) / 2.4)), 860, .8, { model: 'alfa158', color: C.red, num: 1, spin: lt * 18, speed: 1, t: lt, driver: { hat: 'leather', expr: 'grin' } }); bales(g, -100, W + 100, 960, 1); }); }
    card(M - 30, 100, 880, 160); cap('SAME MODEL: ALFA ROMEO 158', lt, .3, M, 200, 60);
  } },
  P16_2: { cam: [[960, 540, 1.1], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .3, () => { fill('#F3E3C3'); sun(g, 1600, 200, 110); hills(g, W * 2, 560, '#9DB56B', 30, .004, 8); for (let i = 0; i < 20; i++) tree(g, -300 + i * 140, 640, .55, '#4E7A44'); });
    L(cam, 1, () => { ground(660, '#BDB6A8'); car2(g, 760 + Math.sin(lt) * 30, 860, .66, { model: 'alfa158', color: C.red, spin: lt * 20, speed: 1, t: lt, num: 1, driver: { hat: 'leather', expr: 'determined' } }); car2(g, 900 - Math.sin(lt) * 30, 980, .66, { model: 'alfa158', color: C.red, spin: lt * 20, speed: 1, t: lt + 1, num: 1, driver: { hat: 'leather', expr: 'grin' } }); speedLines(g, lt, 700, 1000, 10, C.white); });
    card(1260, 100, 560, 280, C.white); text(g, 'BEFORE MONZA', 1300, 170, { size: 36, weight: 800, color: C.grey, t: lt * 2 });
    text(g, 'FANGIO   +2', 1300, 250, { size: 52, weight: 800, t: (lt - .8) * 2 }); text(g, 'FARINA', 1300, 330, { size: 52, weight: 800, t: (lt - 1.2) * 2, color: C.red }); small('Fangio leads by 2 points', lt, 2, M, 330, { color: C.orange });
    card(M - 30, 100, 700, 200); cap('MONZA · 1950', lt, .3, M, 180, 70); small('team-mates fight for the title', lt, 1.2, M, 245);
  } },
  P16_3: { cam: [[960, 600, 1.12], [960, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .5, () => { fill('#CFE0E8'); crowd(g, -300, 2300, 620, 30, .32, 51, lt, { cheer: true }); });
    L(cam, 1, () => { ground(860, C.light); for (const [x, h, col] of [[960, 260, C.mustard], [700, 170, C.silver], [1220, 120, C.tan]]) poly(g, [[x - 120, 860], [x - 120, 860 - h], [x + 120, 860 - h], [x + 120, 860]], col, C.ink, 6);
      fig(g, 960, 600, .55, { hat: 'leather', suitColor: C.white, prop: 'trophy', pose: 'cheer', expr: 'grin', t: lt }); fig(g, 700, 690, .5, { hat: 'leather', suitColor: C.white, expr: 'happy', t: lt + 1 });
      apex(1640, 900, .55, { pose: 'cheer', expr: 'happy', t: lt + .5, suit: 'tweed', hat: 'flat' }); });
    const r = rng(9); for (let i = 0; i < 80; i++) { const k = (lt * .35 + r()) % 1; g.fillStyle = [C.red, C.orange, C.mustard, C.blue][i % 4]; g.save(); g.translate(r() * W, k * 900); g.rotate(lt * 3 + i); g.fillRect(-7, -11, 14, 22); g.restore(); }
    card(M - 30, 90, 900, 290, C.white); cap('GIUSEPPE FARINA', lt, .3, M, 170, 66); small('FIRST FORMULA ONE WORLD CHAMPION', lt, 1, M, 225, { weight: 800, color: C.orange });
    text(g, 'FARINA 30 · FANGIO 27', M, 320, { size: 50, weight: 800, t: (lt - 2) * 2 });
  } },
  P16_4: { cam: [[960, 540, 1], [960, 540, 1]], draw(lt) { checklist(lt, 4, true); } },
  P17_1: { cam: [[960, 540, 1.0], [960, 540, 1.05]], draw(lt, d) { checklist(lt + 6, 4, true); g.fillStyle = `rgba(228,225,218,${eio(seg(lt, d * .6, d))})`; g.fillRect(0, 0, W, H); } },
  P17_2: { cam: [[1300, 560, 1.1], [800, 540, 1.0]], draw(lt, d, cam) {
    L(cam, .5, () => { fill('#E4E1DA'); const cols = [C.red, C.orange, '#2E8B8B', C.silver, C.blue, C.green, '#E6E6E6']; for (let i = 0; i < 7; i++) { poly(g, [[-200 + i * 380, 640], [-200 + i * 380, 300], [140 + i * 380, 300], [140 + i * 380, 640]], C.light, C.ink, 6); rrect(g, -200 + i * 380, 300, 340, 50, 0, cols[i], C.ink, 5, false); } });
    L(cam, 1, () => { ground(640, '#9A9690'); for (let x = -200; x < W + 400; x += 60) { g.fillStyle = C.white; g.fillRect(x, 760, 30, 6); }
      car2(g, 300, 900, .6, { model: 'modern', color: C.red, t: lt, driver: { hat: 'helmet' } }); car2(g, 1250, 960, .6, { model: 'modern', color: C.orange, t: lt, driver: { hat: 'helmet', hatColor: C.mustard } });
      apex(lerp(1900, 800, seg(lt, 0, d)), 960, .55, { suit: 'pit', hat: 'headset', pose: 'walk', expr: 'happy', t: lt }); });
    card(M - 30, 100, 700, 200); cap('76 YEARS LATER', lt, .3, M, 180, 72); small('22 drivers · one title', lt, 1.4, M, 245, { weight: 800, color: C.orange });
  } },
  P17_3: { cam: [[960, 620, 1.2], [960, 560, 1.05]], draw(lt, d, cam) {
    L(cam, 1, () => { fill('#E4E1DA'); ground(640, '#9A9690'); apex(960, 940, .8, { suit: 'pit', hat: 'headset', prop: 'paper', pose: 'hold', expr: 'grin', t: lt }); text(g, '1894', 1180, 500, { size: 60, weight: 800, t: lt * 2, mis: C.orange }); });
  } },
  P17_4: { cam: [[960, 540, 1], [960, 540, 1]], draw(lt, d) {
    fill(C.paper); paper(g, W, H);
    small('NEXT EPISODE', lt, .3, M, 260, { size: 40, weight: 800, color: C.orange });
    text(g, 'FROM DEADLY HOBBY', M, 360, { size: 76, weight: 800, t: (lt - .6) * 2, mis: C.orange }); text(g, 'TO BILLION-DOLLAR MACHINE', M, 450, { size: 76, weight: 800, t: (lt - .9) * 2, mis: C.orange });
    rrect(g, M, 560, 470, 110, 55, C.red, C.ink, 6); poly(g, [[M + 60, 585], [M + 60, 645], [M + 110, 615]], C.white, null, 0, true, false); text(g, 'SUBSCRIBE', M + 140, 632, { size: 44, weight: 800, color: C.white, t: (lt - 1.4) * 2 });
    car2(g, 1460, 960, .55, { model: 'modern', color: C.orange, t: lt }); apex(1500, 760, .7, { pose: 'wave', expr: 'happy', t: lt });
  } },
};

// ---------- sound cues (seconds after a shot starts; 'h' = middle) ----------
const SFX = {
  P00_1: [[1, 'engine'], ['h', 'stamp']],
  P01_1: [[0, 'low']], P01_2: [[.3, 'draw'], [1.5, 'cheer']], P01_3: [[0, 'cheer']], P02_1: [[0, 'engine']], P02_2: [[0, 'engine'], [1, 'pass'], [2.7, 'pass'], [4.4, 'pass']],
  P02_3: [[.4, 'stamp'], ['h', 'paper']], TITLE: [[0, 'title']], P03_1: [[0, 'chug']], P03_2: [[0, 'press']], P03_3: [[1.2, 'tick']], P04_1: [[0, 'chug'], [2, 'stamp']],
  P04_2: [[.5, 'draw']], P04_3: [[2, 'stamp']], P05_2: [[.7, 'ding']], P06_1: [[0, 'engine']], P06_2: [[0, 'cheer']], P06_3: [[0, 'pass'], [4, 'pass']], P07_1: [[0, 'low']],
  P07_3: [[.8, 'stamp']], P08_1: [[1, 'draw']], P08_2: [[.7, 'ding']], P09_2: [[.8, 'pass'], [1.9, 'pass'], [3, 'pass']], P10_3: [[0, 'thump'], [2, 'thump']], P11_1: [[.5, 'click'], [1.6, 'ding']],
  P11_2: [[0, 'engine']], P12_1: [[0, 'cheer']], P12_2: [[.2, 'pass'], [1, 'pass'], [5.2, 'pass'], [6, 'pass']], P12_3: [['h', 'stamp']], P13_1: [[0, 'engine'], [0, 'cheer']],
  P13_2: [[0, 'low']], P14_1: [[.9, 'thump']], P14_4: [[.7, 'ding']], P15_1: [[.3, 'pass']], P15_2: [[1, 'draw']], P16_1: [[.4, 'doors'], [1.2, 'engine']], P16_2: [[0, 'engine']],
  P16_3: [[0, 'cheer']], P16_4: [[.8, 'ding'], [1.35, 'ding'], [1.9, 'ding'], [2.45, 'ding']], P17_4: [[0, 'title']],
};

// ---------- timeline plumbing ----------
const SHOTS = T.shots;
const shotAt = t => SHOTS.find(s => t >= s.s0 && t < s.s1) || SHOTS[SHOTS.length - 1];
const chapterAt = t => [...T.chapters].reverse().find(c => t >= c.t0) || T.chapters[0];
window.DUR = T.dur;
window.EV = SHOTS.flatMap(s => [{ t: +s.s0.toFixed(3), type: 'cut', id: s.id },
  ...(SFX[s.id] || []).map(([dt, type]) => ({ t: +(s.s0 + (dt === 'h' ? (s.s1 - s.s0) * .5 : dt)).toFixed(3), type, id: s.id }))]);

function drawShot(sc, lt) {
  const S = SH[sc.id], d = sc.s1 - sc.s0; if (!S) { fill(C.paper); return; }
  const cam = camAt(S.cam[0], S.cam[1], eio(clamp(lt / d)));
  g.save(); S.draw(lt, d, cam); g.restore();
}
function hud(t, sc) {
  if (sc.id === 'TITLE' || sc.id === 'P17_4') return;
  const ch = chapterAt(t); if (!ch || t < 6) return;
  text(g, ch.name.toUpperCase(), W - 70, 64, { size: 22, weight: 700, color: C.grey, align: 'right', track: 3 });
}
function subtitles(t) {
  const c = CUES.find(c => t >= c.t0 && t < c.t1); if (!c) return;
  g.font = '500 40px Jost'; const w = g.measureText(c.text).width;
  g.globalAlpha = .94; rrect(g, M - 24, 962, w + 52, 66, 10, C.white, null, 0, false); g.globalAlpha = 1;
  g.fillStyle = C.orange; g.fillRect(M - 24, 962, 7, 66);
  g.fillStyle = C.ink; g.textAlign = 'left'; g.textBaseline = 'alphabetic'; g.fillText(c.text, M + 4, 1008);
}
const TR = .5;   // roller-wipe length
window.render = t => {
  const i = SHOTS.indexOf(shotAt(t)), sc = SHOTS[i], lt = t - sc.s0;
  g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.clearRect(0, 0, W, H);
  if (i > 0 && lt < TR) {
    const prev = SHOTS[i - 1]; drawShot(prev, prev.s1 - prev.s0 + lt);
    const x = W * eio(lt / TR);
    g.save(); g.beginPath(); g.rect(0, 0, x, H); g.clip(); drawShot(sc, lt); g.restore();
    g.fillStyle = C.orange; g.fillRect(x - 14, 0, 28, H); g.fillStyle = tint(g, C.ink, .3, 8); g.fillRect(x + 14, 0, 40, H);
  } else drawShot(sc, lt);
  vignette(g); hud(t, sc); subtitles(t);
};
window.TEXTS = () => [];
window.render(0);
window.READY = true;
