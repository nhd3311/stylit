# APEX: Character Bible + Google Flow prompts (motorsport channel, v1)

> Replaces Pip. Original design, the host of a motorsport (F1-first) doodle channel.

## 1. Who is Apex?

| | |
|---|---|
| **Name** | Apex (the racing term: the inside point of a corner, the "perfect line") |
| **Role** | Silent host. The narrator talks; Apex *lives* the story: fan in the grandstand, riding mechanic in 1906, pit crew in 2026. |
| **Personality** | Race-obsessed nerd, overexcited, a bit clumsy, always where the action is. |
| **Head** | Plain **white perfect circle**, thin black outline, **no hair**, no nose, no ears |
| **Face** | Two small solid black dot eyes, short line eyebrows (main expression tool), small line mouth |
| **Body** | Small rounded torso (bean shape), **stick arms and stick legs** (single thick black lines) |
| **Signature 1** | **Vintage round racing goggles pushed up on the forehead**, always, in every era |
| **Signature 2** | **Orange racing gloves** (round mitten hands, no fingers) |
| **Default outfit** | Off-white racing-suit torso with one orange stripe down the middle |
| **Golden rule** | Costumes change by era; **white round head, goggles on the forehead and orange gloves never change** |

## 2. Style: "Risograph editorial" (unchanged from v2)

Flat colour, bold black brush-ink outlines with slight wobble, paper grain + halftone dots, slight colour misregistration, cut-paper collage backgrounds, generous negative space.

| Colour | HEX | Use |
|---|---|---|
| Ink black | `#1A1A1A` | lines, eyes |
| Warm paper | `#F3EDE2` | backgrounds |
| Pure white | `#FFFFFF` | **Apex's head only** (so it pops off the paper) |
| Racing orange | `#F26B21` | gloves, suit stripe, highlights |
| Vermilion | `#E8452C` | Italian red cars, danger |
| Cobalt blue | `#2B4BA8` | French blue cars, sky, night |
| Racing green | `#1F5C3A` | British green cars, grass |
| Mustard | `#E8B530` | sun, trophies, gold |

## 3. LOCK blocks (paste into EVERY prompt)

### 🎨 STYLE LOCK
```
Contemporary editorial illustration with a risograph print look: flat colour shapes, bold black brush-ink outlines with a slight hand-drawn wobble, visible warm paper grain, subtle halftone dot texture, slight colour misregistration at the edges. Limited palette: ink black, warm off-white paper, racing orange, vermilion red, cobalt blue, racing green, mustard yellow. Backgrounds built from simple cut-paper collage shapes, generous negative space, asymmetric gallery-poster composition. No gradients, no 3D rendering, no photorealism, no text, no letters, no numbers, no logos, no watermark.
```

### 🧍 APEX LOCK
```
Apex, an original cartoon character: a plain pure-white perfectly round head with a thin black outline, no hair, no nose, no ears; two small solid black dot eyes, short black line eyebrows, a small simple line mouth; vintage round racing goggles with a brown leather strap pushed up on his forehead; a small rounded bean-shaped torso wearing an off-white racing-suit top with one orange stripe down the middle; arms and legs drawn as single thick black ink lines like a stick figure; round orange racing-glove mitten hands without fingers; small rounded black shoes.
```

## 4. Google Flow workflow

```
STEP 1  Create image (Nano Banana) → turnaround sheet → pick the best → save as Ingredient "Apex"
STEP 2  Create image → background-only style plate → save as Ingredient "Style"
STEP 3  Each scene: Create image + Ingredients [Apex, Style] + scene prompt → 16:9 still
STEP 4  Hero shots only (~8–12, marked ⭐ in the script): Frames to Video (Veo), still = START frame
STEP 5  Name files by scene ID (01-03.png / 01-03.mp4) → Google Drive → send Claude the link
```

## 5. Prompts to create Apex

### 5.1 Turnaround sheet ⭐ (make this first)
```
[STYLE LOCK] [APEX LOCK]
Character model sheet of Apex on a plain warm off-white paper background: four full-body views of the same character in a row (front view, three-quarter view, side profile, back view), standing in a relaxed neutral pose, evenly spaced, same size and proportions in every view. Wide 16:9 sheet.
```

### 5.2 Expression sheet
```
[STYLE LOCK] [APEX LOCK]
Expression sheet of Apex: a 4 by 2 grid of head-and-shoulders portraits of the same character, each with one expression: excited with raised eyebrows and open smile, shocked with tiny eyes and round open mouth, nervous with a sweat drop, proud smug half-closed eyes, sad with drooping eyebrows, focused determined angled eyebrows, laughing with closed curved eyes, confused with one eyebrow raised. The goggles stay on his forehead in every portrait. Plain warm paper background, 16:9.
```

### 5.3 Pose sheet
```
[STYLE LOCK] [APEX LOCK]
Action pose sheet of Apex, six full-body poses of the same character: pointing at something off-screen, running fast with speed lines, waving a chequered flag, holding a stopwatch and looking at it, jumping and cheering with both arms up, kneeling beside a car wheel holding a wheel gun. Plain warm paper background, 16:9.
```

### 5.4 Era costume line-up (consistency test across history)
```
[STYLE LOCK] [APEX LOCK]
Costume line-up of Apex: the same character five times in a row, each in a different simple flat-shape costume over his stick body, keeping the exact same white round head, goggles on the forehead and orange gloves: (1) 1890s newspaper boy with a flat cap and a satchel, (2) 1906 riding mechanic with a long dust coat and a leather cap, (3) 1930s racing driver with a white short-sleeve overall, (4) 1950 spectator in a tweed jacket and flat cap, (5) modern pit-crew member in a fireproof suit with a headset. Plain warm paper background, 16:9.
```

### 5.5 Style plate (background only)
```
[STYLE LOCK]
Style reference plate, no characters: an old country road race scene made of cut-paper collage shapes: a mustard sun, layered racing-green hills, a dusty road curving into the distance, a tiny generic vintage race car in cobalt blue, large areas of empty warm paper, visible grain and halftone texture. 16:9.
```

## 6. Per-scene templates (filled in after the script is approved)

**Still:**
```
[STYLE LOCK] Use ingredient "Apex" for the character and ingredient "Style" for the look.
Scene: {what happens}. Apex: {costume}, {expression}, {action}. Camera: {wide / medium / close-up}.
Cars are generic period race cars without any logos or numbers. Keep the upper third of the frame mostly empty for on-screen text. 16:9.
```

**Video (Frames to Video):**
```
Animate this illustration as limited 2D cut-out animation, like layered paper puppets: {motion}. Keep the flat risograph style, bold wobbly ink lines and paper grain exactly as in the frame; no 3D, no morphing; Apex's white round head, goggles and orange gloves stay identical. Camera: {slow push-in / pan / static}. Audio: no dialogue, no music, only soft ambient sound.
```

## 7. Motorsport-specific rules

| Rule | Why |
|---|---|
| No F1 logo, team logos, sponsor logos, real car numbers | trademarks + Content ID |
| Cars = generic period shapes in **national racing colours** (Italy red, France blue, Britain green, Germany white/silver) | historically accurate and logo-free |
| Real drivers = white-head stick figures + **one prop** (Farina: goggles + cap; Szisz: moustache + dust coat) | recognisable without being caricature portraits |
| Fix: AI adds a nose/hair → add `no hair, no nose` at the end | |
| Fix: goggles disappear → add `goggles pushed up on his forehead` at the end | |
