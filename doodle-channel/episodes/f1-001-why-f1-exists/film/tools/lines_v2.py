"""script-v2.md → voice2/lines.json (one TTS take per paragraph) + beats.json (shots inside each take)."""
import json, re
from pathlib import Path
HERE = Path(__file__).resolve().parent.parent
src = (HERE.parent / "script-v2.md").read_text().split("\n---\n")[1]

DIGITS = [  # spoken → subtitle (longest first)
    ("a hundred and twenty-six kilometres", "126 km"), ("a hundred and one kilometres per hour", "101 km/h"),
    ("a hundred kilometres per hour", "100 km/h"), ("twelve hundred kilometres", "1,200 km"), ("a hundred kilometres", "100 km"),
    ("three hundred thousand", "300,000"), ("thirteenth of May, nineteen fifty", "13th of May, 1950"),
    ("eighteen ninety-four", "1894"), ("nineteen oh three", "1903"), ("nineteen oh six", "1906"), ("nineteen thirties", "1930s"),
    ("nineteen thirty-five", "1935"), ("nineteen forty-nine", "1949"), ("nineteen fifty", "1950"),
    ("four point five litre", "4.5-litre"), ("one point five litre", "1.5-litre"), ("one fifty-eight", "158"),
    ("Indianapolis five hundred", "Indianapolis 500"), ("two hundred cars", "200 cars"), ("forty-nine hours", "49 hours"),
    ("twenty-one machines", "21 machines"), ("Seventy laps", "70 laps"), ("Seventy-six years", "76 years"),
    ("twenty-two drivers", "22 drivers"), ("sixty years", "60 years"), ("ten years", "10 years"), ("twelve laps", "12 laps"),
    ("three points", "3 points"),
]
SAY = [("Szisz", "Sis"), ("Émile", "Emile"), ('"', ""), ("—", ", "), ("–", " to ")]

lines, beats, chapter = [], [], ""
for block in re.split(r"\n(?=## |### )", src):
    head = block.split("\n", 1)[0]
    if head.startswith("## "):
        chapter = re.sub(r"^## ", "", head).strip(); continue
    if not head.startswith("### "): continue
    pid = head[4:].strip(); cur = None; pbeats = []
    for l in block.split("\n")[1:]:
        if l.startswith("▸"):
            cur = {"para": pid, "chapter": chapter, "visual": l[1:].strip(), "text": ""}; pbeats.append(cur)
        elif l.strip() and cur is not None:
            cur["text"] = (cur["text"] + " " + l.strip()).strip()
    spoken = " ".join(b["text"] for b in pbeats if b["text"])
    for a, b in SAY: spoken = spoken.replace(a, b)
    lines.append({"id": pid, "text": spoken, "voice": "bm_george", "speed": 0.97})
    for i, b in enumerate(pbeats):
        sub = b["text"]
        for a, d in DIGITS: sub = sub.replace(a, d).replace(a[0].upper() + a[1:], d)
        beats.append({**b, "id": f"{pid}_{i + 1}", "sub": sub})
(HERE / "voice2").mkdir(exist_ok=True)
(HERE / "voice2/lines.json").write_text(json.dumps(lines, indent=1, ensure_ascii=False))
(HERE / "beats.json").write_text(json.dumps(beats, indent=1, ensure_ascii=False))
print(len(lines), "takes,", len(beats), "beats,", sum(len(l["text"].split()) for l in lines), "words")
