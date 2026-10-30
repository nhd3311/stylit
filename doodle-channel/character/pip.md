# PIP — Character Bible + Google Flow prompts (v2, proposed)

> Inspired by the *format* of EverythingProfessor / Historically / Unknown Frequencies (one recognisable host, era costumes, bold thumbnails).
> The design itself is original, so it doesn't copy any of their characters.

## 1. Who is Pip?

| | |
|---|---|
| **Role** | Silent host. The narrator talks; Pip *reacts*: he time-travels into every scene, gets confused, shocked, proud. |
| **Personality** | Endlessly curious, a bit clumsy, easily impressed. "The viewer's avatar." |
| **Signature 1** | One hair strand on top that curls into a **?** (curiosity = the channel's brand) |
| **Signature 2** | **Vermilion red scarf**, ALWAYS, in every era and costume |
| **Signature 3** | Huge round head + stick-figure body (keeps the "stick doodle" DNA) |
| **Golden rule** | Costumes change; **head, eyes, ? curl and red scarf never change** |

## 2. Contemporary art style: "Risograph editorial"

Instead of plain white-paper doodles: flat colour, bold brush-ink outlines, paper grain + halftone dots, slight colour misregistration (like risograph printing), cut-paper collage backgrounds, plenty of negative space, gallery-poster composition.

**Palette (5 colours, nothing else):**

| Colour | HEX | Used for |
|---|---|---|
| Ink black | `#1A1A1A` | lines, eyes |
| Warm paper | `#F3EDE2` | background, Pip's face |
| Vermilion | `#E8452C` | scarf, danger, key facts |
| Cobalt blue | `#2B4BA8` | sea, sky, night, tech |
| Mustard | `#E8B530` | sun, gold, light, highlights |

## 3. The two LOCK blocks (paste into EVERY prompt)

### 🎨 STYLE LOCK
```
Contemporary editorial illustration with a risograph print look: flat colour shapes, bold black brush-ink outlines with a slight hand-drawn wobble, visible warm paper grain, subtle halftone dot texture, slight colour misregistration at the edges. Strict limited palette of only five colours: ink black, warm off-white paper, vermilion red, cobalt blue, mustard yellow. Backgrounds built from simple cut-paper collage shapes, generous negative space, asymmetric gallery-poster composition. No gradients, no 3D rendering, no photorealism, no text, no letters, no numbers, no watermark.
```

### 🧍 PIP LOCK
```
Pip, an original cartoon character: a very large perfectly round head, about half of his total height, filled with warm off-white and outlined with a bold, slightly wobbly black brush-ink line; two solid black vertical oval eyes set wide apart in the lower half of the face, each with a tiny white highlight; short thick black dash eyebrows; a small simple line mouth; no nose, no ears; a single black hair strand on top of the head curling into the shape of a question mark; a thin stick-figure body with arms and legs drawn as thick black ink lines, round mitten hands without fingers, small rounded black shoes; a vermilion red knitted scarf wrapped around his neck with two tails fluttering.
```

## 4. Google Flow workflow

```
STEP 1  Create image (Nano Banana 2.1 / Pro) → character sheet → pick the best one → save as Ingredient "Pip"
STEP 2  Create image → background-only style plate → save as Ingredient "Style"
STEP 3  For each scene: Create image + Ingredients [Pip, Style] + scene prompt → 16:9 still
STEP 4  Hero shots only (~12–15): Frames to Video (Veo 3.1), using the still as the START frame
STEP 5  Name files by scene ID (01-03.png, 01-03.mp4) → upload to Google Drive → send Claude the link
```

💡 **Save credits:** don't turn all ~75 scenes into Veo video. Make stills for every scene (Claude animates them in the edit with zoom, pan and parallax), and use Veo only for hero shots (shipwreck, Su Song's tower, pendulum, H4 at sea, Day of Two Noons, atomic clock…).

---

## 5. Prompts to create Pip (STEP 1–2)

### 5.1 Turnaround sheet ⭐ (make this one first)
```
[STYLE LOCK] [PIP LOCK]
Character model sheet of Pip on a plain warm off-white paper background: four full-body views of the same character in a row — front view, three-quarter view, side profile, back view — standing in a neutral relaxed pose, evenly spaced, same size and proportions in every view, clean and readable. Wide 16:9 sheet.
```

### 5.2 Expression sheet
```
[STYLE LOCK] [PIP LOCK]
Expression sheet of Pip: a 4 by 2 grid of head-and-shoulders portraits of the same character, each showing one expression — curious with one eyebrow raised, happy with closed upward-curved eyes, shocked with tiny pupils and open round mouth, confused with tilted eyebrows and a small sweat drop, proud smug smile with eyes half closed, scared trembling with lines around him, sleepy with droopy eyes, determined with angled eyebrows. The red scarf is visible in every portrait. Plain warm paper background, 16:9.
```

### 5.3 Pose sheet
```
[STYLE LOCK] [PIP LOCK]
Action pose sheet of Pip, six full-body poses of the same character evenly spaced: pointing at something off-screen, walking with scarf tails flowing, thinking with mitten hand on chin, jumping back in shock, running fast with speed lines, sitting cross-legged reading a big old book. Plain warm paper background, 16:9.
```

### 5.4 Costume test (check the face stays consistent across eras)
```
[STYLE LOCK] [PIP LOCK]
Costume line-up of Pip: the same character five times in a row, each wearing a different simple flat-shape costume over his stick body while keeping the exact same round head, eyes, question-mark hair curl and red scarf — (1) ancient Egyptian linen kilt and simple striped headcloth, (2) medieval monk brown hooded robe, (3) 18th-century sailor with blue coat and tricorn hat, (4) Victorian railway station master with black coat and peaked cap, (5) 1960s scientist in white lab coat holding a clipboard. Plain warm paper background, 16:9.
```

### 5.5 Style plate (background only, no character)
```
[STYLE LOCK]
Style reference plate, no characters: an ancient landscape at golden hour made of cut-paper collage shapes — a mustard sun, layered cobalt-blue hills, a simple vermilion pyramid, a few ink-black birds — with large areas of empty warm paper, visible grain and halftone texture. 16:9.
```

## 6. Templates for each scene (STEP 3–4). Claude fills these in after the script is approved

**Still image:**
```
[STYLE LOCK] Use ingredient "Pip" for the character and ingredient "Style" for the look.
Scene: {what happens}. Pip: {costume}, {expression}, {action}. Camera: {wide / medium / close-up}.
Keep the upper third of the frame mostly empty for on-screen text. 16:9.
```

**Video (Frames to Video):**
```
Animate this illustration as limited 2D cut-out animation, like layered paper puppets: {motion}. Keep the flat risograph style, bold wobbly ink lines and paper grain exactly as in the frame; no 3D, no morphing, Pip's face and red scarf stay identical. Camera: {slow push-in / slow pan left / static}. Audio: no dialogue, no music, only soft ambient sound.
```

## 7. Common Flow mistakes & fixes

| Mistake | Fix |
|---|---|
| Pip grows a nose/ears or real fingers | Add `no nose, no ears, mitten hands without fingers` at the end of the prompt |
| Scarf turns another colour | Add `the scarf is vermilion red` at the end of the prompt |
| AI writes gibberish text in the image | Keep `no text, no letters, no numbers`. Claude adds text in the edit |
| Colours drift away from the palette | Pass the "Style" ingredient back in. Don't forget the STYLE LOCK |
| Veo turns it into 3D / morphs the face | Shorter motion, `limited 2D cut-out animation`, simple camera moves |
