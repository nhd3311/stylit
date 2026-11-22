// F1 Ep. 001 — Why does F1 even exist? Scenes driven by timeline.json (built from the voice).
import { C, clamp, lerp, seg, eo, eio, pop, rng, poly, circ, line, curve, rrect, tint, paper, text, stamp, fig, car, dustCloud,
  hills, sun, tree, building, crowd, europe, proj, CITY, pin, route } from './draw.js';

const W = 1920, H = 1080, M = 124, GROUND = 860;
const cv = document.getElementById('c'), g = cv.getContext('2d');
const T = await (await fetch('timeline.json')).json();
await Promise.all([document.fonts.load('700 40px Jost'), document.fonts.load('800 40px Jost'), document.fonts.load('500 40px Jost'), document.fonts.load('40px Hand')]);

const apex = (x, y, s, o = {}) => fig(g, x, y, s, { apex: true, ...o });
const cap = (s, lt, at, x = M, y = 200, size = 64, o = {}) => text(g, s, x, y, { size, weight: 800, t: (lt - at) / .45, mis: o.mis ?? C.orange, ...o });
const small = (s, lt, at, x = M, y = 260, o = {}) => text(g, s, x, y, { size: 34, weight: 500, color: o.color || C.ink, t: (lt - at) / .45, track: 1, ...o });
const sky = (col) => { g.fillStyle = col; g.fillRect(0, 0, W, H); };
const groundBand = (y, col) => { g.save(); g.translate(4, 3); g.fillStyle = col; g.fillRect(0, y, W, H - y); g.restore(); line(g, [[0, y], [W, y]], C.ink, 6); };

// ---------- reusable sets ----------
function airfield(lt) {
  sky(C.grass);
  g.save(); g.translate(W / 2, H / 2 - 20); g.rotate(-.08);
  // wartime runways: a triangle of wide concrete strips
  for (const [a, b] of [[[-620, 260], [560, 300]], [[-620, 260], [40, -380]], [[560, 300], [40, -380]]]) line(g, [a, b], '#CFC9BB', 110);
  for (const [a, b] of [[[-620, 260], [560, 300]], [[-620, 260], [40, -380]], [[560, 300], [40, -380]]]) { g.setLineDash([30, 26]); line(g, [a, b], C.white, 6); g.setLineDash([]); }
  // the race track: perimeter roads, drawn in orange as the camera arrives
  const loop = [[-700, 300], [-560, 400], [200, 420], [640, 340], [700, 200], [380, -200], [120, -430], [-60, -420], [-260, -160], [-640, 100], [-700, 300]];
  route(g, loop, eo(lt / 3), C.orange, 16);
  g.restore();
  // crowd as dots along the bottom
  const r = rng(3); for (let i = 0; i < 260; i++) circ(g, r() * W, 930 + r() * 150, 7, [C.red, C.blue, C.mustard, C.paper][i % 4], null, 0, false);
}
function track(lt, o = {}) {
  sky(o.sky || '#CFE0E8'); hills(g, W, 560, o.hill || C.grass, 40, .004, 2);
  groundBand(640, '#BDB6A8');
  g.fillStyle = C.grass; g.fillRect(0, 880, W, 200);
  line(g, [[0, 880], [W, 880]], C.ink, 6);
  for (let x = 0; x < W; x += 80) { g.fillStyle = (x / 80) % 2 ? C.red : C.white; g.fillRect(x, 872, 80, 16); }
}
function checklist(lt, n, all = false) {
  sky(C.paper); paper(g, W, H);
  const items = ['PROVE THE MACHINE WORKS', 'A SAFE PLACE TO RACE', 'MAKE IT FAIR', 'CROWN ONE CHAMPION'];
  const x = 220, y = 210; rrect(g, x, y, 1000, 560, 18, C.white, C.ink, 7);
  text(g, 'WHY F1 EXISTS', x + 50, y + 90, { size: 54, weight: 800, mis: C.orange });
  items.forEach((s, i) => {
    const yy = y + 190 + i * 95, shown = i < n || all;
    rrect(g, x + 50, yy - 42, 54, 54, 8, C.paper, C.ink, 5, false);
    if (shown) {
      const tk = all ? (lt - 1.0 - i * 1.6) : (i === n - 1 ? lt - 1.0 : 9);
      text(g, s, x + 130, yy, { size: 44, weight: 700, color: i === n - 1 || all ? C.ink : C.grey, t: all ? tk * 2 + .4 : 1 });
      if (tk > 0) { const k = eo(tk / .35); line(g, [[x + 60, yy - 18], [x + 74, yy - 2], [x + 74 + 40 * k, yy - 2 - 50 * k]], C.orange, 11); }
    } else text(g, '?  ?  ?', x + 130, yy, { size: 40, weight: 600, color: C.light });
  });
  apex(1500, 820, .78, { pose: 'cheer', expr: 'happy', t: lt });
}

// ---------- scenes: (lt = seconds since the scene started, d = scene length, sp = when the voice starts) ----------
const S = {
  L01(lt, d) {
    const z = 1 + .12 * eio(lt / d); g.save(); g.translate(W / 2, H / 2); g.scale(z, z); g.translate(-W / 2, -H / 2); airfield(lt); g.restore();
    rrect(g, M - 30, 110, 760, 190, 14, C.paper, C.ink, 6);
    cap('13 MAY 1950', lt, .5, M, 200, 92); small('A FORMER RAF BOMBER BASE · ENGLAND', lt, 1.2, M, 262);
  },
  L02(lt, d) {
    sky('#CFE0E8'); crowd(g, -40, W + 40, 520, 22, .34, 4, lt); crowd(g, -40, W + 40, 600, 20, .38, 9, lt);
    poly(g, [[420, 880], [420, 600], [1260, 600], [1260, 880]], C.red, C.ink, 7);
    for (let i = 0; i < 8; i++) poly(g, [[420 + i * 105, 600], [472 + i * 105, 650], [525 + i * 105, 600]], C.white, C.ink, 4);
    fig(g, 720, 640, .55, { suit: 'suit', hat: 'crown', expr: 'smug', t: lt, mustache: true });
    fig(g, 960, 640, .55, { suit: 'royal', hat: 'crown', expr: 'happy', t: lt + 1 });
    apex(1560, 870, .62, { suit: 'tweed', hat: 'flat', pose: lt > 2 ? 'shock' : 'stand', expr: lt > 2 ? 'shock' : 'happy', t: lt, look: -1 });
    cap('THE KING & QUEEN', lt, .8, M, 170, 70); small('the only motor race in Britain a reigning monarch ever attended', lt, 2.6, M, 230);
  },
  L03(lt, d) {
    track(lt); crowd(g, -40, W + 40, 560, 26, .3, 12, lt, { cheer: true });
    for (let i = 0; i < 3; i++) {
      const x = -500 + (lt - i * .9) * (560 + i * 30);
      car(g, x, 860 - i * 50, .78 - i * .06, { era: '1950', color: C.red, spin: lt * 14, t: lt + i, driver: { hat: 'leather', expr: 'determined' } });
    }
    if (lt > d * .62) { const k = (lt - d * .62); fig(g, 1500, 860, .62, { hat: 'leather', suit: 'plain', suitColor: C.white, pose: 'wave', expr: 'grin', t: lt }); cap('GIUSEPPE FARINA', k, .2, 1100, 330, 60, { align: 'left' }); small('WINS · ALFA ROMEO', k, .6, 1100, 385); }
    else cap('70 LAPS', lt, .6, M, 200, 80);
  },
  L04(lt, d) {
    track(0, { sky: '#D9D3C6', hill: '#8FA58A' });
    car(g, 860, 860, .9, { era: '1950', color: C.red, t: 0, vib: 0, driver: { hat: 'leather', expr: 'grin' } });
    g.fillStyle = 'rgba(243,237,226,.35)'; g.fillRect(0, 0, W, H);
    stamp(g, 'RACE Nº1', 1380, 330, lt - 1.2, { size: 130 });
    cap('FORMULA ONE', lt, .4, M, 190, 80); small('WORLD CHAMPIONSHIP · BEGINS', lt, .8, M, 250);
  },
  L05(lt, d) {
    sky(C.paper); paper(g, W, H);
    const k = eo(lt / 1.2), yr = Math.round(lerp(1950, 1894, eio(seg(lt, .4, 3.4))));
    g.save(); g.translate(1260, 520); g.rotate((1 - k) * 3 - .06); g.scale(k, k);
    rrect(g, -380, -300, 760, 600, 6, C.white, C.ink, 6);
    rrect(g, -340, -260, 680, 70, 4, C.ink, null, 0, false);
    text(g, 'LE PETIT JOURNAL', 0, -208, { size: 46, weight: 800, color: C.white, align: 'center' });
    for (let i = 0; i < 9; i++) line(g, [[-340, -150 + i * 28], [-40, -150 + i * 28]], C.grey, 6);
    rrect(g, 0, -160, 340, 230, 4, C.light, C.ink, 4, false); car(g, 170, 50, .45, { era: 'horseless', color: C.red });
    for (let i = 0; i < 5; i++) line(g, [[-340, 120 + i * 28], [340, 120 + i * 28]], C.grey, 6);
    g.restore();
    text(g, String(yr), M, 420, { size: 220, weight: 800, mis: C.orange });
    small('56 YEARS EARLIER…', lt, 3.4, M, 500);
  },
  TITLE(lt, d) {
    sky(C.paper); paper(g, W, H);
    for (let x = 0; x < W; x += 60) { g.fillStyle = (x / 60) % 2 ? C.ink : C.white; g.fillRect(x, 960, 60, 30); g.fillStyle = (x / 60) % 2 ? C.white : C.ink; g.fillRect(x, 990, 60, 30); }
    text(g, 'WHY DOES F1', W / 2, 400, { size: 150, weight: 800, align: 'center', t: lt / .5, mis: C.orange });
    text(g, 'EVEN EXIST?', W / 2, 560, { size: 150, weight: 800, align: 'center', t: (lt - .35) / .5, mis: C.red });
    apex(lerp(-200, W + 200, seg(lt, 0, d)), 930, .55, { pose: 'run', prop: 'flag', expr: 'grin', t: lt });
  },
  L06(lt, d) {
    sky('#DCE6E8'); for (let i = 0; i < 7; i++) building(g, -40 + i * 290, 700, 230, 260 + (i % 3) * 70, [C.light, C.tan, C.paper][i % 3], [C.red, C.blue, C.brown][i % 3], 2);
    groundBand(700, '#CBBFA8');
    const x = lerp(-300, 1150, seg(lt, 0, d * .8));
    car(g, x, 900, .85, { era: 'horseless', color: C.red, spin: lt * 6, t: lt, vib: 4, driver: { suit: 'suit', hat: 'top', mustache: true, expr: 'smug' } });
    for (let i = 0; i < 5; i++) { const k = (lt * .8 + i * .2) % 1; circ(g, x - 120 - k * 160, 760 - k * 90, 20 + k * 30, '#CFC6B5', null, 0, false); }
    crowd(g, 1300, 1850, 880, 4, .5, 21, lt, { expr: 'happy' });
    apex(250, 900, .62, { hat: 'flat', suit: 'plain', suitColor: C.tan, prop: 'paper', pose: 'point2', expr: 'grin', t: lt });
    cap('1894', lt, .3, M, 200, 110); small('a toy for rich weirdos?', lt, 3, M, 262);
  },
  L07(lt, d) {
    sky('#A9C3D6'); const box = [380, -340, 1500, 1500, -6, 8, 43, 52.5];
    europe(g, box, { land: C.light });
    const a = proj(...CITY.Paris, box), b = proj(...CITY.Rouen, box);
    route(g, [a, [lerp(a[0], b[0], .5) - 10, lerp(a[1], b[1], .5) - 60], b], seg(lt, 1.5, 5), C.red, 10);
    pin(g, a[0], a[1], lt - .8, C.blue, 'PARIS', { dx: 22, dy: 30 }); pin(g, b[0], b[1], lt - 1.2, C.red, 'ROUEN', { align: 'right', dx: -26 });
    apex(230, 900, .6, { hat: 'flat', suit: 'plain', suitColor: C.tan, prop: 'paper', pose: 'point', expr: 'happy', t: lt });
    rrect(g, M - 30, 110, 640, 170, 14, C.paper, C.ink, 6);
    cap('PARIS → ROUEN', lt, .3, M, 190, 70); small('≈ 126 km · Le Petit Journal, 1894', lt, 1, M, 250);
  },
  L08(lt, d) {
    track(lt, { sky: '#DCE6E8' });
    line(g, [[1500, 640], [1500, 900]], C.ink, 6); line(g, [[1700, 640], [1700, 900]], C.ink, 6); line(g, [[1500, 700], [1700, 700]], C.red, 8);
    car(g, lerp(-200, 1300, eo(lt / (d * .6))), 860, .72, { era: 'steam', color: C.brown, spin: lt * 8, t: lt, driver: { hat: 'bowler', expr: 'grin' } });
    car(g, lerp(-700, 700, eo(lt / (d * .8))), 860, .66, { era: 'horseless', color: C.blue, spin: lt * 8, t: lt, driver: { hat: 'flat', expr: 'happy' } });
    for (let i = 0; i < 2; i++) fig(g, 1560 + i * 120, 900, .42, { suit: 'suit', hat: 'bowler', expr: lt > d * .55 ? 'sad' : 'neutral', look: Math.sin(lt * 9 + i) * (lt > d * .55 ? 1 : 0), t: lt + i });
    rrect(g, M - 30, 100, 680, 300, 14, C.white, C.ink, 6);
    cap('THE PRIZE WAS FOR:', lt, .4, M, 170, 50, { mis: C.red });
    ['• SAFE', '• EASY TO HANDLE', '• CHEAP TO RUN'].forEach((s, i) => small(s, lt, 1.5 + i * .9, M, 235 + i * 52, { weight: 700 }));
    if (lt > d * .62) small('fastest (steam) ≠ top prize', lt, d * .62, 900, 300, { color: C.red });
  },
  L09(lt, d) {
    sky(C.night); circ(g, 1600, 190, 80, C.paper, null, 0, false);
    const r = rng(2); for (let i = 0; i < 80; i++) circ(g, r() * W, r() * 500, 2 + r() * 2, C.paper, null, 0, false);
    hills(g, W, 650, '#1C2850', 50, .003, 1); groundBand(760, '#3A3F55');
    const x = lerp(300, 1300, lt / d);
    g.save(); g.globalAlpha = .55; poly(g, [[x + 250, 790], [x + 900, 690], [x + 900, 900]], C.mustard, null, 0, true, false); g.restore();
    car(g, x, 900, .8, { era: '1903', color: C.red, spin: lt * 10, t: lt, driver: { hat: 'leather', expr: 'sleepy' } });
    cap('PARIS–BORDEAUX–PARIS', lt, .3, M, 170, 64, { color: C.paper, mis: C.orange }); small('1895', lt, .8, M, 230, { color: C.paper });
    small('≈ 1,178 km', lt, 3, M, 300, { color: C.mustard, size: 50 }); small('≈ 2 DAYS · ALMOST NO REST', lt, 4.5, M, 360, { color: C.mustard });
  },
  L10(lt, d) {
    sky('#E7DDC8'); paper(g, W, H); groundBand(880, '#CBBFA8');
    car(g, 820, 880, .9, { era: '1903', color: C.red, mud: 1, vib: 0 });
    apex(330, 880, .7, { suit: 'suit', hat: 'bowler', pose: 'point', expr: 'grin', t: lt });
    fig(g, 1350, 880, .55, { suitColor: C.blue, hat: 'flat', expr: 'happy', t: lt, look: Math.sin(lt * 4) > .3 ? 1 : 0 });
    fig(g, 1550, 880, .5, { suitColor: C.tan, hat: 'bowler', expr: 'smug', t: lt + 1 });
    cap('A RACE = THE BEST ADVERT', lt, .5, M, 190, 70); small('survived 1,200 km → survives the trip to market', lt, 3.5, M, 250);
  },
  L11(lt) { checklist(lt, 1); },
  L12(lt, d) {
    sky('#E9DDBF'); hills(g, W, 560, '#C9B98F', 30, .004, 5); groundBand(700, C.dust);
    crowd(g, -40, W + 40, 690, 28, .3, 31, lt, { cheer: true });
    const x = lerp(-400, 2300, (lt % 5) / 5);
    car(g, x, 860, .8, { era: '1903', color: C.blue, spin: lt * 16, t: lt, dust: 1, driver: { hat: 'leather', expr: 'determined' }, mech: { hat: 'flat', expr: 'shock' } });
    tree(g, 1620, 900, 1.1, C.green); apex(1700, 905, .55, { pose: 'duck', expr: 'shock', t: lt });
    cap('OPEN PUBLIC ROADS', lt, .5, M, 180, 70); small('dust · villages · crowds at the edge', lt, 2.5, M, 240);
  },
  L13(lt, d) {
    sky('#DCE6E8'); groundBand(700, '#CBBFA8');
    line(g, [[100, 420], [1820, 420]], C.ink, 4); for (let i = 0; i < 20; i++) poly(g, [[100 + i * 86, 420], [143 + i * 86, 470], [186 + i * 86, 420]], [C.red, C.blue, C.mustard][i % 3], C.ink, 3);
    const cols = [C.blue, C.red, C.white, C.green, C.mustard, C.blue];
    for (let i = 5; i >= 0; i--) car(g, 1450 - i * 260 + Math.max(0, lt - 3 - i * .2) * 90, 760 + i * 30, .5, { era: '1903', color: cols[i], spin: lt * 6, t: lt + i, driver: { hat: 'leather' } });
    cap('PARIS → MADRID', lt, .4, M, 190, 76); small('1903 · MORE THAN 200 CARS', lt, 1.2, M, 250);
  },
  L14(lt, d) {
    sky('#2C2F3A'); hills(g, W, 650, '#22252E', 30, .004, 7); groundBand(740, '#4A4A52');
    line(g, [[1300, 900], [1300, 520]], '#111', 26); circ(g, 1300, 460, 160, '#1E2127', null, 0, false);
    g.save(); g.translate(1050, 880); g.rotate(-.5); circ(g, 0, 0, 90, null, '#BBB', 12, false); for (let i = 0; i < 8; i++) line(g, [[0, 0], [Math.cos(i) * 80, Math.sin(i) * 80]], '#BBB', 4); g.restore();
    for (let i = 0; i < 6; i++) { const k = (lt * .25 + i / 6) % 1; g.globalAlpha = (1 - k) * .5; circ(g, 1150 - k * 80, 780 - k * 420, 40 + k * 90, '#777', null, 0, false); } g.globalAlpha = 1;
    circ(g, 760, 905, 20, C.mustard, '#BBB', 5, false); circ(g, 810, 905, 20, C.mustard, '#BBB', 5, false);
    cap('"THE RACE OF DEATH"', lt, .6, M, 190, 76, { color: C.paper, mis: C.red });
    small('crash after crash on the first day', lt, 2, M, 250, { color: '#C8C2B6' });
    small('among the dead: Marcel Renault, co-founder of Renault', lt, 5, M, 300, { color: '#C8C2B6' });
  },
  L15(lt, d) {
    sky('#DCE6E8'); groundBand(760, '#CBBFA8');
    poly(g, [[1250, 760], [1250, 280], [1750, 280], [1750, 760], [1620, 760], [1620, 520], [1380, 520], [1380, 760]], C.light, C.ink, 7);
    text(g, 'BORDEAUX', 1500, 360, { size: 48, weight: 800, align: 'center', t: 1 });
    for (let i = 0; i < 4; i++) car(g, 950 - i * 280, 900, .5, { era: '1903', color: [C.blue, C.red, C.green, C.white][i], t: lt, vib: 0, driver: { hat: 'leather', expr: 'sad' } });
    fig(g, 1180, 905, .6, { suit: 'uniform', hat: 'kepi', pose: 'stop', expr: 'determined', dir: -1, t: lt, mustache: true });
    stamp(g, 'STOPPED', 640, 330, lt - 1, { size: 100 });
    small('the cars were towed to the station by horses', lt, 4.5, M, 520);
  },
  L16(lt, d) {
    sky('#A9C3D6'); const box = [600, 40, 1160, 900, -10, 9, 39.5, 49.5];
    europe(g, box, { land: C.light });
    const P = n => proj(...CITY[n], box);
    const kOld = 1 - seg(lt, d * .5, d * .65);
    g.globalAlpha = kOld; route(g, [P('Paris'), P('Bordeaux'), P('Madrid')], seg(lt, .3, 3), C.red, 10); g.globalAlpha = 1;
    if (lt > d * .5) {
      const c = P('Le Mans'), k = eo((lt - d * .55) / 1.5);
      g.beginPath(); g.ellipse(c[0], c[1], 70 * k, 45 * k, -.3, 0, 7); g.strokeStyle = C.orange; g.lineWidth = 14; g.stroke();
      cap('CLOSED CIRCUITS', lt, d * .55 + .4, M, 200, 70, { mis: C.orange });
    } else { cap('CITY-TO-CITY', lt, .4, M, 200, 70, { mis: C.red }); stamp(g, '✕', 1300, 640, lt - 3.5, { size: 140, box: false, rot: 0 }); }
  },
  L17(lt) { checklist(lt, 2); },
  L18(lt, d) {
    sky(C.paper); paper(g, W, H); groundBand(860, C.light);
    g.save(); g.translate(1000, 620); g.scale(2.2, 2.2); poly(g, [[-50, -120], [50, -120], [36, -50], [10, -30], [10, 0], [34, 14], [-34, 14], [-10, 0], [-10, -30], [-36, -50]], C.mustard, C.ink, 4); g.restore();
    const teams = [[C.blue, 'FRANCE'], [C.white, 'GERMANY'], [C.red, 'ITALY'], [C.green, 'BRITAIN'], ['#7FA6C9', 'USA']];
    teams.forEach(([col, n], i) => {
      const x = 300 + i * 340 + (i > 1 ? 120 : 0) - (i > 2 ? 0 : 0), y = 860, k = lt - .6 - i * .5;
      if (k < 0) return; fig(g, x, y, .42 * pop(k * 1.3), { suitColor: col, expr: 'happy', pose: 'hold', t: lt + i });
      rrect(g, x + 10, y - 290, 90, 60, 4, col, C.ink, 4); line(g, [[x + 10, y - 230], [x + 10, y - 150]], C.ink, 5);
      text(g, n, x, y + 60, { size: 28, weight: 700, align: 'center', t: k * 2 });
    });
    cap('GORDON BENNETT CUP', lt, .3, M, 180, 70); small('1900–1905 · countries, not just car makers', lt, 1, M, 240);
  },
  L19(lt, d) {
    sky(C.paper); paper(g, W, H);
    [[C.blue, 'FRANCE', 'BLUE'], [C.white, 'GERMANY', 'WHITE'], [C.red, 'ITALY', 'RED']].forEach(([col, n, cn], i) => {
      const at = 1.8 + i * 1.5, k = eo((lt - at) / 1.1), y = 420 + i * 250;
      line(g, [[0, y + 4], [W, y + 4]], C.light, 6);
      car(g, lerp(-400, 1250, k), y, .52, { era: '1903', color: col, spin: lt * 12, t: lt, driver: { hat: 'leather' } });
      text(g, n, 1550, y - 60, { size: 44, weight: 800, t: (lt - at - .6) * 2 }); text(g, cn, 1550, y - 14, { size: 30, weight: 500, color: C.grey, t: (lt - at - .8) * 2 });
    });
    cap('ONE COLOUR PER COUNTRY', lt, .3, M, 170, 64);
  },
  L20(lt, d) {
    sky('#CFE0E8'); hills(g, W, 560, '#3E7A4E', 50, .003, 3); hills(g, W, 680, C.green, 40, .005, 9); groundBand(780, C.dust);
    // shamrock cloud
    g.save(); g.translate(1350, 240); const sk = pop(seg(lt, d * .55, d * .65) * 1.6); g.scale(sk, sk);
    for (const [dx, dy] of [[-50, 0], [50, 0], [0, -70]]) circ(g, dx, dy, 62, '#4C9A5F', C.ink, 6); line(g, [[0, 40], [20, 140]], C.ink, 10); g.restore();
    car(g, lerp(-300, 900, eo(lt / (d * .7))), 900, .7, { era: '1903', color: C.green, spin: lt * 10, t: lt, driver: { hat: 'leather', expr: 'happy' } });
    apex(1620, 905, .6, { prop: 'pot', pose: 'hold', expr: lt > d * .7 ? 'grin' : 'think', t: lt });
    cap('1903 · IRELAND', lt, .5, M, 170, 64); small('Red, white and blue were already taken', lt, 1.8, M, 230);
    if (lt > d * .78) cap('BRITISH RACING GREEN', lt, d * .78, M, 320, 72, { color: C.green, mis: C.mustard });
  },
  L21(lt, d) {
    sky(C.paper); paper(g, W, H); groundBand(800, C.light);
    car(g, 520, 800, .7, { era: '1906', color: C.red, vib: 0 }); car(g, 1380, 800, .68, { era: 'modern', color: C.red, vib: 0, t: lt });
    text(g, '1906', 520, 900, { size: 44, weight: 800, align: 'center', t: lt }); text(g, 'TODAY', 1380, 900, { size: 44, weight: 800, align: 'center', t: lt - .5 });
    cap('ITALY = RED', lt, 1, M, 200, 90, { color: C.red, mis: C.mustard }); small('Ferrari still races in Italy’s old national colour', lt, 2.5, M, 262);
  },
  L22(lt, d) {
    sky('#F0DDB0'); sun(g, 1550, 260, 150); hills(g, W, 600, '#9DB56B', 50, .003, 4); hills(g, W, 720, '#6E9550', 40, .005, 11); groundBand(820, C.dust);
    cap('GRAND PRIX', lt, .4, M, 250, 140, { mis: C.blue });
    if (lt > d * .7) small('= French for "BIG PRIZE"', lt, d * .7, M, 330, { size: 50, weight: 700, color: C.red });
    small('1906 · LE MANS · AUTOMOBILE CLUB DE FRANCE', lt, 1.4, M, 400);
    apex(1600, 900, .58, { hat: 'leather', suit: 'coat', expr: 'happy', pose: 'wave', t: lt });
  },
  L23(lt, d) {
    sky(C.paper); paper(g, W, H);
    const loop = [[700, 820], [1500, 840], [1650, 700], [1300, 260], [1150, 250], [700, 700], [700, 820]];
    poly(g, loop, null, C.light, 40, true, false); route(g, loop, seg(lt, .4, 3.4), C.orange, 14);
    for (const [x, y, n] of [[700, 820, 'Saint-Calais'], [1650, 700, 'Vibraye'], [1300, 260, 'Le Mans']]) { circ(g, x, y, 14, C.ink, null, 0, false); text(g, n, x + 26, y - 18, { size: 28, weight: 600, t: lt - 1 }); }
    const laps = Math.min(12, Math.floor(seg(lt, 3.6, d - 1) * 12) + (lt > 3.6 ? 1 : 0));
    cap('≈ 103 km PER LAP', lt, 1, M, 200, 60);
    small('2 DAYS', lt, 3.4, M, 300, { size: 50, weight: 700 }); small(`LAP ${laps || 1} / 12`, lt, 3.6, M, 370, { size: 50, weight: 700, color: C.orange });
    small('≈ 1,238 km in total', lt, 6, M, 440, { size: 40, weight: 600 });
  },
  L24(lt, d) {
    sky('#F0DDB0'); g.save(); g.translate(-(lt * 120) % 800, 0); hills(g, W + 800, 620, '#9DB56B', 40, .004, 2); g.restore(); groundBand(760, C.dust);
    car(g, 900, 920, .95, { era: '1906', color: C.blue, spin: lt * 18, t: lt, dust: 1, driver: { hat: 'leather', mustache: true, expr: 'determined' }, mech: { apex: true, hat: 'leather', expr: lt > d * .55 ? 'shock' : 'grin' } });
    cap('FERENC SZISZ', lt, .5, M, 180, 70); small('Hungarian mechanic · driving for Renault', lt, 1.2, M, 240);
    if (lt > d * .5) cap('≈ 101 km/h', lt, d * .5, 1300, 260, 90, { mis: C.red }); if (lt > d * .72) small('ON DIRT ROADS. IN 1906.', lt, d * .72, 1300, 330, { weight: 700 });
  },
  L25(lt, d) {
    sky(C.paper); paper(g, W, H); groundBand(860, C.light);
    const tilt = eio(seg(lt, 2, 5)) * 1.2;
    g.save(); g.translate(900, 860); g.rotate(tilt * .9);
    for (let i = 0; i < 7; i++) { g.save(); g.translate(Math.sin(i * 2.3) * 20, -40 - i * 66); g.rotate(tilt * (i % 2 ? .15 : -.1)); rrect(g, -150, -30, 300, 60, 6, [C.red, C.blue, C.green, C.mustard, C.tan, C.orange, C.light][i], C.ink, 5); g.restore(); }
    g.restore();
    apex(1500, 860, .62, { pose: 'shrug', expr: 'sad', t: lt });
    cap('EVERY RACE, ITS OWN RULES', lt, .5, M, 190, 64); if (lt > d * .55) small('… and no single champion', lt, d * .55, M, 250, { size: 44 });
  },
  L26(lt, d) {
    sky('#9FB3D6'); g.fillStyle = tint(g, C.blue, .25); g.fillRect(0, 0, W, 520);
    poly(g, [[200, 700], [200, 420], [1720, 420], [1720, 700]], C.light, C.ink, 7); poly(g, [[160, 420], [1760, 420], [1660, 340], [260, 340]], C.blue, C.ink, 7);
    crowd(g, 220, 1700, 640, 24, .3, 41, lt); for (let i = 0; i < 8; i++) { line(g, [[260 + i * 200, 340], [260 + i * 200, 230]], C.ink, 5); rrect(g, 260 + i * 200, 230, 70, 44, 3, [C.red, C.white, C.mustard, C.blue][i % 4], C.ink, 4); }
    groundBand(760, '#8F8A80');
    rrect(g, M - 30, 80, 820, 180, 14, C.paper, C.ink, 6); cap('1930s', lt, .4, M, 170, 90, { mis: C.blue }); small('EUROPEAN CHAMPIONSHIP · and politics', lt, 1.4, M, 230);
  },
  L27(lt, d) {
    track(lt, { sky: '#9FB3D6' });
    car(g, lerp(-600, 2400, seg((lt + 4.5) % 6, 0, 3)), 820, .7, { era: 'arrow', color: C.silver, spin: lt * 20, t: lt, driver: { hat: 'helmet', expr: 'determined' } });
    car(g, lerp(-600, 2400, seg((lt + 3.8) % 6, 0, 3)), 870, .72, { era: 'arrow', color: '#D4D7DC', spin: lt * 20, t: lt, driver: { hat: 'helmet' } });
    car(g, lerp(200, 900, seg(lt, 0, d)), 900, .66, { era: 'arrow', color: C.red, spin: lt * 10, t: lt, driver: { hat: 'leather', expr: lt > 2.4 ? 'shock' : 'neutral' } });
    for (let i = 0; i < 10; i++) line(g, [[(i * 230 + lt * 900) % 2200 - 100, 700 + (i % 4) * 40], [(i * 230 + lt * 900) % 2200 - 260, 700 + (i % 4) * 40]], C.white, 5);
    cap('SILVER ARROWS', lt, d * .62, M, 200, 90, { color: C.ink, mis: C.silver }); small('state-funded Mercedes-Benz & Auto Union', lt, 1, M, 260);
  },
  L28(lt, d) {
    sky(C.paper); paper(g, W, H); groundBand(860, C.light);
    car(g, 760, 860, .9, { era: 'arrow', color: C.silver, vib: 0 });
    fig(g, 380, 870, .58, { suit: 'plain', suitColor: C.blue, prop: 'sander', pose: 'hold', expr: 'determined', t: lt });
    const r = rng(6); for (let i = 0; i < 14; i++) { const k = (lt * .6 + r()) % 1; poly(g, [[600 + r() * 300, 650 + k * 200], [618 + r() * 300, 650 + k * 200], [612 + r() * 300, 664 + k * 200]], C.white, C.ink, 2); }
    apex(1650, 870, .6, { hat: 'deerstalker', prop: 'magnifier', pose: 'hold', expr: lt > d * .45 ? 'smug' : 'think', t: lt });
    cap('PAINT SCRAPED OFF?', lt, .4, M, 190, 72); stamp(g, 'MYTH?', 1220, 330, lt - d * .5, { size: 120 });
    if (lt > d * .65) small('the weight limit didn’t even apply at that race', lt, d * .65, M, 250, { weight: 600 });
  },
  L29(lt, d) {
    sky('#BDB8AE'); groundBand(760, '#8F8A80');
    const r = rng(8); for (let i = 0; i < 90; i++) { const x = r() * W, h = 20 + r() * 50; line(g, [[x, 760 + r() * 160], [x + 6, 760 + r() * 160 - h]], '#5D6B4E', 4); }
    line(g, [[600, 900], [600, 560]], C.ink, 12); line(g, [[1320, 900], [1320, 560]], C.ink, 12);
    curve(g, [600, 640], [960, 760 + Math.sin(lt) * 6], [1320, 640], '#555', 10);
    rrect(g, 860, 660, 200, 90, 6, C.paper, C.ink, 5); text(g, 'CLOSED', 960, 720, { size: 40, weight: 800, align: 'center', color: C.red, t: 1 });
    cap('1939–1945', lt, .5, M, 200, 100, { color: C.ink, mis: C.grey });
  },
  L30(lt, d) {
    sky('#6B4A2E'); for (let i = 0; i < 14; i++) line(g, [[i * 150, 0], [i * 150, 860]], '#5A3D25', 8);
    groundBand(860, '#C9A85E'); for (let i = 0; i < 6; i++) poly(g, [[100 + i * 330, 860], [180 + i * 330, 700], [300 + i * 330, 860]], C.mustard, C.ink, 4);
    car(g, 960, 880, .85, { era: '1950', color: C.red, vib: 0 });
    for (let i = 0; i < 6; i++) rrect(g, 640 + i * 70, 640 + (i % 2) * 40, 300, 34, 16, C.tan, C.ink, 5);
    const px = lerp(1650, 1380, eo(seg(lt, 1, 4)));
    poly(g, [[px - 110, 900], [px - 120, 820], [px - 60, 780], [px + 80, 790], [px + 110, 840], [px + 100, 900]], '#E9A9A0', C.ink, 6);
    circ(g, px - 128, 846, 22, '#E9A9A0', C.ink, 5); circ(g, px - 70, 815, 6, C.ink, null, 0, false);
    apex(330, 900, .6, { pose: 'hush', expr: 'smug', t: lt, hat: 'flat' });
    cap('ALFA ROMEO 158', lt, .5, M, 180, 70, { color: C.paper, mis: C.red }); small('hidden near Milan: cheese factory? pig farm?', lt, d * .45, M, 240, { color: C.paper });
  },
  L31(lt, d) {
    sky('#6B4A2E'); g.save(); g.translate(-500, 300); g.scale(2.6, 2.6); car(g, 600, 300, 1, { era: '1950', color: C.red, vib: 0 }); g.restore();
    const k = Math.max(0, Math.sin(seg(lt, .6, 1.6) * Math.PI));
    g.save(); g.translate(1290, 345); g.rotate(lt); g.globalAlpha = k;
    for (let i = 0; i < 4; i++) { g.rotate(Math.PI / 4); poly(g, [[0, -120], [18, 0], [0, 120], [-18, 0]], C.white, null, 0, true, false); } g.restore();
  },
  L32(lt, d) {
    sky('#D6CBB4'); rrect(g, 1260, 120, 500, 300, 8, C.light, C.ink, 6); for (let i = 0; i < 3; i++) line(g, [[1300, 200 + i * 70], [1720, 200 + i * 70]], C.grey, 6);
    for (let i = 0; i < 4; i++) fig(g, 520 + i * 300, 880, .62, { suit: 'suit', hat: i % 2 ? 'bowler' : null, mustache: i % 2 === 0, expr: 'think', t: lt + i, look: Math.sin(lt + i) });
    poly(g, [[300, 900], [300, 790], [1620, 790], [1620, 900]], C.brown, C.ink, 7);
    g.save(); g.translate(960, 770); const k = pop(seg(lt, 1, 2.5) * 1.6); g.scale(k, k);
    rrect(g, -160, -110, 320, 120, 8, C.red, C.ink, 6); text(g, 'THE FORMULA', 0, -32, { size: 40, weight: 800, align: 'center', color: C.paper }); g.restore();
    cap('1946 · ONE RULEBOOK', lt, .5, M, 190, 68); small('the FIA’s sporting commission, Paris', lt, 1.4, M, 250);
  },
  L33(lt, d) {
    sky(C.paper); paper(g, W, H);
    rrect(g, 220, 170, 900, 700, 16, C.white, C.ink, 7);
    text(g, 'FORMULA = THE RULES', 270, 260, { size: 60, weight: 800, mis: C.orange, t: lt / .5 });
    ['ENGINE SIZE', 'WEIGHT', 'DESIGN'].forEach((s, i) => {
      const y = 400 + i * 150, k = lt - 2.5 - i * .7; if (k < 0) return;
      rrect(g, 280, y - 70, 110, 100, 10, [C.mustard, C.blue, C.red][i], C.ink, 5); text(g, s, 430, y, { size: 50, weight: 700, t: k * 2 });
    });
    ['F1', 'F2', 'F3'].forEach((s, i) => { const k = lt - d * .6 - i * .4; if (k < 0) return; rrect(g, 1300, 260 + i * 200, 380, 150, 12, i ? C.light : C.orange, C.ink, 6); text(g, s, 1490, 360 + i * 200, { size: 90, weight: 800, align: 'center', t: k * 2 }); });
    if (lt > d * .6) small('top tier first, lower formulas later', lt, d * .6, 1300, 900, { size: 30 });
  },
  L34(lt, d) {
    sky(C.paper); paper(g, W, H); const tilt = Math.sin(lt * 1.6) * .04 * (1 - seg(lt, 3, 6));
    poly(g, [[900, 880], [1020, 880], [960, 560]], C.tan, C.ink, 6);
    g.save(); g.translate(960, 560); g.rotate(tilt);
    line(g, [[-560, 0], [560, 0]], C.ink, 14);
    for (const [sx, big] of [[-480, 1], [480, 0]]) {
      line(g, [[sx - 120, 0], [sx - 120, 160]], C.ink, 4); line(g, [[sx + 120, 0], [sx + 120, 160]], C.ink, 4);
      poly(g, [[sx - 170, 160], [sx + 170, 160], [sx + 120, 200], [sx - 120, 200]], C.light, C.ink, 6);
      if (big) rrect(g, sx - 120, -20 + 20, 240, 140, 10, C.grey, C.ink, 6), rrect(g, sx - 100, 30, 60, 30, 4, C.ink, null, 0, false);
      else { rrect(g, sx - 90, 60, 150, 100, 10, C.grey, C.ink, 6); circ(g, sx + 90, 100, 44, C.mustard, C.ink, 6); for (let i = 0; i < 6; i++) line(g, [[sx + 90, 100], [sx + 90 + Math.cos(lt * 6 + i) * 40, 100 + Math.sin(lt * 6 + i) * 40]], C.ink, 4); }
    }
    g.restore();
    text(g, '4.5 L', 480, 360, { size: 80, weight: 800, align: 'center', t: (lt - 1) * 2, mis: C.orange });
    text(g, '1.5 L + SUPERCHARGER', 1440, 360, { size: 52, weight: 800, align: 'center', t: (lt - 3) * 2, mis: C.orange });
    cap('THE FIRST FORMULA', lt, .3, M, 170, 60);
  },
  L35(lt, d) {
    sky(C.paper); paper(g, W, H); groundBand(880, C.light);
    const k = seg(lt, 0, d * .45);
    g.save(); g.translate(lerp(-300, 300, eo(k)), 0); car(g, 0, 880, 1.25, { era: 'arrow', color: C.ink, spin: lt * 4, t: lt, driver: { hat: 'top', expr: 'smug' } }); g.restore();
    if (lt > d * .35) { g.save(); g.translate(800, 880); const s = pop(seg(lt, d * .35, d * .5) * 1.6); g.scale(s, s); for (let i = 0; i < 5; i++) rrect(g, -60, -80 - i * 80, 120, 76, 6, [C.red, C.blue, C.mustard, C.green, C.orange][i], C.ink, 5); text(g, 'RULES', 0, -450, { size: 44, weight: 800, align: 'center', t: 1 }); g.restore(); }
    if (lt > d * .55) { car(g, 1350, 880, .55, { era: '1950', color: C.red, t: lt, driver: { hat: 'leather' } }); car(g, 1700, 880, .55, { era: '1950', color: C.green, t: lt + 1, driver: { hat: 'leather' } }); }
    cap(lt < d * .55 ? 'NO RULES → THE RICHEST WINS' : 'ONE FORMULA → A FAIR FIGHT', lt, lt < d * .55 ? .4 : d * .55, M, 190, 64);
  },
  L36(lt) { checklist(lt, 3); },
  L37(lt, d) {
    sky(C.paper); paper(g, W, H); groundBand(880, C.light);
    apex(960, 880, .9, { prop: 'emptytrophy', pose: 'hold', expr: 'think', look: Math.sin(lt * 1.5), t: lt });
    cap('ONE THING MISSING…', lt, .5, M, 200, 72); if (lt > 1.8) small('a single champion', lt, 1.8, M, 260, { size: 44, color: C.orange, weight: 700 });
  },
  L38(lt, d) {
    track(lt, { sky: '#DCE6E8' });
    car(g, lerp(-300, 2200, seg(lt, .4, 3.6)), 860, .62, { era: 'bike', color: C.blue, spin: lt * 16, t: lt, driver: { hat: 'leather', prop: 'trophy', pose: 'hold', expr: 'grin' } });
    car(g, 1150, 860, .72, { era: '1950', color: C.red, vib: 0, t: lt, driver: { hat: 'leather', expr: lt > 2 ? 'sad' : 'neutral', look: -1 } });
    cap('1949', lt, .3, M, 190, 100); small('MOTORCYCLE WORLD CHAMPIONSHIP', lt, 1, M, 250, { weight: 700 });
  },
  L39(lt, d) {
    sky('#A9C3D6'); const box = [500, 0, 1220, 990, -4, 16, 42.5, 53.5];
    europe(g, box, { land: C.light });
    const names = ['Silverstone', 'Monaco', 'Bern', 'Spa', 'Reims', 'Monza'];
    const pts = names.map(n => proj(...CITY[n], box));
    route(g, pts, seg(lt, d * .35, d * .8), C.orange, 10);
    pts.forEach((p, i) => pin(g, p[0], p[1], lt - 1 - i * .4, C.red));
    fig(g, 260, 900, .6, { suit: 'suit', mustache: true, pose: 'point', expr: 'smug', t: lt });
    rrect(g, M - 30, 110, 760, 170, 14, C.paper, C.ink, 6);
    cap('ONE SEASON. ONE CHAMPION.', lt, .5, M, 190, 60); small('1950 · the idea of Count Antonio Brivio', lt, 1.4, M, 250);
  },
  L40(lt, d) {
    sky('#A9C3D6'); const box = [200, 0, 1220, 990, -4, 16, 42.5, 53.5];
    europe(g, box, { land: C.light });
    const races = [['Silverstone', 'BRITAIN'], ['Monaco', 'MONACO'], [null, 'INDIANAPOLIS 500 (USA)'], ['Bern', 'SWITZERLAND'], ['Spa', 'BELGIUM'], ['Reims', 'FRANCE'], ['Monza', 'ITALY']];
    rrect(g, 1340, 150, 520, 760, 14, C.paper, C.ink, 6); text(g, '1950 · 7 RACES', 1380, 220, { size: 42, weight: 800, t: lt * 2 });
    races.forEach(([c, n], i) => {
      const k = lt - .6 - i * .6; if (c) { const p = proj(...CITY[c], box); pin(g, p[0], p[1], k, C.red); }
      text(g, `${i + 1}. ${n}`, 1380, 300 + i * 82, { size: 32, weight: c ? 600 : 800, color: c ? C.ink : C.blue, t: k * 2 });
    });
    if (lt > 4.2) { rrect(g, 120, 760, 360, 110, 12, C.blue, C.ink, 5); text(g, '← USA', 160, 832, { size: 48, weight: 800, color: C.paper, t: (lt - 4.2) * 2 }); }
  },
  L41(lt, d) { S.L01(lt + 6, d + 6); rrect(g, M - 30, 330, 760, 110, 14, C.orange, C.ink, 6); text(g, 'SILVERSTONE · RACE 1', M, 405, { size: 54, weight: 800, t: (lt - .5) * 2 }); },
  L42(lt, d) {
    const sw = d * .42;
    if (lt < sw) {
      sky('#6B4A2E'); groundBand(860, '#C9A85E');
      const k = eo(seg(lt, .6, 1.6));
      poly(g, [[560 - k * 380, 260], [960 - k * 380, 260], [960 - k * 380, 860], [560 - k * 380, 860]], C.brown, C.ink, 8);
      poly(g, [[960 + k * 380, 260], [1360 + k * 380, 260], [1360 + k * 380, 860], [960 + k * 380, 860]], C.brown, C.ink, 8);
      car(g, 960 + Math.max(0, lt - 1.4) * 900, 900, .8, { era: '1950', color: C.red, spin: lt * 16, t: lt, dust: seg(lt, 1.4, 2), driver: { hat: 'leather', expr: 'determined' } });
    } else {
      track(lt); crowd(g, -40, W + 40, 560, 26, .3, 12, lt, { cheer: true });
      car(g, lerp(-300, 1300, eo((lt - sw) / 2.5)), 860, .8, { era: '1950', color: C.red, spin: lt * 16, t: lt, driver: { hat: 'leather', expr: 'grin' } });
      line(g, [[1500, 640], [1500, 880]], C.ink, 10);
    }
    cap('THE SAME ALFA ROMEO 158', lt, .4, M, 190, 64, { color: lt < sw ? C.paper : C.ink });
  },
  L43(lt, d) {
    sky('#CFE0E8'); crowd(g, -40, W + 40, 600, 24, .32, 51, lt, { cheer: true });
    groundBand(860, C.light);
    for (const [x, h, col] of [[960, 260, C.mustard], [700, 170, C.silver], [1220, 120, C.tan]]) poly(g, [[x - 120, 860], [x - 120, 860 - h], [x + 120, 860 - h], [x + 120, 860]], col, C.ink, 6);
    fig(g, 960, 600, .55, { hat: 'leather', suitColor: C.white, prop: 'trophy', pose: 'cheer', expr: 'grin', t: lt });
    apex(1600, 900, .55, { pose: 'cheer', expr: 'happy', t: lt + .5, suit: 'tweed', hat: 'flat' });
    const r = rng(9); for (let i = 0; i < 70; i++) { const k = (lt * .35 + r()) % 1; g.fillStyle = [C.red, C.orange, C.mustard, C.blue][i % 4]; g.fillRect(r() * W, k * 900, 14, 22); }
    cap('GIUSEPPE FARINA', lt, .5, M, 180, 70); small('1950 · FIRST FORMULA ONE WORLD CHAMPION', lt, d * .45, M, 240, { weight: 700, color: C.orange });
  },
  L44(lt) { checklist(lt, 4, true); },
  L45(lt, d) {
    sky('#E4E1DA'); const cols = [C.red, C.orange, '#2E8B8B', C.silver, C.blue];
    for (let i = 0; i < 5; i++) { poly(g, [[60 + i * 380, 640], [60 + i * 380, 300], [400 + i * 380, 300], [400 + i * 380, 640]], C.light, C.ink, 6); rrect(g, 60 + i * 380, 300, 340, 50, 0, cols[i], C.ink, 5, false); }
    groundBand(640, '#9A9690'); for (let x = 0; x < W; x += 60) g.fillRect(x, 760, 30, 6);
    car(g, 420, 880, .62, { era: 'modern', color: C.red, vib: 0, t: lt, driver: { hat: 'helmet' } });
    car(g, 1300, 920, .62, { era: 'modern', color: C.orange, vib: 0, t: lt, driver: { hat: 'helmet', hatColor: C.mustard } });
    apex(lerp(1900, 900, seg(lt, 0, d)), 940, .55, { suit: 'pit', hat: 'headset', pose: 'walk', expr: 'happy', t: lt });
    cap('76 YEARS LATER', lt, .4, M, 180, 76); small('same four reasons', lt, 1.6, M, 240, { weight: 700, color: C.orange });
  },
  L46(lt, d) {
    sky('#E4E1DA'); groundBand(640, '#9A9690');
    apex(960, 940, .8, { suit: 'pit', hat: 'headset', prop: 'paper', pose: 'hold', expr: 'grin', t: lt });
    text(g, '1894', 1180, 500, { size: 60, weight: 800, t: lt * 2, mis: C.orange });
  },
  L47(lt, d) {
    sky(C.paper); paper(g, W, H);
    small('NEXT EPISODE', lt, .3, M, 260, { size: 40, weight: 700, color: C.orange });
    text(g, 'FROM DANGEROUS HOBBY', M, 360, { size: 76, weight: 800, t: (lt - .6) * 2, mis: C.orange });
    text(g, 'TO BILLION-DOLLAR MACHINE', M, 450, { size: 76, weight: 800, t: (lt - .9) * 2, mis: C.orange });
    rrect(g, M, 560, 470, 110, 55, C.red, C.ink, 6); poly(g, [[M + 60, 585], [M + 60, 645], [M + 110, 615]], C.white, null, 0, true, false);
    text(g, 'SUBSCRIBE', M + 140, 632, { size: 44, weight: 800, color: C.white, t: (lt - 1.4) * 2 });
    apex(1460, 900, .9, { pose: 'wave', expr: 'happy', t: lt });
  },
};

// ---------- sound / cue events (seconds after the scene starts) ----------
const CUES = {
  L01: [[.5, 'type']], L03: [[0, 'engine'], [4, 'cheer']], L04: [[1.2, 'stamp']], L05: [[.2, 'paper'], [3.4, 'tick']],
  TITLE: [[0, 'title']], L06: [[0, 'chug']], L07: [[1.5, 'draw']], L09: [[0, 'night']], L11: [[1, 'ding']], L12: [[0, 'engine'], [1, 'cheer']],
  L14: [[0, 'low']], L15: [[1, 'stamp']], L16: [[3.5, 'stamp']], L17: [[1, 'ding']], L19: [[1.8, 'pass'], [3.3, 'pass'], [4.8, 'pass']], L24: [[0, 'engine']],
  L27: [[1.5, 'pass'], [2.2, 'pass'], [7.5, 'pass'], [8.2, 'pass'], [13.5, 'pass']], L28: [['h', 'stamp']], L29: [[0, 'low']], L31: [[.8, 'glint']], L32: [[1.2, 'thump']], L36: [[1, 'ding']],
  L38: [[.4, 'pass']], L42: [[.8, 'doors'], [1.4, 'engine']], L43: [[0, 'cheer']], L44: [[1, 'ding'], [2.6, 'ding'], [4.2, 'ding'], [5.8, 'ding']], L47: [[0, 'title']],
};

// ---------- timeline plumbing ----------
const SCENES = [];
T.lines.forEach(x => { SCENES.push({ id: x.id, s0: x.s0, s1: x.s1, ln: x }); if (T.title && x.id === 'L05') SCENES.push({ id: 'TITLE', s0: T.title.t0, s1: T.title.t1 }); });
const sceneAt = t => SCENES.find(s => t >= s.s0 && t < s.s1) || SCENES[SCENES.length - 1];
const chapterAt = t => [...T.chapters].reverse().find(c => t >= c.t0) || T.chapters[0];
const cues = T.lines.flatMap(x => x.chunks);

window.DUR = T.dur;
window.EV = SCENES.flatMap(s => [{ t: +s.s0.toFixed(3), type: 'cut', id: s.id },
  ...(CUES[s.id] || []).map(([dt, type]) => ({ t: +(s.s0 + (dt === 'h' ? (s.s1 - s.s0) * .5 : dt)).toFixed(3), type, id: s.id }))]);

function hud(t, sc) {
  if (sc.id === 'TITLE' || sc.id === 'L47') return;
  const ch = chapterAt(t); if (!ch || ch.ch === 1 && t < 7) return;
  text(g, ch.name.toUpperCase(), W - 70, 70, { size: 24, weight: 600, color: C.grey, align: 'right', track: 3 });
}
function subtitles(t) {
  const c = cues.find(c => t >= c.t0 && t < c.t1); if (!c) return;
  g.font = '500 40px Jost'; const w = g.measureText(c.text).width;
  g.globalAlpha = .93; rrect(g, M - 24, 962, w + 52, 66, 10, C.white, null, 0, false); g.globalAlpha = 1;
  g.fillStyle = C.orange; g.fillRect(M - 24, 962, 7, 66);
  g.fillStyle = C.ink; g.textAlign = 'left'; g.textBaseline = 'alphabetic'; g.fillText(c.text, M + 4, 1008);
}

window.render = t => {
  const sc = sceneAt(t), lt = t - sc.s0, d = sc.s1 - sc.s0;
  g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.clearRect(0, 0, W, H);
  g.save(); S[sc.id](lt, d); g.restore();
  hud(t, sc); subtitles(t);
};
window.TEXTS = () => [];
window.render(0);
window.READY = true;
