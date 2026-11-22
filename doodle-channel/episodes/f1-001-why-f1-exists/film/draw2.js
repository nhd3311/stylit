// v2 drawing kit: period-accurate cars, atmosphere, parallax camera. Builds on draw.js.
import { C, MIS, clamp, lerp, seg, eo, eio, rng, poly, circ, line, curve, rrect, tint, fig } from './draw.js';
export const W = 1920, H = 1080;

// ---------- camera & parallax ----------
// cam = {x, y, z}: the world point at screen centre and the zoom of the main layer (depth 1).
export function layer(g, cam, k, fn) {
  const z = 1 + (cam.z - 1) * k;
  g.save(); g.translate(W / 2, H / 2); g.scale(z, z); g.translate(-W / 2 - (cam.x - W / 2) * k, -H / 2 - (cam.y - H / 2) * k);
  fn(); g.restore();
}
export const camAt = (a, b, p) => ({ x: lerp(a[0], b[0], p), y: lerp(a[1], b[1], p), z: lerp(a[2], b[2], p) });

// ---------- sky & atmosphere ----------
export function skyBands(g, top, bottom, y0 = 0, y1 = 700) {
  g.fillStyle = bottom; g.fillRect(-W, -H, W * 3, H * 3);
  const steps = [.85, .6, .38, .2];
  steps.forEach((d, i) => { g.fillStyle = tint(g, top, d, 9); g.fillRect(-W, y0 - H + i * 0, W * 3, H + (y1 - y0) * (1 - i / steps.length) * .9); });
}
export function cloud(g, x, y, s, col = C.paper) {
  g.save(); g.translate(x, y); g.scale(s, s);
  g.save(); g.translate(MIS[0], MIS[1]); g.fillStyle = col;
  for (const [cx, cy, r] of [[-70, 10, 46], [-20, -14, 62], [44, 0, 52], [92, 16, 36], [0, 24, 50]]) { g.beginPath(); g.arc(cx, cy, r, 0, 7); g.fill(); }
  g.fillRect(-116, 16, 244, 44); g.restore(); g.restore();
}
export function clouds(g, t, seed, n = 5, y = 200, col = C.paper, speed = 8) {
  const r = rng(seed); for (let i = 0; i < n; i++) { const x = ((r() * 2400 + t * speed * (0.6 + r())) % 2600) - 340; cloud(g, x, y + r() * 180, .6 + r() * .7, col); }
}
export function shadow(g, x, y, w, a = .18) { g.save(); g.globalAlpha = a; g.beginPath(); g.ellipse(x, y, w, w * .12, 0, 0, 7); g.fillStyle = C.ink; g.fill(); g.restore(); }
export function vignette(g) {
  const gr = g.createRadialGradient(W / 2, H / 2, H * .45, W / 2, H / 2, H * .95); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(30,20,10,.28)');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
}
export function poplar(g, x, y, s, col = '#3E6B3A') {
  line(g, [[x, y], [x, y - 60 * s]], C.ink, 7 * s);
  poly(g, [[x, y - 40 * s], [x - 34 * s, y - 140 * s], [x - 26 * s, y - 260 * s], [x, y - 330 * s], [x + 26 * s, y - 260 * s], [x + 34 * s, y - 140 * s]], col, C.ink, 5 * s);
  g.save(); g.globalAlpha = .5; poly(g, [[x + 4 * s, y - 60 * s], [x + 30 * s, y - 150 * s], [x + 20 * s, y - 250 * s], [x + 4 * s, y - 300 * s]], tint(g, C.ink, .3, 7), null, 0, true, false); g.restore();
}
export function pole(g, x, y, s) { line(g, [[x, y], [x, y - 300 * s]], C.brown, 8 * s); line(g, [[x - 40 * s, y - 280 * s], [x + 40 * s, y - 280 * s]], C.brown, 7 * s); }
export function wires(g, xs, y, s) { for (let i = 1; i < xs.length; i++) curve(g, [xs[i - 1] - 30 * s, y - 280 * s], [(xs[i - 1] + xs[i]) / 2, y - 250 * s], [xs[i] - 30 * s, y - 280 * s], C.ink, 2); }
export function fence(g, x0, x1, y, col = C.paper) {
  for (let x = x0; x < x1; x += 60) { line(g, [[x, y], [x, y - 60]], C.ink, 5); }
  line(g, [[x0, y - 46], [x1, y - 46]], C.ink, 5); line(g, [[x0, y - 20], [x1, y - 20]], C.ink, 5);
}
export function bales(g, x0, x1, y, s = 1) { for (let x = x0; x < x1; x += 120 * s) rrect(g, x, y - 60 * s, 110 * s, 60 * s, 8 * s, C.mustard, C.ink, 4); }
export function drums(g, x0, x1, y, s = 1) { for (let x = x0; x < x1; x += 140 * s) { rrect(g, x, y - 80 * s, 60 * s, 80 * s, 6 * s, C.red, C.ink, 4); line(g, [[x, y - 54 * s], [x + 60 * s, y - 54 * s]], C.ink, 3); line(g, [[x, y - 26 * s], [x + 60 * s, y - 26 * s]], C.ink, 3); } }
export function tufts(g, x0, x1, y0, y1, seed, col = '#3E6B3A') { const r = rng(seed); for (let i = 0; i < 70; i++) { const x = lerp(x0, x1, r()), y = lerp(y0, y1, r()); line(g, [[x, y], [x - 6, y - 14]], col, 3); line(g, [[x, y], [x + 5, y - 16]], col, 3); } }
export function speedLines(g, t, y0, y1, n = 14, col = C.white, dir = 1) {
  const r = rng(4); for (let i = 0; i < n; i++) { const y = lerp(y0, y1, r()), L = 120 + r() * 260, x = ((r() * 3000 - t * 2400 * dir) % 2600 + 2600) % 2600 - 300; g.globalAlpha = .7; line(g, [[x, y], [x + L, y]], col, 4); } g.globalAlpha = 1;
}
export function wellington(g, x, y, s, t = 0) {
  g.save(); g.translate(x, y); g.scale(s, s);
  shadow(g, 0, 150, 420, .15);
  poly(g, [[-460, -10], [-380, -40], [300, -50], [420, -30], [440, 0], [300, 20], [-380, 20]], '#6F7A5E', C.ink, 7);   // fuselage
  poly(g, [[-100, -10], [-40, -240], [60, -240], [80, -10]], '#5E6A4F', C.ink, 6); poly(g, [[-100, 0], [-40, 230], [60, 230], [80, 0]], '#5E6A4F', C.ink, 6); // wings (top view-ish)
  poly(g, [[-430, -20], [-470, -120], [-420, -120], [-380, -30]], '#5E6A4F', C.ink, 6);                                // tail fin
  for (const wy of [-140, 140]) { rrect(g, -40, wy - 22, 120, 44, 18, '#4C5640', C.ink, 5); const a = t * 30; line(g, [[90, wy + Math.cos(a) * 60], [90, wy - Math.cos(a) * 60]], C.ink, 6); }
  circ(g, 380, -24, 22, '#B9D3E0', C.ink, 5, false); circ(g, 0, -100, 26, C.blue, C.white, 6, false); circ(g, 0, -100, 10, C.red, null, 0, false);
  g.restore();
}

// ---------- wheels ----------
function wheelV2(g, x, y, r, o) {
  const { spokes = 12, wood = false, tyre = .16, spin = 0, speed = 0, disc = false, knock = false, modern = false } = o;
  const tr = r * tyre;
  circ(g, x, y, r, C.ink, null, 0, false);
  circ(g, x, y, r - tr, modern ? '#55575C' : wood ? '#C8A26B' : C.paper, null, 0, false);
  if (disc || modern) { circ(g, x, y, (r - tr) * .62, modern ? C.ink : C.silver, C.ink, 3, false); }
  else for (let i = 0; i < spokes; i++) {
    const a = spin + i * Math.PI * 2 / spokes;
    line(g, [[x + Math.cos(a) * r * .12, y + Math.sin(a) * r * .12], [x + Math.cos(a) * (r - tr), y + Math.sin(a) * (r - tr)]], wood ? C.brown : C.ink, wood ? r * .08 : Math.max(1.5, r * .025));
  }
  circ(g, x, y, r * .12, wood ? C.brown : C.ink, null, 0, false);
  if (knock) { g.save(); g.translate(x, y); g.rotate(spin); poly(g, [[-r * .2, 0], [0, -r * .06], [r * .2, 0], [0, r * .06]], C.mustard, C.ink, 3); g.restore(); }
  if (speed > .5) { g.globalAlpha = .35; for (let k = 0; k < 3; k++) { g.beginPath(); g.arc(x, y, r - tr * .5, spin + k * 2, spin + k * 2 + .9); g.strokeStyle = C.paper; g.lineWidth = 3; g.stroke(); } g.globalAlpha = 1; }
  // tyre highlight
  g.beginPath(); g.arc(x, y, r - tr * .4, -2.6, -1.9); g.strokeStyle = 'rgba(255,255,255,.35)'; g.lineWidth = 3; g.stroke();
}

// ---------- period cars, side view, facing right; (x,y) = ground under the car's middle ----------
// Each model = { seats, body, wheels }: drawn in that order, so drivers sit inside and wheels stay in front.
const MODELS = {
  peugeot1894: {
    seats: (S) => S.d(-90, -150, .32),
    body: (g, c, D) => {
      poly(g, [[-200, -170], [160, -170], [170, -120], [-210, -120]], c, C.ink, 7);
      poly(g, [[-210, -170], [-210, -250], [-150, -250], [-150, -170]], c, C.ink, 7); poly(g, [[100, -170], [100, -230], [160, -230], [160, -170]], c, C.ink, 7);
      poly(g, [[-200, -255], [180, -255], [170, -270], [-190, -270]], C.ink, C.ink, 5); line(g, [[-195, -255], [-195, -170]], C.ink, 4); line(g, [[165, -255], [165, -170]], C.ink, 4);
      line(g, [[40, -170], [-40, -215]], C.ink, 6);
    },
    wheels: (Wh) => { Wh(-120, 92, { spokes: 14 }); Wh(110, 74, { spokes: 12 }); },
  },
  dedion: {
    seats: (S) => { S.d(-120, -196, .32); S.m(-40, -196, .32); },
    body: (g, c, D, t) => {
      poly(g, [[-560, -150], [-330, -150], [-320, -100], [-570, -100]], C.brown, C.ink, 6); poly(g, [[-540, -150], [-540, -230], [-360, -230], [-360, -150]], C.brown, C.ink, 6);
      line(g, [[-320, -110], [-240, -110]], C.ink, 8);
      rrect(g, -240, -230, 360, 120, 14, c, C.ink, 7); rrect(g, 0, -330, 110, 100, 10, C.ink, C.ink, 6); line(g, [[60, -330], [60, -420]], C.ink, 26);
      for (let i = 0; i < 4; i++) { const k = (t * .7 + i * .25) % 1; circ(g, 60 - k * 140, -440 - k * 160, 22 + k * 40, '#CFC6B5', null, 0, false); }
    },
    wheels: (Wh) => { Wh(-520, 60, { spokes: 10 }); Wh(-360, 60, { spokes: 10 }); Wh(-170, 80, { spokes: 12 }); Wh(80, 80, { spokes: 12 }); },
  },
  panhard1895: {
    seats: (S) => S.d(-110, -146, .34),
    body: (g, c) => {
      poly(g, [[-230, -150], [-40, -150], [-40, -200], [40, -200], [60, -150], [200, -150], [210, -100], [-240, -100]], c, C.ink, 7);
      rrect(g, 110, -196, 90, 46, 6, C.ink, C.ink, 4); line(g, [[50, -150], [-10, -214]], C.ink, 6);
    },
    wheels: (Wh) => { Wh(-140, 84, { spokes: 12, wood: true }); Wh(130, 70, { spokes: 12, wood: true }); },
  },
  renault1903: {
    seats: (S) => { S.d(-200, -136, .34); S.m(-120, -136, .34); },
    body: (g, c, D) => renaultBody(g, c, D, false),
    wheels: (Wh) => { Wh(-190, 90, { spokes: 12, wood: true }); Wh(180, 90, { spokes: 12, wood: true }); },
  },
  renault1906: {
    seats: (S) => { S.d(-200, -136, .34); S.m(-120, -136, .34); },
    body: (g, c, D) => renaultBody(g, c, D, true),
    wheels: (Wh) => { Wh(-190, 98, { spokes: 12, wood: true }); Wh(180, 98, { spokes: 12, wood: true }); },
  },
  mercedesW25: {
    seats: (S) => S.d(-20, -112, .3),
    body: (g, c) => {
      poly(g, [[-320, -70], [-300, -126], [-150, -150], [-90, -150], [-60, -176], [-10, -150], [230, -140], [320, -114], [338, -84], [300, -60], [-310, -60]], c, C.ink, 7);
      poly(g, [[-140, -150], [-112, -192], [-84, -192], [-64, -156]], c, C.ink, 5);
      for (let i = 0; i < 5; i++) line(g, [[322, -114 + i * 10], [334, -110 + i * 10]], C.ink, 3);
      line(g, [[-280, -96], [300, -100]], 'rgba(255,255,255,.75)', 6);
    },
    wheels: (Wh) => { Wh(-200, 74, { spokes: 16, knock: true, tyre: .2 }); Wh(212, 74, { spokes: 16, knock: true, tyre: .2 }); },
  },
  autounion: {
    seats: (S) => S.d(70, -118, .3),
    body: (g, c) => {
      poly(g, [[-360, -72], [-300, -136], [-60, -160], [60, -166], [200, -142], [330, -98], [350, -72], [300, -58], [-330, -58]], c, C.ink, 7);
      for (let i = 0; i < 5; i++) line(g, [[-280 + i * 34, -134], [-270 + i * 34, -98]], C.ink, 3);
      line(g, [[-300, -92], [320, -92]], 'rgba(255,255,255,.75)', 6);
    },
    wheels: (Wh) => { Wh(-210, 72, { spokes: 16, knock: true, tyre: .2 }); Wh(205, 72, { spokes: 16, knock: true, tyre: .2 }); },
  },
  alfaP3: {
    seats: (S) => S.d(-70, -118, .3),
    body: (g, c) => {
      poly(g, [[-300, -80], [-290, -132], [-120, -142], [-84, -168], [-36, -144], [220, -138], [290, -118], [300, -80], [-290, -70]], c, C.ink, 7);
      poly(g, [[290, -132], [320, -118], [320, -82], [290, -76]], C.ink, C.ink, 4);
    },
    wheels: (Wh) => { Wh(-190, 76, { spokes: 16, knock: true }); Wh(190, 76, { spokes: 16, knock: true }); },
  },
  alfa158: {
    seats: (S) => S.d(-46, -110, .3),
    body: (g, c, D, t, o) => {
      poly(g, [[-300, -80], [-280, -126], [-150, -142], [-70, -144], [-40, -170], [10, -148], [230, -138], [300, -116], [316, -86], [290, -64], [-280, -64]], c, C.ink, 7);
      poly(g, [[296, -118], [324, -110], [324, -72], [296, -66]], C.ink, C.ink, 4); for (let i = 0; i < 4; i++) line(g, [[302 + i * 6, -112], [302 + i * 6, -72]], C.silver, 2);
      poly(g, [[-60, -146], [-30, -176], [0, -148]], '#B9D3E0', C.ink, 4);
      g.fillStyle = D; g.fillRect(-280, -82, 590, 14);
      line(g, [[-270, -110], [280, -114]], 'rgba(255,255,255,.55)', 5);
      if (o.num) circ(g, 70, -104, 26, C.white, C.ink, 4, false);
    },
    wheels: (Wh) => { Wh(-180, 72, { spokes: 18, knock: true }); Wh(200, 72, { spokes: 18, knock: true }); },
  },
  modern: {
    seats: (S) => S.d(-20, -100, .28),
    body: (g, c, D) => {
      poly(g, [[-400, -70], [-395, -190], [-330, -190], [-320, -120], [-120, -120], [-60, -150], [20, -140], [120, -110], [300, -90], [420, -70], [420, -46], [-400, -46]], c, C.ink, 7);
      poly(g, [[300, -70], [440, -70], [450, -40], [300, -40]], C.ink, C.ink, 5); poly(g, [[-410, -200], [-310, -200], [-310, -180], [-410, -180]], C.ink, C.ink, 5);
      curve(g, [-90, -150], [-20, -230], [70, -140], C.ink, 12);
      g.fillStyle = D; g.fillRect(-380, -70, 780, 16);
    },
    wheels: (Wh) => { Wh(-250, 70, { modern: true, tyre: .36 }); Wh(250, 66, { modern: true, tyre: .36 }); },
  },
  bike: {
    seats: (S) => S.d(-20, -126, .36),
    body: (g, c) => { poly(g, [[-140, -130], [120, -150], [160, -110], [-130, -100]], c, C.ink, 7); rrect(g, -40, -130, 90, 50, 10, C.silver, C.ink, 4); },
    wheels: (Wh) => { Wh(-150, 72, { spokes: 14 }); Wh(150, 72, { spokes: 14 }); },
  },
};
function renaultBody(g, c, D, big) {
  poly(g, [[-300, -150], [-80, -150], [-80, -110], [-300, -110]], c, C.ink, 7);
  poly(g, [[-80, -110], [-80, -170], [120, -200], [270, -150], [280, -110]], c, C.ink, 7);
  poly(g, [[-70, -165], [-10, -175], [-10, -115], [-70, -115]], C.silver, C.ink, 5);
  for (let i = 0; i < 4; i++) line(g, [[-64 + i * 14, -168], [-64 + i * 14, -118]], C.ink, 2);
  g.fillStyle = D; g.fillRect(-300, -125, 580, 15);
  if (big) { circ(g, -330, -150, 54, null, C.ink, 12, false); circ(g, -330, -150, 40, null, C.grey, 6, false); }
}
export function car2(g, x, y, s, o = {}) {
  const { model = 'alfa158', color = C.red, dir = 1, spin = 0, speed = 0, driver = null, mech = null, t = 0, mud = 0 } = o;
  const M = MODELS[model];
  g.save(); g.translate(x, y); g.scale(s * dir, s);
  shadow(g, 0, 0, model === 'modern' ? 380 : model === 'dedion' ? 480 : 300, .22);
  g.translate(0, speed > 0 ? Math.sin(t * 47) * 1.5 : 0);
  const D = tint(g, C.ink, .35, 8);
  M.seats({ d: (sx, sy, sc) => driver && fig(g, sx, sy, sc, { pose: 'drive', ...driver, t }), m: (sx, sy, sc) => mech && fig(g, sx, sy, sc, { pose: 'drive', ...mech, t: t + .7 }) });
  M.body(g, color, D, t, o);
  M.wheels((wx, r, opt = {}) => wheelV2(g, wx, -r, r, { spin, speed, ...opt }));
  if (mud) { const r = rng(5); for (let i = 0; i < 30; i++) circ(g, -250 + r() * 520, -60 - r() * 140, 5 + r() * 12, C.brown, null, 0, false); }
  g.restore();
}

export function dust(g, x, y, k, t, col = C.dust, spread = 520) {
  const r = rng(11);
  for (let i = 0; i < 12; i++) {
    const ph = (t * .9 + r()) % 1, cx = x - ph * spread - r() * 60, cy = y - r() * 90 - ph * 50, rad = (40 + r() * 60) * (0.6 + ph);
    g.globalAlpha = k * (1 - ph) * .8; circ(g, cx, cy, rad, col, null, 0, false);
  }
  g.globalAlpha = 1;
}
