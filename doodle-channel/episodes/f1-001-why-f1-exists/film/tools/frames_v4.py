"""v4 shot list: one frame per spoken phrase (~2-4 s), in the style of the reference explainer.

Each chunk of narration (split exactly as in chunks()) gets 1-2 frames:
  A(prompt, apex=False, label=None, x=False)  -> AI illustration (gen_images.py), optional handwritten label / red X drawn in code
  K(text, sub=None, icon=None)                -> handwritten text card on white, drawn in code (no AI, spelling always exact)
Writes frames_v4.json (for the editor) and gen/frames_ai.json (for gen_images.py).
"""
import json, re
from pathlib import Path
HERE = Path(__file__).resolve().parent.parent

def A(p, apex=False, label=None, x=False): return {"kind": "ai", "prompt": p, "apex": apex, "label": label, "x": x}
def K(t, sub=None, icon=None): return {"kind": "card", "text": t, "sub": sub, "icon": icon}

# recurring descriptions (kept identical so the AI draws the same things the same way)
ALFA = "a red 1950 Alfa Romeo 158 single-seater racing car (long cigar-shaped body, oval front grille, exposed wire wheels)"
FARINA = "a stick-figure racing driver in a white short-sleeved overall and a brown leather helmet with goggles"
OFFICIAL = "a stick figure in a dark suit and bowler hat"
DUSTCAR = "an early-1900s open racing car with a long bonnet, wooden-spoke wheels, a driver and a riding mechanic in leather caps"
SILVER = "a streamlined silver 1930s Grand Prix racing car"

SHOTS = [
 # P00 hook
 [K("F1 STARTED IN 1950?", icon="question")],
 [A("A modern Formula One starting grid seen from the side, sleek generic F1 cars in team colours (no logos), Apex in a pit-crew headset scratching his head, puzzled.", apex=True),
  K("56 YEARS", sub="nobody tells you about")],
 # P01
 [K("A FEW YEARS EARLIER…", icon="clock")],
 [A("A grey wartime airfield in England, 1943: two dark green twin-engined bombers parked on concrete, a few stick-figure airmen in brown flight jackets walking past, overcast sky.")],
 [A("Seen from high above: an old wartime airfield turned into a race track in 1950, the perimeter road outlined as a winding loop, green fields, small crowds along the edges, sunny day.", label="13 MAY 1950")],
 [A("A 1950 race track made from an old airfield perimeter road: grey tarmac curving away, flat grass, a wooden spectator fence, a red racing car in the distance.")],
 [A("Close-up of a 1950 race track edge marked by stacked golden straw bales and red-painted oil drums, tarmac in the foreground.")],
 [A("A huge excited crowd of stick figures in 1950s caps and coats behind a rope fence at a race track, some waving flags, sunny day.", label="≈100,000 FANS")],
 [A("A small royal box draped in red, white and blue bunting at a 1950 race track: a stick-figure king in a dark suit with a small crown and a stick-figure queen in a pale dress and hat, smiling; Apex in a flat cap beside the box, jaw dropped.", apex=True)],
 [A("A stick-figure king and queen in a royal box watching a race, with a large golden thought bubble showing a racing car.", label="A FIRST — AND A LAST")],
 # P02
 [A(f"A 1950 starting grid: four identical red 1950 Alfa Romeo 158 racing cars lined up side by side on the front row, drivers in leather helmets, mechanics standing by.", label="4 × ALFA ROMEO 158")],
 [A("An empty grid slot on a race track with a lonely traffic cone; a small red racing car drives away into the distance in the opposite direction, a stick-figure race organiser shrugs.", label="NO FERRARI", x=False)],
 [K("70 LAPS LATER", icon="flag")],
 [A(f"{ALFA} crossing the finish line as an official in a white coat waves a black-and-white chequered flag; the driver, {FARINA}, raises one arm in triumph; straw bales line the track.", label="GIUSEPPE FARINA")],
 [A("A crowd of stick figures cheering at a 1950 race track, hats in the air, unaware; one small stick figure looks thoughtfully at the camera.")],
 [A(f"A golden trophy on a podium with a red 1950 racing car beside it, confetti in the air, a banner-shaped empty sign above.", label="RACE Nº1 OF THE F1 WORLD CHAMPIONSHIP")],
 [K("BUT…", icon="question")],
 [A("A long winding road made of years stretching from the foreground into the distance, with small milestones, ending at a 1950 trophy on the horizon; Apex standing at the start of the road with a backpack.", apex=True, label="56 YEARS OF PROBLEMS")],
 [A("A cheerful 1890s Paris newspaper boy in a flat cap holding up a newspaper and shouting, a big stack of newspapers at his feet, a Paris street behind.")],
 # P03
 [A("A cobbled Paris street in 1894 with cream Haussmann buildings, horse-drawn carriages everywhere and one small strange horseless car puttering among them.", label="1894")],
 [A("An 1894 horseless carriage broken down at the side of a road with steam and smoke coming out, its driver in a top hat scratching his head, passers-by covering their ears.")],
 [A("Rich stick figures in top hats and fancy dresses laughing as they pose beside an early 1890s horseless carriage like a toy, an ordinary worker rolling his eyes in the background.")],
 [A("An 1890s printing press room: a big black press printing newspapers, a stick-figure editor with a moustache and waistcoat holding up a fresh front page with a drawing of a car.", label="LE PETIT JOURNAL")],
 [A("A simple illustrated map of northern France with a dotted route line drawn from Paris to Rouen along the river Seine, a small car icon on the route, a pin at each end.", label="PARIS → ROUEN · 126 km")],
 [A("A stick-figure judge with a magnifying glass inspecting an 1894 horseless carriage carefully, clipboard in the other hand.", label="PROVE THEY WORK")],
 [A("A mountain of entry forms and envelopes piled on an 1894 office desk, a stick-figure clerk peeking over the top, overwhelmed.", label="102 ENTRIES")],
 [A("An 1894 starting line in Paris with a mixed line-up of odd early machines: a steam tractor, small petrol carriages and tricycle-like cars, flags strung above, a small crowd watching.", label="ONLY 21 STARTED")],
 # P04
 [K("NOT REALLY A RACE")],
 [A("Three stick-figure judges in bowler hats at a desk with a checklist, one holding up a sign shaped like a shield, inspecting an early car politely.", label="SAFE")],
 [A("A stick-figure driver steering an 1894 car with one relaxed hand, a coin purse and a small fuel can beside him, judges nodding approvingly.", label="EASY · CHEAP")],
 [A("1894 French country road: a big black steam tractor with a tall chimney puffing smoke, pulling a small carriage, arrives first under a finish banner; spectators clap.")],
 [A("Two stick-figure judges in bowler hats shaking their heads and crossing their arms in front of the big steam tractor, its driver looking disappointed.", x=True)],
 [A("Inside the cab of a steam tractor: a second man sweaty and covered in soot shovelling coal into the boiler fire while the driver steers.", label="NEEDS A STOKER")],
 [A("Two small early petrol cars, one red and one yellow, parked side by side with a big shared golden prize trophy between them, their drivers shaking hands.", label="PEUGEOT + PANHARD")],
 [K("A YEAR LATER…", sub="1895")],
 [A("A simple illustrated map of France with a long dotted route line from Paris down to Bordeaux in the south-west and back again, a small car icon on the line.", label="≈1,200 km")],
 [A("Night on a French country road: a small 1895 two-seater petrol car with oil lamps driving under the stars, the tired stick-figure driver yawning but holding on.")],
 [A("Dawn at a Paris finish line: the same small 1895 car arriving first, the exhausted driver with dark rings under his eyes, a large clock showing the hours.", label="≈48 h 47 min")],
 [K("BUT THERE'S A CATCH")],
 [A("A stern stick-figure official in a bowler hat pointing at a big rulebook page with a drawing of a car with four seats.", label="RULE: 4 SEATS")],
 [A("Close-up of the small 1895 racing car showing only two seats, the driver looking at the empty space behind him in dismay.", label="2 SEATS", x=True)],
 [A("A later-arriving 1895 four-seat petrol car crossing the finish line hours after the first, its crew grinning, officials handing them the trophy while the first driver watches sadly.", label="OFFICIAL WIN: PEUGEOT")],
 # P05
 [A("Apex in a salesman's waistcoat and bowler hat proudly presenting a mud-covered early car to a small crowd of curious buyers.", apex=True)],
 [A("A mud-splattered 1895 car with a big golden medal hanging on it, buyers queueing with money in hand.", label="SURVIVED 1,200 km")],
 [A("A giant 1890s advertising poster on a wall showing a racing car winning, people stopping to look at it.", label="THE BEST ADVERT")],
 [K("REASON #1", sub="why F1 exists")],
 [A("Apex giving a big thumbs up next to a sturdy early car with a checkmark-shaped badge on it.", apex=True, label="PROVE THE MACHINE WORKS")],
 # P06
 [K("THE TROUBLE IS…")],
 [A("Split image: on the left a very fast early-1900s racing car leaving speed lines, on the right a bumpy narrow dirt road with potholes and chickens.")],
 [K("1903")],
 [A("A big early-1900s racing car speedometer-style dial with the needle past 100, a blurred racing car behind it on a dirt road.", label="100+ km/h")],
 [A(f"{DUSTCAR} roaring along a narrow dirt road through a French village, chickens scattering, villagers jumping aside.")],
 [A("Crowds of stick-figure spectators standing right at the very edge of a dusty country road, leaning out, as a racing car approaches in a cloud of dust.")],
 [A("Dawn at the palace gardens of Versailles: a long queue of early racing cars with drivers and riding mechanics waiting to start, huge crowds, the palace in the background.", label="VERSAILLES · MAY 1903")],
 [A("A simple illustrated map of France and Spain with a long dotted route line from Paris down to Madrid, a small car icon at the start.", label="→ MADRID")],
 [A(f"{DUSTCAR} almost invisible inside a huge thick cloud of brown dust on a country road, only its rear wheels showing.")],
 [A("Curious stick-figure spectators stepping out into the middle of a dusty road to look, while a racing car's headlamps appear through the dust behind them.")],
 # P07
 [A("A sombre roadside scene: an early racing car wheel lying broken on the ground near a tree, smoke drifting, no people shown, muted grey colours.")],
 [A("A simple sepia-toned memorial portrait frame of a stick figure with a moustache in a 1903 driving cap, a black ribbon on the corner.", label="MARCEL RENAULT 1872–1903")],
 [A("Three stick-figure brothers in early-1900s suits and moustaches standing proudly in front of a small car workshop.", label="THE RENAULT BROTHERS")],
 [A(f"Two early racing cars side by side in thick dust on a country road, the one behind pulling out to overtake.")],
 [A("A bend in a dusty country road lined with trees; skid marks leave the road towards one large tree; muted colours, no people visible.")],
 [A("Bordeaux finish line in 1903: a stick-figure driver with a moustache in a leather cap arriving in a small racing car, smiling for a moment, crowds cheering.", label="LOUIS RENAULT")],
 [A("The same driver at Bordeaux now sitting down with his head in his hands, a messenger holding a telegram beside him, the crowd falling silent.")],
 [A("Night in Bordeaux: a stern French official in a dark uniform and kepi holding up a hand to stop a line of racing cars, lamplight.", label="RACE STOPPED")],
 [A("A row of early racing cars parked with their engines off, a gendarme standing guard, drivers looking glum.", x=False)],
 [A("Horses pulling early racing cars on ropes along a city street towards a railway station, drivers walking beside them looking embarrassed.", label="TOWED TO THE STATION")],
 # P08
 [A("A simple illustrated map of France with the long Paris–Bordeaux–Madrid road line crossed out in red.", x=True, label="CITY-TO-CITY RACING")],
 [A("A loop of country road closed off by wooden barriers and flags, a race car driving around it while spectators stand safely behind the barriers.", label="CLOSED CIRCUITS")],
 [A("A closed road loop seen from above with gates and barriers at every junction, a sign-shaped board at the entrance.")],
 [K("REASON #2"), A("Apex standing behind a safety barrier at a closed circuit, giving a thumbs up as a race car passes safely.", apex=True, label="A SAFE PLACE TO RACE")],
 # P09
 [K("MEANWHILE…")],
 [A("A rich American newspaper owner stick figure with a big moustache, top hat and fur coat proudly presenting a large silver trophy cup.", label="JAMES GORDON BENNETT")],
 [A("Small teams of stick figures each standing around their own early racing car, each team holding a plain coloured flag, a globe behind them.", label="NATIONS, NOT COMPANIES")],
 [K("ONE COLOUR PER NATION", sub="1900")],
 [A("Three early-1900s racing cars side by side: one painted blue, one painted white, one painted yellow, no logos, simple flags of plain colour above each.", label="FRANCE · GERMANY · BELGIUM")],
 [A("An early-1900s racing car painted bright red, with an American-style stick-figure driver in a cap, waving.", label="USA = RED")],
 [A("A British stick-figure team manager looking at three paint pots labelled only by colour: red, white and blue, all crossed out, scratching his head.")],
 [K("1903")],
 [A("A peaceful Irish country road with stone walls and rolling green hills, a crowd waiting for a race.", label="IRELAND")],
 [A("A British policeman stick figure with a tall helmet holding up a hand in front of a road sign-shaped board with a crossed-out car icon, on an English country lane.", x=True)],
 [A("A British early racing car being painted dark green by a stick-figure mechanic with a brush, a paint pot beside him.")],
 [A("A dark green early-1900s racing car on an Irish country road with a big three-leaf shamrock shape drawn in the clouds above.", label="THE STORY GOES…")],
 [A("A dark green racing car, with Apex holding a paint brush and grinning proudly.", apex=True, label="BRITISH RACING GREEN")],
 [A("An early Italian racing car painted black, its driver in a leather cap.", label="ITALY: BLACK…")],
 [A("The same Italian racing car now repainted bright red, a stick-figure mechanic stepping back with a dripping brush.", label="…THEN RED")],
 [A("A modern red Formula One car (no logos) next to an early-1900s red racing car, both shining.", label="STILL RED TODAY")],
 # P10
 [K("1906")],
 [A("Summer countryside near Le Mans, France: a huge triangle of closed country roads seen from a hill, a big wooden grandstand with tricolour flags, poplar trees along the roads.", label="AUTOMOBILE CLUB DE FRANCE")],
 [A("A big golden trophy glowing on a pedestal in front of a 1906 grandstand, crowds in boater hats admiring it.")],
 [K("GRAND PRIX", sub="= \"big prize\"")],
 [A("A simple illustrated map of a triangular road circuit linking three small French towns, a dotted line around it.", label="1 LAP ≈ 103 km")],
 [A("A 1906 grandstand scoreboard with a big calendar showing two days, a sun shining hot overhead.", label="12 LAPS · 2 DAYS")],
 [A(f"{DUSTCAR} racing on a sun-baked country road, heat shimmer rising, poplar trees along the road.", label="≈1,238 km")],
 [A("A cracked, broken-up country road in blazing sunshine with a racing car tyre exploding in a puff of smoke.")],
 [A("A stick-figure mechanic kneeling by an early racing car, sweating, cutting a ruined tyre off a wooden wheel with a knife.")],
 [A("The same mechanic still working on the tyre while a big pocket watch beside him shows the minutes ticking, his driver tapping his foot impatiently.", label="10+ MINUTES")],
 # P11
 [K("SECRET WEAPON")],
 [A("A shiny spare wheel rim with a tyre already fitted, held up like a treasure by a stick-figure mechanic in a 1906 pit, sunlight glinting on it.", label="DETACHABLE RIMS · MICHELIN")],
 [A("A stick-figure mechanic tossing away a knife and a ruined tyre with a grin.")],
 [A("A 1906 blue racing car in the pits: a mechanic swapping the whole wheel rim quickly while another holds a stopwatch, the driver already gripping the wheel.", label="A FEW MINUTES")],
 [A("A stick-figure racing driver with a thick moustache in a leather cap and goggles, sitting in a blue 1906 racing car, determined.", label="FERENC SZISZ")],
 [A("A blue 1906 racing car flying along a dirt road in a cloud of dust, speed lines, poplar trees whizzing past, the riding mechanic holding on.", label="≈101 km/h")],
 [A("Apex as a riding mechanic in a leather cap, holding on for dear life beside the driver in a blue early racing car on a bumpy dirt road.", apex=True, label="ON DIRT ROADS · 1906")],
 [A("A blue 1906 racing car crossing a finish line under a big banner, crowds cheering, hats flying.", label="GRAND PRIX RACING IS BORN")],
 [K("BUT…", sub="still a patchwork")],
 [A("A teetering pile of different-coloured rulebooks about to topple over, a puzzled stick-figure official trying to hold it up.")],
 [A("Several different race winners each holding a different trophy, standing far apart and looking at each other, with an empty podium in the middle.", label="NO OVERALL CHAMPION")],
 # P12
 [K("THE 1930s")],
 [A("A huge 1930s Grand Prix grandstand packed with stick-figure spectators in hats, plain coloured flags, a tense atmosphere.", label="EUROPEAN CHAMPIONSHIP")],
 [A("A government building with a stick figure in a 1930s official uniform handing over big sacks of money to two racing team managers.", label="… AND POLITICS")],
 [A(f"Two silver 1930s racing cars side by side in a workshop, one with a long bonnet and one teardrop-shaped with the engine behind the driver, engineers proudly polishing them.", label="MERCEDES-BENZ · AUTO UNION")],
 [A(f"{SILVER} blasting past older red and blue racing cars on a race track, motion lines, the others left behind.")],
 [A("Two silver 1930s racing cars side by side on a podium-like stage, a laurel wreath hanging on each.", label="THE SILVER ARROWS")],
 [A("A 1930s mechanic sanding white paint off a racing car body in a workshop, flakes of white paint falling, revealing shiny silver metal underneath.", label="THE LEGEND")],
 [A("Apex as a detective in a deerstalker hat holding a magnifying glass up to an old newspaper clipping, one eyebrow raised.", apex=True, label="MYTH?")],
 [A("An old 1934 race rulebook page with the weight-limit rule crossed out, beside a silver racing car on a weighing scale.", x=True, label="LIMIT NOT USED THAT DAY")],
 # P13
 [K("…BUT THEY CAN BE BEATEN")],
 [A("A forest race track in Germany in 1935 with tall pine trees and an enormous crowd of stick figures covering the hillsides.", label="1935 · ≈300,000 FANS")],
 [A("A determined stick-figure driver with a yellow jumper and leather helmet in an old red 1930s racing car, gripping the wheel.", label="TAZIO NUVOLARI")],
 [A("An old red 1930s racing car chasing two silver racing cars through a forest bend, closing in, motion lines.")],
 [A("The old red racing car crossing the finish line just ahead of a silver car, a chequered flag waving, the huge crowd stunned.", label="LAST-LAP WIN")],
 [A("An empty, overgrown race track with weeds growing through the tarmac, a closed gate with a chain across it, grey sky.", label="1939–1945")],
 [A("A small red 1940s Alfa Romeo 158 racing car in an Italian workshop, a stick-figure mechanic proudly resting a hand on it.", label="ALFA ROMEO 158")],
 [A(f"Close-up of {ALFA} gleaming under a single lamp in a dark workshop.")],
 [A("Stick-figure workers secretly pushing a small red racing car under a pile of hay and firewood in a barn at night, a lantern glowing.", label="HIDDEN NEAR MILAN")],
 [A("A small red racing car hidden behind big round wheels of cheese stacked on shelves in an old cheese factory.", label="LEGEND: A CHEESE FACTORY")],
 [A("A pink pig curiously sniffing a small red racing car hidden under hay in a farm barn; Apex with a finger to his lips going 'shh'.", apex=True, label="OR A PIG FARM")],
 # P14
 [A("A smoky 1946 Paris meeting room: stick-figure officials in suits around a long table with one big rulebook in the middle.", label="AFTER THE WAR · THE FIA")],
 [A("A big closed rulebook glowing on a table, with a red cover and a simple car silhouette on it.", label="ONE FORMULA")],
 [K("FORMULA", sub="= the rules")],
 [A("A recipe-card-style page showing simple icons: an engine, a weighing scale, a racing car outline, each with a tick box.")],
 [A("A racing car engine on one side of a balance scale and a weight on the other side, perfectly balanced.", label="ENGINE SIZE · WEIGHT")],
 [A("A big old-fashioned car engine block on one side of a balance scale.", label="4.5 L")],
 [A("A small car engine with a supercharger fan attached, on the other side of a balance scale, perfectly balanced.", label="1.5 L + SUPERCHARGER")],
 [A("A rich stick figure in a top hat with a giant monster racing car twice the size of the others, smirking.", label="NO RULES?")],
 [A("Two different racing cars, one red and one green, racing side by side neck and neck on a track.", label="A FAIR FIGHT"),
  K("REASON #3", sub="make it fair")],
 # P15
 [K("ONE THING MISSING…", icon="question")],
 [A("A 1949 motorcycle racer stick figure proudly holding up a world championship trophy, his motorcycle beside him, while a racing car driver looks on jealously.", label="1949 · MOTORCYCLES")],
 [A("A racing car driver stick figure sulking with arms crossed next to his red racing car, an empty trophy shelf behind him.")],
 [K("EARLY 1950", sub="according to most accounts…")],
 [A("An elegant Italian count stick figure with a thin moustache and a smart suit drawing lines between dots on a big map of Europe on a wall.", label="COUNT ANTONIO BRIVIO")],
 [A("A big wooden points board with a ladder of five places and a small extra star for the fastest lap.", label="8 · 6 · 4 · 3 · 2 + 1")],
 [A("A simple illustrated map of Europe with six red map pins in Britain, Monaco, Switzerland, Belgium, France and Italy.", label="7 RACES")],
 [A("A simple illustrated map with one red map pin far away across the ocean in America on an oval race track.", label="+ INDIANAPOLIS 500")],
 [A("An almost empty grandstand section labelled only by colour, with a few European stick figures who decided to stay home on the other side of the ocean.")],
 # P16
 [A("Seen from high above: the 1950 airfield race track again, with a red racing car leading the field.", label="SILVERSTONE")],
 [K("13 MAY 1950")],
 [A("Barn doors bursting open as a small red 1950 Alfa Romeo 158 racing car roars out of a hay barn, straw flying.", label="THE SAME MODEL…")],
 [A(f"{ALFA} crossing the 1950 finish line under a chequered flag.", label="ALFA ROMEO 158")],
 [A("An Italian race track in 1950 at Monza with tall trees and a grandstand, a big scoreboard waiting.", label="MONZA · THE FINAL")],
 [A("Two stick-figure drivers in matching white overalls and leather helmets standing next to two identical red racing cars, eyeing each other; one is younger with dark hair.", label="FARINA vs FANGIO")],
 [A("A big wooden points board at a race track showing two names as coloured bars, one slightly longer.", label="FANGIO LEADS BY 2")],
 [A(f"{FARINA} standing on the top step of a podium with a big trophy, confetti falling, the crowd cheering.", label="FARINA 30 · FANGIO 27")],
 [A(f"{FARINA} with a laurel wreath around his neck holding a world champion trophy high.", label="FIRST F1 WORLD CHAMPION"),
  K("REASON #4", sub="crown one champion")],
 # P17
 [K("SO, WHY DOES F1 EXIST?")],
 [A("Apex sitting at a desk ticking off a checklist with a big pencil, surrounded by little sketches of early cars.", apex=True)],
 [A("A safe closed circuit with barriers on one side, and two evenly matched racing cars on the other.", label="SAFE PLACE · FAIR FIGHT")],
 [A("A single big golden championship trophy on a pedestal under a spotlight.", label="ONE CHAMPION")],
 [K("76 YEARS LATER")],
 [A("A modern F1 car (no logos) in a high-tech factory with engineers studying screens and wind tunnel models.", label="TECHNOLOGY")],
 [A("Modern team bosses in team shirts arguing over a giant rulebook at a meeting table.", label="THE RULEBOOK")],
 [A("A modern Formula One grid of 22 sleek generic F1 cars in many colours lined up, seen from above.", label="22 DRIVERS · 1 TITLE")],
 [A("Apex in a modern pit-crew suit and headset picking up an old 1894 newspaper from the pit lane floor and grinning.", apex=True)],
 [K("NEXT TIME", sub="from deadly hobby to billion-dollar machine")],
 [A("Apex waving goodbye cheerfully next to a modern F1 car (no logos) on a sunny starting grid.", apex=True)],
]


def chunks():
    """Split narration exactly like the shot list above was written against."""
    L = json.loads((HERE / "voice2/lines.json").read_text()); out = []
    for p in L:
        for s in re.split(r'(?<=[.?!:])\s+', p['text']):
            cur = ''
            for pt in re.split(r'(?<=,)\s+', s):
                if cur and len((cur + ' ' + pt).split()) > 11: out.append([p['id'], cur]); cur = pt
                else: cur = (cur + ' ' + pt).strip()
            if cur:
                if out and out[-1][0] == p['id'] and len(cur.split()) <= 3: out[-1][1] += ' ' + cur
                else: out.append([p['id'], cur])
    return out


if __name__ == "__main__":
    ch = chunks()
    assert len(ch) == len(SHOTS), f"{len(ch)} chunks vs {len(SHOTS)} shot groups"
    frames, ai = [], []
    for i, ((pid, txt), group) in enumerate(zip(ch, SHOTS)):
        for j, f in enumerate(group):
            fid = f"f{i:03d}{'abc'[j]}"
            frames.append({"id": fid, "chunk": i, "para": pid, "text": txt, "part": j, "parts": len(group), **f})
            if f["kind"] == "ai": ai.append({"id": fid, "prompt": f["prompt"], "apex": f["apex"]})
    (HERE / "frames_v4.json").write_text(json.dumps(frames, indent=1, ensure_ascii=False))
    (HERE / "gen").mkdir(exist_ok=True)
    (HERE / "gen/frames_ai.json").write_text(json.dumps(ai, indent=1, ensure_ascii=False))
    print(f"{len(frames)} frames: {len(ai)} AI images + {len(frames) - len(ai)} text cards")
