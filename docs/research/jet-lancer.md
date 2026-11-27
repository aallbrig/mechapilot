# Jet Lancer: research and what Mecha Fighter should take from it

The owner wants Mecha Fighter's Levels to feel "like Jet Lancer", starting with a **deck**: a ground or sea surface at the bottom of the world. This note breaks down how Jet Lancer works, from primary and high-trust sources. It then ranks what to bring into Mecha Fighter and how, against the spec in issue #73 and the code on `main`.

Researched 2026-11-27. Each claim carries a source tag such as **[S1]**; the [Sources](#sources) list gives the full links. Statements marked _inferred_ come from studying screenshots, not from a written source.

## Facts about the game

- **Title:** Jet Lancer. Released 12 May 2020 on PC, Mac and Nintendo Switch [S1][S2].
- **Developer:** Code Wakers, the duo of Vladimir Fedyushkin (design and art) and Nicolai Danielsen (programming) [S1][S2][S4]. **Publisher:** Armor Games Studios [S1][S4].
- **Correction:** the brief named Mark Dobbins as the developer. No source supports that; every store page and the publisher credit Code Wakers.
- **Pitch:** "a high-velocity aerial combat shooter where you duel enemy aviators, hunt giant robots, and defy death at supersonic speeds" [S1][S3].
- **Campaign:** 30 missions and 11 bosses, plus New Game+ with harder AI and new attack patterns [S1][S2].
- **Loadout:** 28 guns, payloads and flight components, chosen at a carrier hub [S1][S8].
- **Arcade Mode:** a wave-based score attack with stacking upgrades and multi-boss battles, added after launch [S1].
- **History:** the working title was _Skychasers: Reborn_; it became _Jet Lancer_ in December 2018 [S13].

## Screenshots studied

These are the official images from the publisher, the itch.io page and Kotaku's review. They're described here, not copied into the repo.

| Ref | Source URL | What it shows |
| --- | --- | --- |
| I1 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MTcucG5n/original/RpQJIX.png> | A boss fight over desert. A spider-like boss's segmented legs arc over and into the sand. Its name and health bar sit at the top centre. A skull "DANGER" sigil sits over the boss, and the hearts sit low in the middle. The ground is a flat perspective plane, with the horizon about 60% of the way up the screen. |
| I2 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MjAuanBn/original/4%2BrXF0.jpg> | The loadout screen in 3D: special weapon, charge weapon and installed modules, with easy-to-hard and generalist-to-specialist sliders. |
| I3 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MjUucG5n/original/b1zVBM.png> | The 3D overworld: the player's hovercraft carrier on open sea among sea stacks, with mission beacons and the card "OP 36: SEA HUNTER: Destroy enemy ships", rank ACE. |
| I4 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MjIucG5n/original/sxHR4U.png> | A dogfight at dusk over a city on the coast, with sea in the foreground. White dotted contrails trace every aircraft's path. Icon chevrons sit on the screen edges, and pink hex tiles fill the edges as a damage warning. Two bracket gauges flank the centre just below the horizon. |
| I5 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MjEuanBn/original/RilN7A.jpg> | A boss named "TOWER": coiled segmented rings over a coastal city and sea, a big gold shot stream, and a letter rank "C" at the top right. |
| I6 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MjMucG5n/original/qsImXG.png> | Sunset over a flat violet sea, with the horizon about 65% of the way up. A huge red burst explosion, edge damage hexes, and off-screen chevrons along the top. |
| I7 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MTguanBn/original/Y3Tgrb.jpg> | An early build (file dated December 2018): a strictly side-on city street, with a tank convoy driving along a road at the bottom of the screen. Red cross markers lock enemy jets. |
| I8 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MTkuanBn/original/1un8z7.jpg> | Big orange explosions over a city grid. Rooftops line the bottom of the screen, with a giant silhouette in the background haze. |
| I9 | <https://img.itch.zone/aW1hZ2UvNjM2Mzg4LzM0MDE4MjQucG5n/original/GILobm.png> | Twilight over green farmland, with the horizon in the middle of the screen. Score and target score at the top left, a timer and a "danger level" meter at the top right, and a target bracket around a tower. |
| I10 | [publisher page, screenshots 9–14][S4] | Arcade Mode: "WAVE 8 INCOMING" over a row of enemy icons, "COMBO 1.4x" and "COUNTER 2.4x" multipliers, and floating score pops. A night city with a road at the bottom edge. |
| I11 | <https://kotaku.com/app/uploads/2020/05/g7rtra5mpb2w8vnyaolv.jpg> | A segmented sea-serpent boss looping out of and back into the sea among rock stacks. **This is the clearest case of a boss using the surface.** |
| I12 | <https://kotaku.com/app/uploads/2020/05/aqhk0kslfzov8qbntvub.jpg> | Over a city: an "!" "SAFE" sigil (the counterpart of DANGER), with off-screen chevrons stacked on both edges. |
| I13 | <https://kotaku.com/app/uploads/2020/05/t9ugzvivgtjteadu3ux3.jpg> | Twin boss health bars for a two-jet rival fight over farmland. |

## 1. World layout

- **There is a floor, and it kills.** Players describe "the kill plane of the sea" and dying when a dash "veers down" into it [S10]. One review says the starting jet has "safeties that prevent you from flying into the ocean", which you can trade away for stronger gear [S6]. A player says an add-on will "automatically break & reorient you if you're about to hit water or ground at the bottom of the screen" [S9]. The module list names it **Emergency Stall Mod** [S12].
- **The floor changes per mission:** sea (I4, I6, I11), desert (I1), farmland (I9), city rooftops and roads (I7, I8, I10) _(inferred from screenshots)_.
- **Ground units live on the floor.** Tanks and boats crowd the bottom and leave "razor thin margins near the bottom of the screen" [S10]. One mission is literally "Destroy enemy ships" (I3), and I7 shows a tank convoy on a road.
- **Even the AI has to respect the floor.** Patch 1.0.26 fixed "hacker jets would dive into the ground" [S11].
- **Skimming is rewarded with feel, not rules.** Boosting just above the water throws up a water effect "the player feels" [S7]. No source describes a scoring bonus for flying low, and none mentions bouncing off the floor.
- **Ceiling:** no source mentions one. Developer posts reportedly talk of zipping around "with no physical borders" [S14] (quoted by a search summary; not confirmed on the page). The screenshots show open sky above. _(Inferred: no hard ceiling.)_
- **Horizontal bounds:** not documented. One review says "each stage's screen borders open at the start" as a visual flourish [S7]. Nothing suggests wrapping.
- **Camera:** in every in-flight screenshot the horizon sits between 50% and 65% of the screen height. Below it a perspective ground plane recedes, with the 2D fight played in front (I1, I4, I6, I9). _(Inferred: the camera frames the floor as a band in the lower third or so and rarely lets it leave the screen.)_

## 2. Level and mission structure

- **Missions ("OPs")** are numbered and picked from a 3D overworld. You sail a hovercraft carrier there, and some areas unlock only with carrier parts [S5][S7] (I3).
- **Mission types** [S5][S7][S8]:
  - destroy all targets;
  - free dogfights;
  - defend or escort allies;
  - hack towers by staying in range, "basically king of the hill";
  - stealth with limited weapons;
  - reach a target score inside a time limit;
  - bullet-hell stages later on.
- **Ground versus air targets:** both exist. There are ships, tanks and towers (I3, I7, I9) besides jets, robots and drones.
- **Bosses** come every few missions and are the reviewers' favourite part [S5][S6].
- **Ending and progression:** each mission gives a letter rank up to ACE and S+ (I3, I5) [S9]. Players can "just do the objective(s)", while speed and taking no damage earn the top rank [S9]. Progression comes from new parts every few stages, not from XP [S7].
- **Criticism** [S5][S8]: it "gets repetitive after a while", and the timed score missions annoy reviewers because enemies spawn unpredictably.

## 3. Visual language

- **Palette:** saturated, bright "80s Japanese City Pop album art" skies [S6]: azure noon, pink-gold sunset, deep-blue dusk (I4–I6, I9).
- **Readability:** "craft are kept small and backgrounds sparse" [S5].
- **Parallax:** a 3D perspective floor and horizon; mid-ground silhouettes (city skylines, sea stacks, giant hazy shapes); near-ground props such as rooftops and rock stacks (I4, I8, I11).
- **Contrails are the signature.** Every aircraft leaves a white dotted contrail, so flight paths read as curves across the sky (I4, I6, I9). Explosions are big, chunky and coloured (I6, I8).
- **Speed:** the contrails, the scrolling perspective ground, and boost spray over the water [S7].
- **HUD:**
  - hearts for health, three by default [S8], sitting low in the centre;
  - two bracket gauges flanking the centre for thrust heat, power and the special ("a few lines in the middle of the screen show power, speed, and special abilities") [S7] (I4, I9);
  - the boss name and health bar at the top centre (I1, I5), doubled for the twin-jet fight (I13);
  - a DANGER or SAFE sigil when an enemy locks on [S6] (I1, I12);
  - off-screen enemies shown as icon chevrons stacked on the screen edges (I4, I12);
  - pink hex tiles crowding the screen edges at low health (I4, I6);
  - in Arcade, a wave preview row and combo and counter multipliers (I10).

## 4. Movement feel

- **360° inertial flight** with throttle on a trigger. The game is compared directly to Time Pilot [S5][S15].
- **Coasting:** you can turn 180° and fire backwards "while inertia carries you forward" [S6]. Toggling the thrust on and off makes turns manageable [S8]. Players call it "stalling and falling" [S9].
- **Afterburner:**
  - boosts you forward and "damage[s] whatever's immediately behind you" [S6];
  - overheats if overused, which leaves you "without acceleration or other moves tied to your boost" [S8];
  - has its own heat gauge [S8].
- **Evade:**
  - a barrel roll with about one second of invulnerability, "the most important feature" [S8];
  - "expertly-timed dodges momentarily doubl[e] your rate of fire" [S6];
  - a module swaps it for a linear dash that kills what it hits [S6][S8];
  - the accessibility options widen the "Evasion Window" [S16];
  - scoring has a "Counter" bonus for well-timed evades (I10) [S9][S12].
- **Floor interaction:** a crash, unless the Emergency Stall auto-recovery is equipped [S9][S10][S12].
- **Pain points players report:**
  - the dash's path can cross the sea;
  - the death plays at the post-dash position;
  - the "Dash hitbox is too wide. Evade hitbox too narrow." [S10]

## 5. Enemies and bosses

- **Enemies:** pilots and jets, drones, hacker jets, bombers, tanks and boats [S10][S11]. Some enemies switch into an "engaged state when hit" [S10].
- **Bosses** with distinct strategies [S6]:
  - a giant floating eye-orb;
  - a mechanical sea serpent;
  - giant robot spiders;
  - a mirror match against two agile rival jets.
- **Named bosses** in the sources include EMPRESS (I1), TOWER (I5) and STERN REBUKE, which has a rotating laser [S11].
- **Bosses use the floor:**
  - the sea serpent dives through the sea surface and loops out of it (I11);
  - the spider's legs plant into the desert floor and arc over the player (I1);
  - TOWER's coils loop over the city line (I5).
- **Every fight escalates** to a "devastating attack" that is hard to avoid [S8].

## Mechanics to take, and what must not be copied

**Free to be inspired by.** These are game mechanics and level-design ideas, not protected expression:

- a lethal or punishing floor, with an optional assist;
- ground targets that pin you low;
- a dodge with i-frames that rewards perfect timing;
- a boost with heat;
- bosses that use the surface;
- contrails for readability;
- a lock-on warning;
- edge damage warnings;
- per-level ranks.

**Must not be copied.** Mecha Fighter stays original:

- Jet Lancer's art: its pixel sprites, its exact city-pop palette, the hex damage pattern, the skull "DANGER" sigil design, the bracket gauge layout and the loadout screen.
- Its names and characters: Ash Leguinn, Lem the cat, Root City, LANCE, EMPRESS, TOWER, STERN REBUKE and the "OP NN" mission names.
- Its music and SFX, and its specific boss designs: the tentacle spider, the segmented sea serpent and the coil tower. "A boss emerges from the sea" is a fine idea; a segmented red-and-black serpent is theirs.
- **Flag:** Mecha Fighter's Level 5 boss is called **Crimson Lancer**, and its moves include "charge lances". Now that the design is openly inspired by _Jet Lancer_, that name reads as derivative. Renaming it is cheap, for example to _Crimson Rival_ or _Vermilion Ace_. That is the owner's call.

## Ranked recommendations

The size scale: **S** is under a day, **M** is one to three days, **L** is a multi-PR feature.

### 1. The Deck (headline) — size L

**Why it fits.** The Deck gives Mecha Fighter's empty, unbounded sky a floor. That creates the altitude tension the sources praise, with "razor thin margins near the bottom". It also adds a horizon, which makes the side view read as a place, and it gives each Level a stronger identity than a sky gradient does. Gravity shots fall onto it, so it doubles as a visible place for shots to land.

**How it maps.**

- **Level data.** Add a `deck` block to `levels/level_N.json` and `schemas/level.schema.json`:

  ```json
  "deck": {
    "kind": "sea",
    "height": -12,
    "skim_band": 1.5,
    "slam_speed": 0.55,
    "slam_damage": 20,
    "restitution": 0.45,
    "swell": { "amplitude": 0, "period": 0 }
  }
  ```

  - `kind` is one of `sea`, `carrier`, `ground`, `cloud`, `hull` or `none`.
  - `height` is a world y in units.
  - `slam_speed` is a share of `MechTuning.speed`.
  - `slam_damage` is the slam's Armor damage, added to the spec's damage table.

  `LevelDefinition` parses it, and the existing test_level_data suite covers it.
- **Pure rules.** A `DeckRules` (RefCounted, headless-tested, like `FlightModel`) decides what a contact means:
  - **Skim:** the mech is inside `skim_band` above the surface. No damage, plus spray, a booster wash and a light rumble.
  - **Touch:** the mech reaches the surface moving down slower than `slam_speed`. It is held at the surface (the "boosters catch it" ground effect) and the downward velocity is removed. Idle coasting must never hurt: `coast_terminal_fall` (6 u/s) sits below the slam speed.
  - **Slam:** the mech reaches the surface faster than `slam_speed`. It takes `slam_damage` Armor through the existing hit path: 0.6 s of invulnerability, knockback and camera shake. It also bounces with `restitution`.

  Test the contact on the **swept path** (the previous to the next position), not only the end point. That avoids Jet Lancer's "died after the dash" complaint [S10].

  The default is a damaging bounce, not instant death. Mecha Fighter already has Armor 100 plus lives, and pillar 3 ("the player always knows what to do") argues against a silent kill plane. A `deck_guard` setting can add an auto pull-up as an accessibility assist, playing the Emergency Stall's role.
- **Events.** Add `player.deck_skimmed(position)`, `player.deck_slammed(position, damage)` and `world.shot_splashed(position, kind)`. Add a `DamageSource.DECK` and a `DestroyCause.DECK`. These follow the `events.gd` channels. The rules announce them; the game code never decides them (#97).
- **Projectiles.** Player, enemy and boss shots that reach the deck end there with a splash (`Ballistics` plus the shot pools). The deck soaks up shots that miss low, so low altitude is safe from below but exposed from above. That suits arcing fire.
- **Enemies.**
  - `EnemySteering` gets a floor-avoidance term. Jet Lancer shipped exactly this bug [S11]; add a regression test that no enemy kind enters the deck under steering alone.
  - An enemy that does strike the deck, for example a Fighter pulled into a swoop by the player, dies and scores a **Lure kill**, which feeds the Combo.
  - `SpawnDirector` must reject spawn points below `height + margin`. Today it spawns on a ring of radius 25 around the player, so the lower half of the ring would be underwater.
- **Play Sphere.** Keep it as it is. Unbounded horizontally, as now (the cloud field already wraps). No ceiling.
- **Camera framing.**
  - `CameraRig` sits 34 units from the plane with a 60° FOV, so half the visible height is about 34 × tan 30° ≈ 19.6 units in landscape.
  - Clamp the follow focus so the deck line never rises above **25% from the bottom of the screen**: `focus.y >= deck.height + 0.5 * half_height`, which is about 9.8 units in landscape. Compute it from the live half extents so portrait works too.
  - Near the deck, the mech then drops below the dead zone instead of the camera dipping underwater.
  - Fold this into #104, the hard safe frame, as the lower bound of the same clamp.
- **Render.** A large 3D plane at `deck.height` extending into -Z. Perspective then gives a real horizon line and scrolling ground parallax for free, which is Jet Lancer's look (I1, I6, I9) done in our own 2.5D way.

**Risks.**

- **Camping on the deck.** The deck must not be a safe floor. Counter it with deck threats, both from Level design (idea 3) and from Bomber carpets.
- **Feel tuning:** the touch, skim and slam thresholds.
- **The camera clamp against #104's safe frame;** they need one owner.
- **Draw calls for the plane and its spray particles,** against the 30-enemy budget.
- **Content load:** six deck looks for the visual pass (#27).

### 2. Evade with a perfect-timing reward — size M

**Why it fits.** This is the move reviewers call "the most important feature" [S8]. Mecha Fighter has no defensive verb besides moving, and every one of its attacks is already telegraphed 0.4 s ahead. That telegraph is exactly the cue a timed dodge needs.

**How it maps.**

- **The move.** A new `PilotIntent` action, `evade`: about 0.35 s of invulnerability through the existing `InvulnerabilityWindow`, a short burst along the stick, and a spin of the limbs and boosters on the spring rig.
- **Perfect evade.** When an enemy shot would have hit during the window, announce `player.evade_perfect` and apply:
  - **Overdrive:** about 2 s of `fire_interval` × 0.5;
  - plus 1 to the Combo multiplier, or a separate "Counter" tally on the Level Clear.
- **Cooldown** of about 0.8 s, shown on the mech itself rather than in a new HUD bar (pillar 2).
- **Input.** A gamepad face button or bumper, Shift on the keyboard, and the right mouse button. On touch, a double-tap on the left half, or a small button.
- **Settings.** Add an "Evade window" accessibility slider, as in Jet Lancer [S16].
- **Docs.** The How to Play guide (#75) gets a page.

**Risks.**

- **Touch:** the left half currently only moves, by spec.
- **Balance against Armor and the 0.6 s hit invulnerability.**
- **Hitbox fairness.** Players complained about Jet Lancer's [S10], so test the window boundaries headlessly.
- **Spec change.** It adds a control row to #73.

### 3. Threats on the Deck (ground targets) — size M per kind

**Why it fits.** The Deck needs reasons to fly low, and dangers that punish you for staying low. Gravity shots are naturally good at lobbing onto ground targets, so this plays to Mecha Fighter's one unique mechanic better than anything in Jet Lancer.

**How it maps.** New `EnemyKind`s that move along the deck, each with an `EnemyProfile` and a roster entry gated by `min_kills`:

- **Gunboat** on sea decks: it fires telegraphed arcing flak upward.
- **Deck turret** on the carrier and hull: stationary.
- **AA crawler** on ground decks.

The off-screen indicators already handle them. Give deck units a distinct arrow tint or icon so "below you" reads at a glance.

**Risks.**

- Scope.
- Intel entries and Schema enums.
- Deck units can't leave the Play Sphere vertically, so check that they despawn correctly as the player flies away.

### 4. Bosses that use the Deck — size S to M each, on top of #74

These are original mechanics on the existing bosses, with no Jet Lancer designs:

- **Albatross (Dawn):** low passes skimming the sea. Its shells raise splash columns that linger 0.5 s as hazards.
- **Thunderhead (Storm):**
  - its bomb carpets detonate on the waves as a moving wall of water spouts, telegraphed by shadows on the sea;
  - phase 2 adds lightning strikes onto the deck, telegraphed by a glow on the water.
- **Leviathan (Night):** it becomes a **surface carrier sitting on the deck**, not an airship. Its launch bays are on the flight deck, so the player must come low through searchlight sweeps to hit them, then the core opens. This matches the spec ("launch bays destroyed, then core exposed") and is the strongest deck-boss pairing.
- **Crimson Lancer, or its renamed successor (Stratosphere):** dives into the cloud deck and bursts out elsewhere. The cloud surface bulging and glowing for 0.4 s telegraphs the exit.
- **Ascendant (Orbit):** the mothership's upper hull **is** the deck for the boss fight. The shield nodes are deck targets in phase 1, then the hull cracks open to show the core.

**Risks.** Boss patterns need deck awareness through `BossPattern` and the arena. Each boss's deck interplay needs a headless pattern test.

### 5. Boost with heat — size M

**Why it fits.** It gives the existing booster flames and vapor cones a real mechanic: speed on demand, with a cost. A **backblast** that damages enemies right behind the mech, as in Jet Lancer [S6], also answers Time Pilot's classic "enemy on your tail".

**How it maps.**

- **Rules.** `FlightModel` gets a boost multiplier, plus `MechTuning` values for `boost_speed`, `heat_per_s`, `cool_per_s` and `overheat_lockout`. A pure `BoostHeat` rule tracks the heat.
- **Feedback.** `MechFeedback` scales the flame and vapor cone with it.
- **Overheat** disables the boost and the evade for about 1.5 s [S8].
- **Heat display.** Shown as the booster glow colour on the mech, not as a HUD bar.

**Risks.**

- Input count, with two new verbs (ideas 2 and 5).
- Touch mapping: the boost could be "push the stick to the rim", needing no new button.

### 6. Contrails for readability — size S

**Why it fits.** Mecha Fighter's pillar 2 is "readable at a glance". Jet Lancer's single clearest readability device is a contrail behind every craft, which turns flight paths into readable curves (I4, I9).

**How it maps.** Give `EnemyLook` and the mech a pooled ribbon or dotted trail. The colour differs from shot glows, so trails are never mistaken for bullets. Respect the reduced-motion setting.

**Risks.**

- Draw calls with 30 enemies; use one `MultiMesh` or a ribbon per enemy, capped.
- Our style must differ: solid tapered ribbons rather than Jet Lancer's white dot chains.

### 7. Lock-on warning and edge damage — size S

**How it maps.**

- **Lock-on warning.** When any telegraph is aimed at the player (the 0.4 s glow), show a small warning glyph above the mech and play a two-tone chirp. Listen to the existing telegraph signals.
- **Edge damage.** Extend the existing damage vignette with an original pattern that crowds the screen edges as Armor falls, instead of a flat tint.
- **Original art:** no skull-in-diamond, no hex tiles.

**Risks.** Clutter on phones; test at 360 px.

### 8. Deck spray and the low-altitude score bonus — size S, after idea 1

**How it maps.**

- **Skim bonus.** While skimming, kills score a **Skim bonus**, for example +25%, shown as a pop.
- **Spray.** The spray particles and a water-wake decal show the band.
- **Rewarding the risk.** This turns the Deck from a hazard into a risk-and-reward line, which Jet Lancer only does through feel [S7].

**Risks.** Scoring changes need #73's scoring table and tests updated.

### 9. Per-Level rank on Level Clear — size S

**How it maps.** A letter grade (C to S) computed from the tally the Level Clear already shows: kills, accuracy, armor bonus and no-death bonus. This echoes Jet Lancer's mission ranks (I3, I5) without the mission system.

**Risks.** None beyond the tests and the Scoreboard schema, if the rank is stored.

### 10. Not recommended for 1.0

- **Mission variety** (escort, hacking towers, stealth, timed score). It conflicts with pillar 1 ("arcade-pure ... Time Pilot's loop"), and reviewers found it the weakest part of Jet Lancer [S5][S8]. Revisit it as optional "Challenge Levels" after 1.0.
- **The loadout and modules system, the overworld carrier hub, and the story.** They're large, and they're Jet Lancer's identity, not Time Pilot's.
- **The Arcade wave-preview row** (I10). The Boss Gauge already says "how far to the boss". A wave preview adds HUD clutter for little gain.

## Deck designs per Level

| # | Level | Deck | Height | Contact rule | Deck threats and props | Boss interplay |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Dawn Patrol | **Calm sea at sunrise**: pink-gold reflections, gentle swell. | -12 | Standard skim, touch and slam. The tutorial adds a prompt: "Stay above the waves". | None in the early Skirmish, so the player learns the deck. Distant sea stacks for parallax, our own shapes. | Albatross skims low; its shells raise splash columns. |
| 2 | Storm Front | **Rough sea**: dark, with whitecaps and rain hitting the water. | -12, with a swell of ±0.8 u over a 4 s period | Swell changes the effective height, telegraphed by the wave crests. Slam damage +5. | Lightning strikes the water, with a 0.4 s glow on the surface. | Thunderhead's carpet bombs become water-spout walls. |
| 3 | Sunset Strike | **Friendly carrier group on a gold sea**: the Level Intro launches the mech off a catapult deck, then the carrier falls behind. | -12 sea, with solid carrier slabs at -10 | The carrier deck is solid and allows a touch, but no repair, to prevent camping. The sea is standard. | Enemy fast boats fire flak. | Hornet's dash attacks strafe the carrier; protecting it is flavour only. |
| 4 | Night Raid | **Black sea with an enemy carrier group**: searchlights sweep up from the decks. | -12 | Standard. Searchlights don't hurt; while lit, enemies aim 25% better. | Deck turrets and gunboats; searchlight towers. | **Leviathan sits on the sea.** Its launch bays are deck targets, then the core is exposed. |
| 5 | Stratosphere | **Cloud tops**: a soft, violet-lit cloud sea. | -10 | A **soft deck**: no slam damage. Inside the cloud, drag rises 2×, the mech is hidden from enemy aim, and the player can't see out. Sinking 4 u below the surface counts as a slam. | Cloud towers as parallax; Bombers fly just above the tops. | The rival ace dives into the cloud and bursts out, telegraphed by the bulge. |
| 6 | Edge of Orbit | **No deck in the Skirmish**: Earth's curve far below as backdrop only. The absence is the escalation, with nowhere to skim. | none | `kind: none`; the camera clamp is off. | — | **Ascendant's hull becomes the deck** when it arrives: shield nodes on the hull, and the camera clamp switches on to the hull line. |

A shared rule for every Level: the deck height stays well below the spawn point, so the Level Intro never starts within one screen of the deck. A respawn always happens above the skim band.

## Suggested next steps

1. Owner decisions. Is the Deck damaging-bounce or kill-plane? The recommendation is damaging bounce plus an optional guard. Should Crimson Lancer be renamed? Is Evade in 1.0?
2. Amend issue #73 with the `deck` block, the slam damage row, the new Events and, if accepted, Evade.
3. One build issue per idea, in rank order. Idea 1 depends on #104 (the camera) and the visual pass (#27); ideas 3, 4 and 8 depend on idea 1.
4. Add **Deck** to `GLOSSARY.md` ("the surface at the bottom of a Level's world: sea, carrier, ground, cloud or hull; contact can skim, touch or slam"). Avoid "floor" and "ground" as general terms, because ground is one kind of deck.

## Sources

- [S1] Steam store page: <https://store.steampowered.com/app/913060/Jet_Lancer/>
- [S2] Nintendo eShop page: <https://www.nintendo.com/us/store/products/jet-lancer-switch/>
- [S3] itch.io page, Armor Games Studios: <https://armor-games-studios.itch.io/jet-lancer>
- [S4] Publisher page, with the press kit and screenshots: <https://armorgamesstudios.com/games/jet-lancer> (press kit: <https://presskits.armorgamesstudios.com/jet-lancer.zip>)
- [S5] Nintendo Life review: <https://www.nintendolife.com/reviews/switch-eshop/jet_lancer1>
- [S6] Kotaku, "Jet Lancer Is A Stylish Fighter Pilot Game With Great Boss Fights": <https://kotaku.com/jet-lancer-is-a-stylish-fighter-pilot-game-with-great-b-1843540367>
- [S7] MyGamer review (Switch): <https://www.mygamer.com/jet-lancer-switch-review/>
- [S8] Noisy Pixel review: <https://noisypixel.net/jet-lancer-review-switch-pc/>
- [S9] ResetEra community thread (player reports; lower trust, used only for floor and assist behaviour, corroborated by [S6] and [S10]): <https://www.resetera.com/threads/jet-lancer-is-a-fantastic-indie-ace-combat-spiritual-successor-to-luftrausers-and-no-ones-talking-about-it.335106/>
- [S10] Steam Community discussion, with a developer reply in the thread: <https://steamcommunity.com/app/913060/discussions/0/4138312502516295317/>
- [S11] Official patch notes v1.0.26: <https://armor-games-studios.itch.io/jet-lancer/devlog/146613/patch-notes-v-1026>
- [S12] Guide index naming the modules and scoring bonuses: <https://steamah.com/jet-lancer-the-ultimate-guide/>
- [S13] Developer background and the working title: <https://www.gamespress.com/High-velocity-arcade-shooter-Jet-Lancer-out-now-on-PC-Switch>
- [S14] Steam developer announcements: <https://steamcommunity.com/app/913060/allnews/>
- [S15] God is a Geek review (via search summary; the page refused automated fetches): <https://www.godisageek.com/reviews/jet-lancer-review/>
- [S16] "Jet Lancer's Accessibility Options", developer post, 19 Feb 2020: <https://store.steampowered.com/news/posts/?feed=steam_community_announcements&appids=913060&appgroupname=Jet+Lancer&enddate=1586182409>

Gaps: no developer interview or GDC talk on the camera or world bounds turned up. A NintenDomain podcast interview with the designer exists (May 2020) but wasn't transcribed. Ceiling and horizontal-bound behaviour are therefore inferred from screenshots and from the absence of reports.
