// Drawing kit for the Apex motorsport channel: risograph-editorial look in Canvas 2D.
// Everything is a pure function of its arguments (and t), so any frame renders alone.

export const C = {
  ink: '#1A1A1A', paper: '#F3EDE2', white: '#FFFFFF', orange: '#F26B21', red: '#E8452C',
  blue: '#2B4BA8', green: '#1F5C3A', mustard: '#E8B530', grey: '#9C978C', light: '#E2DBCD',
  silver: '#B9BDC4', brown: '#7A4A26', tan: '#B88A5A', night: '#22305E', grass: '#5E8C4F', dust: '#D9C7A3',
};
export const MIS = [4, 3];   // fixed misregistration of the colour plate vs the ink plate

// ---------- maths ----------
export const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
export const lerp = (a, b, t) => a + (b - a) * t;
export const seg = (t, a, b) => clamp((t - a) / (b - a));
export const eo = t => 1 - Math.pow(1 - clamp(t), 3);
export const eio = t => { t = clamp(t); return t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
export const pop = t => t <= 0 ? 0 : t >= 1.6 ? 1 : 1 - Math.exp(-6 * t) * Math.cos(9 * t);   // springy 0→1 with overshoot
export function rng(seed) { let a = seed >>> 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

// ---------- primitives ----------
export function poly(ctx, pts, fill, stroke = C.ink, lw = 6, close = true, mis = true) {
  if (fill) {
    ctx.save(); if (mis) ctx.translate(MIS[0], MIS[1]);
    ctx.beginPath(); pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); if (close) ctx.closePath();
    ctx.fillStyle = fill; ctx.fill(); ctx.restore();
  }
  if (stroke) {
    ctx.beginPath(); pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); if (close) ctx.closePath();
    ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.lineJoin = ctx.lineCap = 'round'; ctx.stroke();
  }
}
export function circ(ctx, x, y, r, fill, stroke = C.ink, lw = 6, mis = true) {
  if (fill) { ctx.beginPath(); ctx.arc(x + (mis ? MIS[0] : 0), y + (mis ? MIS[1] : 0), r, 0, 7); ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.stroke(); }
}
export function line(ctx, pts, color = C.ink, lw = 6) {
  ctx.beginPath(); pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
  ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.lineJoin = ctx.lineCap = 'round'; ctx.stroke();
}
export function curve(ctx, a, c, b, color = C.ink, lw = 6) {
  ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.quadraticCurveTo(c[0], c[1], b[0], b[1]);
  ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.lineCap = 'round'; ctx.stroke();
}
export function rrect(ctx, x, y, w, h, r, fill, stroke = C.ink, lw = 5, mis = true) {
  const p = () => { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); };
  if (fill) { ctx.save(); if (mis) ctx.translate(MIS[0], MIS[1]); p(); ctx.fillStyle = fill; ctx.fill(); ctx.restore(); }
  if (stroke) { p(); ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.stroke(); }
}

// halftone dot pattern in one ink (a "tint" of a plate)
const patCache = {};
export function tint(ctx, color, density = .35, period = 9) {
  const k = color + density + period; if (patCache[k]) return patCache[k];
  const c = document.createElement('canvas'); c.width = c.height = period * 2; const g = c.getContext('2d');
  g.fillStyle = color; const r = Math.sqrt(density) * period * .62;
  for (const [x, y] of [[period / 2, period / 2], [period * 1.5, period * 1.5]]) { g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); }
  return (patCache[k] = ctx.createPattern(c, 'repeat'));
}

// static paper: flat warm paper with fine fibres, made once
let paperCanvas = null;
export function paper(ctx, W, H, color = C.paper) {
  if (!paperCanvas || paperCanvas.col !== color) {
    paperCanvas = document.createElement('canvas'); paperCanvas.width = W; paperCanvas.height = H; paperCanvas.col = color;
    const g = paperCanvas.getContext('2d'); g.fillStyle = color; g.fillRect(0, 0, W, H);
    const r = rng(7); g.globalAlpha = .05;
    for (let i = 0; i < 1400; i++) { g.fillStyle = r() < .5 ? '#000' : '#fff'; const x = r() * W, y = r() * H; g.fillRect(x, y, 1 + r() * 9, 1); }
  }
  ctx.drawImage(paperCanvas, 0, 0);
}

// ---------- text ----------
export function text(ctx, s, x, y, o = {}) {
  const { size = 48, weight = 700, color = C.ink, align = 'left', font = 'Jost', t = 1, track = 0, base = 'alphabetic', alpha = 1 } = o;
  const k = eo(t); if (k <= 0) return;
  ctx.save(); ctx.globalAlpha = alpha * k; ctx.font = `${weight} ${size}px ${font}`; ctx.textAlign = align; ctx.textBaseline = base;
  if (track) ctx.letterSpacing = track + 'px';
  if (o.mis) { ctx.fillStyle = o.mis; ctx.fillText(s, x + MIS[0] + 1, y + (1 - k) * 18 + MIS[1] + 1); }
  ctx.fillStyle = color; ctx.fillText(s, x, y + (1 - k) * 18); ctx.restore();
}
export function stamp(ctx, s, x, y, t, o = {}) {
  const { size = 120, color = C.red, rot = -.12, box = true } = o; const k = pop(t * 1.4); if (t <= 0) return;
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(1 + (1 - k) * .8, 1 + (1 - k) * .8); ctx.globalAlpha = clamp(t * 4);
  ctx.font = `800 ${size}px Jost`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  const w = ctx.measureText(s).width + size * .6;
  if (box) { ctx.strokeStyle = color; ctx.lineWidth = size * .07; ctx.strokeRect(-w / 2, -size * .72, w, size * 1.44); }
  ctx.fillStyle = color; ctx.fillText(s, 0, 4); ctx.restore();
}

// ---------- figures ----------
// (x, y) = between the feet; s = scale (1 → ~410 px tall). o: see defaults.
export function fig(ctx, x, y, s, o = {}) {
  const { apex = false, pose = 'stand', expr = 'neutral', dir = 1, t = 0, suit = apex ? 'race' : 'plain', suitColor = null,
    hat = null, hatColor = null, prop = null, gloves = apex ? C.orange : C.ink, head = C.white, mustache = false, beard = false, look = 0, lw = 7 } = o;
  ctx.save(); ctx.translate(x, y); ctx.scale(s * dir, s);
  const ph = t * 6.3, breathe = Math.sin(t * 2.4) * 3;
  // pose → hands (relative to shoulders) and legs
  const shL = [-36, -186], shR = [36, -186];
  let hL = [-70, -100], hR = [70, -100], fL = [-30, -6], fR = [30, -6], hip = -120, bob = breathe, lean = 0;
  const sw = Math.sin(ph);
  switch (pose) {
    case 'point': hR = [150, -235]; hL = [-72, -104]; break;
    case 'point2': hR = [160, -150]; break;
    case 'cheer': hL = [-150, -330 + Math.sin(ph) * 14]; hR = [150, -330 - Math.sin(ph) * 14]; bob = -Math.abs(Math.sin(ph)) * 18; break;
    case 'shock': hL = [-130, -150]; hR = [130, -150]; bob = -6; break;
    case 'walk': hL = [-40 - sw * 40, -100]; hR = [40 + sw * 40, -100]; fL = [-20 + sw * 40, -6 + Math.max(0, -sw) * -12]; fR = [20 - sw * 40, -6 + Math.max(0, sw) * -12]; bob = Math.abs(Math.cos(ph)) * -8; break;
    case 'run': { const r = Math.sin(ph * 1.6); hL = [-60 - r * 70, -150]; hR = [60 + r * 70, -150]; fL = [-10 + r * 70, -6 - Math.max(0, -r) * 30]; fR = [10 - r * 70, -6 - Math.max(0, r) * 30]; lean = .12; bob = -Math.abs(Math.cos(ph * 1.6)) * 14; break; }
    case 'wave': hR = [175, -330 + Math.sin(ph * 1.4) * 30]; break;
    case 'hold': hL = [-30, -150]; hR = [60, -150]; break;
    case 'shrug': hL = [-110, -200]; hR = [110, -200]; break;
    case 'hush': hR = [14, -238]; break;
    case 'think': hR = [30, -228]; hL = [-60, -110]; break;
    case 'duck': hL = [-150, -250]; hR = [150, -250]; bob = 50; break;
    case 'sit': fL = [-80, -60]; fR = [-40, -60]; hip = -70; bob = 50; break;
    case 'drive': hL = [70, -150]; hR = [90, -150]; break;
    case 'stop': hR = [150, -300]; break;
  }
  ctx.translate(0, bob); ctx.rotate(lean);
  // legs
  if (pose !== 'drive') {
    curve(ctx, [-14, hip], [(-14 + fL[0]) / 2 - 6, (hip + fL[1]) / 2], fL, C.ink, lw * 1.3);
    curve(ctx, [14, hip], [(14 + fR[0]) / 2 + 6, (hip + fR[1]) / 2], fR, C.ink, lw * 1.3);
    for (const f of [fL, fR]) { ctx.beginPath(); ctx.ellipse(f[0] + 6, f[1] + 4, 21, 10, 0, 0, 7); ctx.fillStyle = C.ink; ctx.fill(); }
  }
  // arms behind? draw after torso for front
  const torso = suit === 'coat'
    ? [[-50, -204], [-66, -120], [-64, -40], [64, -40], [66, -120], [50, -204], [0, -220]]
    : [[-42, -198], [-50, -150], [-34, -112], [34, -112], [50, -150], [42, -198], [0, -214]];
  const sc = suitColor || ({ race: C.paper, plain: C.light, coat: C.tan, tweed: C.tan, suit: C.ink, pit: C.orange, uniform: C.blue, robe: C.brown, royal: C.red, lab: C.white }[suit] || C.light);
  poly(ctx, torso, sc, C.ink, lw);
  if (suit === 'race') poly(ctx, [[-8, -210], [8, -210], [8, -114], [-8, -114]], C.orange, null);
  if (suit === 'pit') poly(ctx, [[-44, -150], [44, -150], [40, -138], [-40, -138]], C.ink, null, 0, true, false);
  if (suit === 'tweed' || suit === 'suit') { line(ctx, [[-10, -210], [0, -170], [10, -210]], suit === 'suit' ? C.white : C.ink, 4); }
  if (suit === 'coat') line(ctx, [[0, -214], [0, -44]], C.ink, 4);
  if (suit === 'royal') { poly(ctx, [[-42, -198], [42, -198], [38, -186], [-38, -186]], C.mustard, null, 0, true, false); }
  const front = pose === 'hush' || pose === 'think';
  const arms = () => {
  for (const [sh, h] of [[shL, hL], [shR, hR]]) {
    const ctl = [(sh[0] + h[0]) / 2 + (h[0] > sh[0] ? 10 : -10), (sh[1] + h[1]) / 2 + 22];
    curve(ctx, sh, ctl, h, C.ink, lw * 1.25);
  }
  // props in the right hand
  if (prop) drawProp(ctx, prop, hR, t);
  for (const h of [hL, hR]) {
    if (gloves === C.ink) circ(ctx, h[0], h[1], 11, C.ink, null, 0, false);
    else circ(ctx, h[0], h[1], 17, gloves, C.ink, 5, false);
  }
  };
  if (!front) arms();
  // head
  const hy = -300, R = 105;
  circ(ctx, look * 4, hy, R, head, C.ink, lw, false);
  ctx.save(); ctx.translate(look * 10, 0); face(ctx, expr, hy, t, lw); ctx.restore();
  if (mustache) curve(ctx, [-30, hy + 46], [0, hy + 30], [30, hy + 46], C.ink, 9);
  if (beard) poly(ctx, [[-70, hy + 40], [-40, hy + 100], [0, hy + 112], [40, hy + 100], [70, hy + 40], [40, hy + 70], [-40, hy + 70]], C.ink, null, 0, true, false);
  if (hat) drawHat(ctx, hat, hy, R, hatColor, lw);
  if (apex && hat !== 'helmet') goggles(ctx, hy - 50);
  if (front) arms();
  ctx.restore();
}

function face(ctx, expr, hy, t, lw) {
  const blink = (Math.floor(t * 10) % 37 === 0) ? .15 : 1;
  const eye = (x, y, r = 10) => { ctx.beginPath(); ctx.ellipse(x, y, r, r * blink, 0, 0, 7); ctx.fillStyle = C.ink; ctx.fill(); };
  const brow = (a, b) => line(ctx, [a, b], C.ink, lw);
  switch (expr) {
    case 'shock': eye(-34, hy + 16, 6); eye(34, hy + 16, 6); brow([-56, hy - 18], [-22, hy - 12]); brow([22, hy - 12], [56, hy - 18]);
      ctx.beginPath(); ctx.ellipse(0, hy + 60, 13, 17, 0, 0, 7); ctx.fillStyle = C.ink; ctx.fill(); break;
    case 'happy': eye(-34, hy + 20); eye(34, hy + 20); brow([-52, hy - 10], [-22, hy - 14]); brow([22, hy - 14], [52, hy - 10]);
      poly(ctx, [[-24, hy + 50], [0, hy + 74], [24, hy + 50]], C.ink, null, 0, true, false); break;
    case 'grin': curve(ctx, [-48, hy + 18], [-34, hy + 4], [-20, hy + 18], C.ink, lw); curve(ctx, [20, hy + 18], [34, hy + 4], [48, hy + 18], C.ink, lw);
      poly(ctx, [[-30, hy + 46], [0, hy + 76], [30, hy + 46]], C.ink, null, 0, true, false); break;
    case 'sad': eye(-34, hy + 22); eye(34, hy + 22); brow([-54, hy - 2], [-22, hy - 12]); brow([22, hy - 12], [54, hy - 2]);
      curve(ctx, [-18, hy + 62], [0, hy + 50], [18, hy + 62], C.ink, lw); break;
    case 'smug': line(ctx, [[-46, hy + 20], [-22, hy + 20]], C.ink, lw); line(ctx, [[22, hy + 20], [46, hy + 20]], C.ink, lw);
      curve(ctx, [-18, hy + 54], [4, hy + 66], [22, hy + 50], C.ink, lw); break;
    case 'think': eye(-30, hy + 20); eye(38, hy + 20); brow([-52, hy - 6], [-22, hy - 6]); brow([22, hy - 18], [54, hy - 10]);
      line(ctx, [[-10, hy + 58], [16, hy + 56]], C.ink, lw); break;
    case 'sleepy': line(ctx, [[-46, hy + 22], [-22, hy + 22]], C.ink, lw); line(ctx, [[22, hy + 22], [46, hy + 22]], C.ink, lw);
      circ(ctx, 0, hy + 58, 8, C.ink, null, 0, false); break;
    case 'determined': eye(-34, hy + 20); eye(34, hy + 20); brow([-54, hy - 14], [-22, hy - 2]); brow([22, hy - 2], [54, hy - 14]);
      line(ctx, [[-16, hy + 56], [16, hy + 56]], C.ink, lw); break;
    default: eye(-34, hy + 20); eye(34, hy + 20); brow([-52, hy - 8], [-22, hy - 12]); brow([22, hy - 12], [52, hy - 8]);
      curve(ctx, [-16, hy + 54], [0, hy + 64], [16, hy + 54], C.ink, lw);
  }
}

function goggles(ctx, y) {
  curve(ctx, [-104, y + 8], [0, y - 8], [104, y + 8], C.brown, 12);
  for (const gx of [-30, 30]) { circ(ctx, gx, y, 26, C.mustard, C.ink, 7, false); circ(ctx, gx - 4, y - 4, 12, '#F7EFD8', null, 0, false); }
  line(ctx, [[-4, y], [4, y]], C.ink, 7);
}

function drawHat(ctx, hat, hy, R, col, lw) {
  const top = hy - R;
  switch (hat) {
    case 'flat': poly(ctx, [[-98, top + 50], [-70, top + 4], [40, top - 2], [96, top + 34], [140, top + 50], [96, top + 58], [-98, top + 58]], col || C.tan, C.ink, lw); break;
    case 'leather': poly(ctx, [[-100, top + 70], [-92, top + 14], [0, top - 8], [92, top + 14], [100, top + 70], [0, top + 40]], col || C.brown, C.ink, lw);
      line(ctx, [[-96, top + 70], [-80, hy + 40]], C.brown, 10); line(ctx, [[96, top + 70], [80, hy + 40]], C.brown, 10); break;
    case 'crown': poly(ctx, [[-60, top + 20], [-70, top - 50], [-30, top - 14], [0, top - 64], [30, top - 14], [70, top - 50], [60, top + 20]], col || C.mustard, C.ink, lw); break;
    case 'bowler': poly(ctx, [[-120, top + 40], [-70, top + 36], [-66, top - 30], [0, top - 52], [66, top - 30], [70, top + 36], [120, top + 40], [0, top + 48]], col || C.ink, C.ink, lw); break;
    case 'top': poly(ctx, [[-120, top + 36], [-62, top + 34], [-62, top - 90], [62, top - 90], [62, top + 34], [120, top + 36], [0, top + 46]], col || C.ink, C.ink, lw); break;
    case 'kepi': poly(ctx, [[-70, top + 30], [-64, top - 40], [64, top - 40], [70, top + 30]], col || C.blue, C.ink, lw); poly(ctx, [[0, top + 30], [110, top + 42], [70, top + 30]], C.ink, C.ink, lw); break;
    case 'helmet': poly(ctx, [[-110, hy + 20], [-104, hy - 50], [-60, top + 6], [0, top - 6], [60, top + 6], [104, hy - 50], [110, hy + 20], [70, hy + 4], [-70, hy + 4]], col || C.white, C.ink, lw);
      rrect(ctx, -76, hy - 10, 152, 34, 14, C.ink, C.ink, 4, false); break;
    case 'headset': curve(ctx, [-104, hy - 10], [0, top - 40], [104, hy - 10], C.ink, 10); circ(ctx, -104, hy, 22, C.orange, C.ink, 6, false); circ(ctx, 104, hy, 22, C.orange, C.ink, 6, false); break;
    case 'deerstalker': poly(ctx, [[-96, top + 46], [-80, top - 10], [0, top - 30], [80, top - 10], [96, top + 46], [0, top + 30]], col || C.tan, C.ink, lw); break;
    case 'toque': poly(ctx, [[-70, top + 24], [-90, top - 50], [-30, top - 70], [30, top - 70], [90, top - 50], [70, top + 24]], C.white, C.ink, lw); break;
  }
}

function drawProp(ctx, prop, h, t) {
  const [x, y] = h;
  switch (prop) {
    case 'paper': poly(ctx, [[x - 30, y - 70], [x + 60, y - 80], [x + 66, y + 30], [x - 24, y + 40]], C.white, C.ink, 5);
      for (let i = 0; i < 4; i++) line(ctx, [[x - 14, y - 48 + i * 20], [x + 46, y - 54 + i * 20]], C.grey, 4); break;
    case 'flag': line(ctx, [[x, y + 40], [x, y - 190]], C.ink, 7);
      for (let r = 0; r < 3; r++) for (let c = 0; c < 4; c++) { const w = Math.sin(t * 8 + c * .9) * 8; ctx.fillStyle = (r + c) % 2 ? C.white : C.ink; ctx.fillRect(x + c * 28, y - 190 + r * 26 + w, 28, 26); }
      ctx.strokeStyle = C.ink; ctx.lineWidth = 4; ctx.strokeRect(x, y - 190 + Math.sin(t * 8) * 8, 112, 78); break;
    case 'magnifier': line(ctx, [[x, y], [x + 40, y - 40]], C.brown, 12); circ(ctx, x + 70, y - 70, 42, '#DDE8EE', C.ink, 7, false); break;
    case 'pot': poly(ctx, [[x - 40, y], [x + 40, y], [x + 34, y + 70], [x - 34, y + 70]], C.green, C.ink, 6); curve(ctx, [x - 40, y], [x, y - 50], [x + 40, y], C.ink, 5); break;
    case 'trophy': poly(ctx, [[x - 50, y - 120], [x + 50, y - 120], [x + 36, y - 50], [x + 10, y - 30], [x + 10, y], [x + 34, y + 14], [x - 34, y + 14], [x - 10, y], [x - 10, y - 30], [x - 36, y - 50]], C.mustard, C.ink, 6); break;
    case 'emptytrophy': poly(ctx, [[x - 50, y - 120], [x + 50, y - 120], [x + 36, y - 50], [x + 10, y - 30], [x + 10, y], [x + 34, y + 14], [x - 34, y + 14], [x - 10, y], [x - 10, y - 30], [x - 36, y - 50]], null, C.ink, 6); break;
    case 'wrench': line(ctx, [[x, y], [x + 70, y - 70]], C.silver, 14); circ(ctx, x + 78, y - 78, 16, null, C.silver, 10, false); break;
    case 'book': poly(ctx, [[x - 50, y - 60], [x + 50, y - 60], [x + 50, y + 20], [x - 50, y + 20]], C.red, C.ink, 6); line(ctx, [[x, y - 60], [x, y + 20]], C.ink, 4); break;
    case 'sander': poly(ctx, [[x - 10, y - 20], [x + 80, y - 20], [x + 80, y + 20], [x - 10, y + 20]], C.mustard, C.ink, 6); break;
    case 'lamp': circ(ctx, x + 10, y - 10, 24, C.mustard, C.ink, 6, false); break;
  }
}

// ---------- cars ----------
// (x, y) = ground under the middle of the car; length ≈ 520·s. dir 1 faces right.
export function car(ctx, x, y, s, o = {}) {
  const { era = '1950', color = C.red, dir = 1, spin = 0, driver = null, mech = null, dust = 0, t = 0, smoke = 0, mud = 0 } = o;
  ctx.save(); ctx.translate(x, y); ctx.scale(s * dir, s);
  const jig = Math.sin(t * 40) * (o.vib ?? 1.5);
  if (dust > 0) dustCloud(ctx, -280, -20, dust, t);
  const wheel = (wx, r, spokes = 10, tyre = 14) => {
    circ(ctx, wx, -r, r, C.ink, C.ink, 4, false); circ(ctx, wx, -r, r - tyre, era === 'modern' ? C.grey : C.paper, null, 0, false);
    for (let i = 0; i < spokes; i++) { const a = spin + i * Math.PI * 2 / spokes; line(ctx, [[wx, -r], [wx + Math.cos(a) * (r - tyre), -r + Math.sin(a) * (r - tyre)]], C.ink, 3); }
    circ(ctx, wx, -r, 8, C.ink, null, 0, false);
  };
  const seat = (fx, fy, f) => { if (f) fig(ctx, fx, fy, .42, { pose: 'drive', ...f, t }); };
  ctx.translate(0, jig * .3);
  switch (era) {
    case 'horseless':
      seat(-40, -150, driver);
      poly(ctx, [[-170, -200], [120, -200], [130, -120], [-180, -120]], color, C.ink, 7);
      poly(ctx, [[-180, -260], [-120, -260], [-120, -200], [-180, -200]], color, C.ink, 7);
      line(ctx, [[60, -200], [100, -290]], C.ink, 7); wheel(-130, 95, 12, 8); wheel(110, 75, 12, 8); break;
    case 'steam':
      seat(-40, -150, driver);
      poly(ctx, [[-200, -190], [160, -190], [170, -110], [-210, -110]], color, C.ink, 7);
      poly(ctx, [[100, -190], [150, -190], [150, -330], [100, -330]], C.ink, C.ink, 7);
      for (let i = 0; i < 4; i++) { const k = (t * .7 + i * .25) % 1; circ(ctx, 125 - k * 120, -350 - k * 160, 26 + k * 40, '#CFC6B5', null, 0, false); }
      wheel(-140, 85, 12, 8); wheel(120, 85, 12, 8); break;
    case '1906':
      seat(-80, -150, driver); seat(10, -150, mech);
      poly(ctx, [[-260, -190], [-60, -190], [-60, -150], [180, -160], [240, -150], [250, -100], [-270, -100]], color, C.ink, 7);
      poly(ctx, [[180, -200], [240, -200], [250, -100], [180, -100]], C.ink, C.ink, 7);
      circ(ctx, -280, -150, 50, null, C.ink, 10, false); wheel(-170, 100, 12, 12); wheel(170, 100, 12, 12); break;
    case '1903':
      seat(-60, -150, driver); seat(30, -150, mech);
      poly(ctx, [[-230, -180], [-40, -180], [-40, -150], [170, -160], [230, -140], [230, -100], [-240, -100]], color, C.ink, 7);
      wheel(-160, 92, 12, 12); wheel(160, 92, 12, 12); break;
    case 'arrow':
      seat(-20, -95, driver);
      poly(ctx, [[-300, -70], [-250, -140], [-80, -150], [-40, -175], [40, -150], [220, -130], [320, -80], [300, -50], [-290, -50]], color, C.ink, 7);
      line(ctx, [[-150, -110], [180, -100]], '#ffffff', 5);
      wheel(-180, 70, 0, 18); wheel(200, 70, 0, 18); break;
    case '1950':
      seat(-50, -100, driver);
      poly(ctx, [[-280, -60], [-260, -130], [-120, -150], [-60, -150], [-30, -175], [20, -155], [220, -140], [290, -110], [300, -70], [270, -50], [-270, -50]], color, C.ink, 7);
      circ(ctx, 300, -95, 30, C.ink, C.ink, 5, false); circ(ctx, 300, -95, 18, color, null, 0, false);
      wheel(-180, 72, 14, 14); wheel(190, 72, 14, 14); break;
    case 'modern':
      seat(-20, -80, driver);
      poly(ctx, [[-330, -60], [-320, -150], [-250, -150], [-240, -90], [-60, -100], [-20, -140], [40, -110], [260, -80], [380, -60], [380, -40], [-330, -40]], color, C.ink, 7);
      poly(ctx, [[330, -60], [420, -60], [420, -30], [330, -30]], C.ink, C.ink, 6);
      curve(ctx, [-60, -130], [-10, -190], [60, -120], C.ink, 10);
      wheel(-220, 74, 0, 26); wheel(230, 70, 0, 26); break;
    case 'bike':
      seat(-10, -120, driver);
      poly(ctx, [[-120, -130], [120, -150], [150, -110], [-120, -100]], color, C.ink, 7);
      wheel(-140, 70, 10, 10); wheel(150, 70, 10, 10); break;
  }
  if (mud) { const r = rng(5); for (let i = 0; i < 24; i++) circ(ctx, -250 + r() * 500, -100 - r() * 100, 6 + r() * 12, C.brown, null, 0, false); }
  ctx.restore();
}

export function dustCloud(ctx, x, y, k, t) {
  const r = rng(11);
  for (let i = 0; i < 9; i++) {
    const ph = (t * .9 + r()) % 1, cx = x - ph * 520 - r() * 60, cy = y - r() * 90 - ph * 40, rad = (40 + r() * 50) * (0.6 + ph);
    ctx.globalAlpha = k * (1 - ph) * .85; circ(ctx, cx, cy, rad, C.dust, null, 0, false);
  }
  ctx.globalAlpha = 1;
}

// ---------- scenery ----------
export function hills(ctx, W, y, color, amp, freq, seed, H = 1080) {
  ctx.save(); ctx.translate(MIS[0], MIS[1]); ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, y - amp * (Math.sin(x * freq + seed) * .6 + Math.sin(x * freq * 2.3 + seed * 3) * .4));
  ctx.lineTo(W, H); ctx.closePath(); ctx.fillStyle = color; ctx.fill(); ctx.restore();
}
export function sun(ctx, x, y, r, color = C.mustard) { ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fillStyle = tint(ctx, color, .55, 10); ctx.fill(); ctx.beginPath(); ctx.arc(x, y, r * .62, 0, 7); ctx.fillStyle = color; ctx.fill(); }
export function tree(ctx, x, y, s, color = C.green) {
  line(ctx, [[x, y], [x, y - 110 * s]], C.ink, 9 * s);
  circ(ctx, x, y - 160 * s, 70 * s, color, C.ink, 6 * s);
}
export function building(ctx, x, y, w, h, color, roof = C.red, wins = 2) {
  poly(ctx, [[x, y], [x, y - h], [x + w, y - h], [x + w, y]], color, C.ink, 5);
  poly(ctx, [[x - 10, y - h], [x + w / 2, y - h - w * .45], [x + w + 10, y - h]], roof, C.ink, 5);
  for (let i = 0; i < wins; i++) rrect(ctx, x + 14 + i * (w - 28) / Math.max(1, wins - 1) - (wins > 1 ? 12 : -((w - 28) / 2) + 12), y - h * .66, 24, 34, 3, C.mustard, C.ink, 4, false);
}
// a row of small spectators; deterministic bobbing
export function crowd(ctx, x0, x1, y, n, s, seed, t, o = {}) {
  const r = rng(seed); const cols = o.cols || [C.tan, C.blue, C.light, C.brown, C.green, C.grey];
  for (let i = 0; i < n; i++) {
    const x = lerp(x0, x1, (i + r() * .6) / n), ph = r() * 7, yy = y - r() * 14;
    fig(ctx, x, yy, s * (0.85 + r() * .3), {
      pose: o.cheer && r() < .7 ? 'cheer' : 'stand', t: t + ph, suitColor: cols[Math.floor(r() * cols.length)],
      hat: r() < .45 ? (r() < .5 ? 'flat' : 'bowler') : null, hatColor: r() < .5 ? C.tan : C.ink, expr: o.expr || (r() < .5 ? 'happy' : 'neutral'), dir: r() < .5 ? 1 : -1, lw: 9,
    });
  }
}

// ---------- big map of western Europe (very simplified, hand-made) ----------
// project lon/lat into a box
export function proj(lon, lat, box) { const [x, y, w, h, l0, l1, b0, b1] = box; return [x + (lon - l0) / (l1 - l0) * w, y + (b1 - lat) / (b1 - b0) * h]; }
const LAND = {
  gb: [[-5.7, 50.0], [1.4, 51.2], [1.7, 52.7], [0.2, 53.6], [-1.6, 55.6], [-2.0, 57.7], [-3.4, 58.6], [-5.0, 58.6], [-6.2, 56.8], [-5.0, 55.2], [-3.2, 54.8], [-3.0, 53.4], [-4.6, 53.2], [-4.3, 52.2], [-5.3, 51.7], [-3.4, 51.4], [-5.7, 50.0]],
  ie: [[-6.0, 52.1], [-6.0, 53.9], [-5.6, 54.6], [-7.3, 55.3], [-8.5, 54.9], [-10.0, 54.2], [-10.3, 52.1], [-8.5, 51.6], [-6.0, 52.1]],
  eu: [[-1.6, 43.4], [-1.8, 46.5], [-4.7, 47.8], [-4.6, 48.6], [-1.6, 48.7], [-1.2, 49.7], [1.6, 50.9], [4.0, 51.5], [4.8, 52.8], [7.0, 53.5], [8.6, 53.9], [8.6, 55.4], [10.0, 57.6], [10.6, 57.3], [10.9, 54.4], [14.2, 53.9], [18.0, 54.8], [20.0, 54.4], [20.0, 40.0], [18.5, 40.2], [16.9, 41.0], [15.6, 40.0], [16.0, 38.0], [15.6, 38.0], [14.0, 40.8], [12.0, 41.9], [10.2, 43.9], [8.8, 44.4], [7.5, 43.8], [5.0, 43.4], [3.2, 43.1], [3.2, 41.9], [0.9, 41.0], [-0.3, 39.5], [0.2, 38.7], [-0.7, 37.6], [-2.1, 36.7], [-5.6, 36.0], [-6.4, 36.8], [-7.4, 37.2], [-8.9, 37.0], [-8.8, 38.7], [-9.5, 39.2], [-8.7, 41.9], [-9.3, 43.0], [-7.7, 43.8], [-4.5, 43.4], [-1.6, 43.4]],
};
export function europe(ctx, box, o = {}) {
  const { land = C.light, sea = null } = o;
  if (sea) { ctx.fillStyle = sea; ctx.fillRect(box[0], box[1], box[2], box[3]); }
  for (const k of ['eu', 'gb', 'ie']) poly(ctx, LAND[k].map(p => proj(p[0], p[1], box)), o.fills?.[k] || land, C.ink, 5);
}
export const CITY = {
  Paris: [2.35, 48.86], Rouen: [1.1, 49.44], Bordeaux: [-0.58, 44.84], Madrid: [-3.7, 40.42], 'Le Mans': [0.2, 48.0], Milan: [9.19, 45.46],
  Silverstone: [-1.02, 52.07], Monaco: [7.42, 43.73], Bern: [7.45, 46.95], Spa: [5.97, 50.44], Reims: [4.03, 49.26], Monza: [9.27, 45.58], Dublin: [-6.26, 53.35],
};
export function pin(ctx, x, y, t, color = C.red, label = null, o = {}) {
  const k = pop(t * 1.5); if (t <= 0) return;
  ctx.save(); ctx.translate(x, y); ctx.scale(k, k);
  poly(ctx, [[0, 0], [-16, -30], [-18, -46], [0, -62], [18, -46], [16, -30]], color, C.ink, 5); circ(ctx, 0, -44, 7, C.paper, null, 0, false);
  ctx.restore();
  if (label) text(ctx, label, x + (o.dx ?? 22), y + (o.dy ?? -20), { size: o.size || 30, weight: 600, t: t * 2, align: o.align || 'left' });
}
// dashed route drawn progressively
export function route(ctx, pts, k, color = C.red, lw = 8) {
  if (k <= 0) return; let total = 0; const L = [];
  for (let i = 1; i < pts.length; i++) { const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); L.push(d); total += d; }
  let left = total * clamp(k); ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length && left > 0; i++) { const f = Math.min(1, left / L[i - 1]); ctx.lineTo(lerp(pts[i - 1][0], pts[i][0], f), lerp(pts[i - 1][1], pts[i][1], f)); left -= L[i - 1]; }
  ctx.setLineDash([18, 14]); ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.lineCap = 'round'; ctx.stroke(); ctx.setLineDash([]);
}
