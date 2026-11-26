# Unity game behaviour: parity spec for the Godot port

Research for [#5](https://github.com/aallbrig/mechapilot/issues/5) (map: [#1](https://github.com/aallbrig/mechapilot/issues/1)).
Read on 2026-11-26 from commit `f1f01d6` of `unity/mecha-pilot` (Unity 2021.3.13f1). Packages that
matter: Input System 1.4.3, Cinemachine 2.8.9, Timeline 1.6.4, URP 12.1.7, TextMeshPro 3.0.6,
Fluid Behavior Tree 2.2.3, Fluid State Machine 2.0.1.

**Sources.** Everything below comes from the C# in `Assets/Scripts`, and the tuned values come from the
serialized YAML in `Assets/Scenes/Game.unity`, `Assets/Prefabs/*.prefab`,
`Assets/InputActions/PlayerInput.inputactions`, `Assets/Scripts/Timelines/Level Opening.playable`, and
`ProjectSettings/*.asset`. Where the scene overrides a script default, the **scene/prefab value is
the one that ships** and is the one listed. In the citations below, `A/` means `unity/mecha-pilot/Assets/`.
Nothing here was checked by running the game. Items marked **(verify)** are inferred from code and engine
semantics. Confirm them by playing the production build before treating them as hard requirements.

Vocabulary follows `GLOSSARY.md`: **Game State** (Menu, Gameplay, Game Over, Scoreboard), **Game
Event**, **Play Sphere**, **Scoreboard**.

## Short answer

Mecha Fighter is a single-scene, twin-stick, Time Pilot-style shooter played in a 2D plane (Unity XY at
z = 0), viewed by a perspective camera 22 units away. A player-centred **Play Sphere** (radius 40)
despawns enemies that fall too far behind. One enemy type chases the player and kills on contact. One
player shot kills an enemy and scores +100. A "beginner" spawner ramps up the number of enemies on screen
and how often they spawn as kills accumulate. When the player dies, a 2 s delay leads to Game Over, where the
player enters 3-letter initials. The run is saved to a local **Scoreboard** in PlayerPrefs (`MF_Scores`,
JSON). There is no boss yet. A "kills until boss" bar (30) fills but nothing is wired to it.

## 1. Game State machine

Source: `A/Scripts/GamePlay/GameManager.cs`, `GameStateTransitionReactor` instances in `Game.unity`.

| # | Parity item (testable) | Value / source |
| - | - | - |
| GS-1 | The game boots into **Menu**. | `startingGameState: 0` |
| GS-2 | Menu → **Gameplay** on the "Play" button. | `Play Button.onClick → GameManager.PlayGame` |
| GS-3 | Menu → **Scoreboard** on the "Scores" button. | `Score Board Button.onClick → GameManager.ScoreBoard` |
| GS-4 | Scoreboard → Menu on the "Back" button. | `Main Menu Button.onClick → GameManager.Menu` |
| GS-5 | Gameplay → **Game Over** happens automatically, **2.0 s after the player dies** (strictly `>`, polled every frame). | `secondsBeforeTransitionToGameOver: 2` |
| GS-6 | Game Over → Menu on the "Play Again" button. It **saves the run first**, then goes to **Menu**, not straight back into Gameplay. | `Reset Button.onClick → ScoreManager.SaveScore, GameManager.Menu` |
| GS-7 | There are no other transitions: no pause, no quit, no Cancel/Escape handling. | — |
| GS-8 | Each state change emits *exited(old)* then *entered(new)*. Leaving Game Over also emits a separate "game is over" event (used to stop the spawner). | `GameManagerStateExited/Entered`, `GameIsOver` |

What each state turns on and off (all from `GameStateTransitionReactor` onEnter/onExit in `Game.unity`):

| State | On enter | On exit |
| - | - | - |
| Menu | Show Menu UI. Hide Gameplay UI, Game Over UI, Scoreboard UI and the score HUD. | — |
| Gameplay | Show Gameplay UI and score HUD. Activate player and Play Sphere. Reset the run score (score = 0, startTime = now, date = today). Play the Level Opening timeline. | Player position → (0,0,0). Deactivate player and Play Sphere. Release all enemy indicators. |
| Game Over | Show Game Over UI. Select the first initial letter. | Emit "game is over": deactivate the enemy spawner. |
| Scoreboard | Show the Scoreboard UI (rebuilt from saved scores each time). Select "Back". Hide the score HUD. | Re-show the score HUD (then Menu hides it again). |

Focus defaults (`AutomaticSelectableSelector`): Menu selects **Play**, Scoreboard selects **Back**,
Game Over selects **First Letter**.

## 2. Level intro (Timeline signals)

Source: `A/Scripts/Timelines/Level Opening.playable`, the `Directors` PlayableDirector and SignalReceiver in `Game.unity`.

| # | Parity item | Value |
| - | - | - |
| IN-1 | When Gameplay is entered, the Level Opening timeline starts (game time, wrap mode None). | `PlayableDirector.Play` from the Gameplay onEnter |
| IN-2 | At t = 0 s the signal **Level Intro Started** fires: show the "Level Start" text and deactivate the enemy spawner. | Signal Emitter `m_Time: 0` |
| IN-3 | At t = 2 s the signal **Level Intro Completed** fires: hide the "Level Start" text and activate the enemy spawner. | Signal Emitter `m_Time: 2` |
| IN-4 | So no enemy can spawn during the first 2 s of a run, and the player can already move and shoot during the intro. | — |
| IN-5 | The first enemy spawns **immediately** when the spawner activates at t = 2 s (see SP-6). **(verify)** | — |

Two other SignalReceivers (on `User Interface Container` and `Spawners Container`) listen for the same
signals, but the timeline only notifies the `Directors` object. They never fire (see Oddities).

## 3. Controls

Source: `A/InputActions/PlayerInput.inputactions`. The scene's `Player Input` component uses
*Invoke Unity Events* and sends `Move` → `PlayerController.HandleMovement` and `Fire` →
`PlayerController.HandleFireWeaponCommand`. Both actions are `Value`/`Vector2`, and their started, performed and canceled callbacks all go to the handler.

### Gameplay (twin-stick: move and aim are independent)

| Device | Move | Fire / aim (8-way or analog) |
| - | - | - |
| Keyboard | W A S D **and** arrow keys (2D composite, digital-normalized: diagonals have magnitude 1) | **I J K L** (2D composite) |
| Gamepad | Left stick, D-pad | Right stick |
| Generic joystick | `<Joystick>/stick` | — |
| XR | `<XRController>/{Primary2DAxis}` | — |
| Touch | On-screen stick, bottom-left, drives `<Gamepad>/leftStick`, movement range **50 px** | On-screen stick, bottom-right, drives `<Gamepad>/rightStick`, movement range **72 px** |
| Mouse | — (no mouse aim, no click-to-fire) | — |

- CT-1: Holding any Fire direction fires repeatedly toward it (see Combat). Releasing stops firing. There is no separate fire button.
- CT-2: The on-screen sticks are visible during Gameplay **on every platform**, desktop included. Layout: canvas reference resolution **860×540**, *Scale With Screen Size*, match 0.32. Left group anchored bottom-left at (128, 160), right group bottom-right at (−128, 160). Background 192×192, handle 96×96.
- CT-3: Helper labels "Move" and "Attack" sit above the sticks, plus a "Joystick" label under each. They disappear **10 s** after the Gameplay UI first becomes active (see Oddities: they only do this once per page load).
- CT-4: The Touch control scheme lists Touchscreen plus optional Gamepad, Keyboard, Pointer and Mouse (the "Touchscreen issue resolved" commit `f53f171` added Pointer and Mouse). Parity requirement: on a touch device, the on-screen sticks work and scheme switching never strands input.

### UI (menus, Scoreboard, Game Over)

- UI Navigate: gamepad left stick, right stick and D-pad, joystick stick, keyboard WASD and arrows. Submit: `*/{Submit}` (Enter, gamepad South). Cancel: `*/{Cancel}` (Escape, gamepad East), which **does nothing**. Point and Click: mouse, pen, touch.
- Buttons use navigation mode Automatic (menu) or Explicit (Game Over).

### Initials entry (Game Over)

Source: `A/Scripts/UI/InitialLetterInput.cs`, `InitialLetterInputForm.cs`, the `Initials Input` children in the scene.

| # | Parity item | Value |
| - | - | - |
| IE-1 | There are three letter slots. Each starts as **"A"**, holds 1 character and is read-only (no typing). | `m_CharacterLimit: 1`, `m_ReadOnly: 1`, `m_Text: A` |
| IE-2 | The alphabet is `ABCDEFGHIJKLMNOPQRSTUVWXYZ` plus **space** (27 symbols) and wraps. | `Alphabet` |
| IE-3 | While a slot is selected, **Move down** goes to the *next* letter (A→B … Z→space→A) and **Move up** goes to the *previous* letter (A→space→Z). This is the reverse of the usual arcade convention. Keep it for parity or flag it as a deliberate change. | `HandleUINavigate` |
| IE-4 | Changing a letter only happens when the Move value is **exactly** (0, ±1): keyboard, D-pad, on-screen buttons. An analog stick that isn't fully vertical does nothing. | `input == Vector2.up` |
| IE-5 | Left and right move between slots: First ↔ Second ↔ Third → "Play Again". From Play Again, Up or Left goes back to Third. | Explicit navigation |
| IE-6 | On touch, the Game Over screen shows a 4-button on-screen D-pad (bottom-left, 64×64 each) that drives Move. | `OnScreenButton` Up=`leftStick/up`, Down=`dpad/down`, Left=`dpad/left`, Right=`leftStick/right` |
| IE-7 | The saved initials are the three slot texts joined together (default `"AAA"`). Spaces are allowed. | `GetInitials` |

## 4. Player movement

Source: `A/Scripts/Player/PlayerController.cs`, `A/Prefabs/Player Character.prefab`.

| # | Parity item | Value |
| - | - | - |
| PM-1 | Top speed is **10 u/s**, scaled by input magnitude (an analog stick at half tilt gives 5 u/s). | `speed: 10` |
| PM-2 | **The player never stops.** When Move is released, the mech keeps drifting in the last input direction at **0.3 × speed = 3 u/s**. | `LastMoveInput = MoveInput.normalized * 0.3f` |
| PM-3 | When a run starts, the player spawns at the origin already moving **screen-up at 5 u/s** (and is facing up). | `initialMovementVector: {x: 0, y: 0.5}` |
| PM-4 | Movement stays in the play plane (z = 0) with no gravity and no acceleration or smoothing: velocity changes instantly. | `CharacterController.Move(PlayerMoveVector * dt)` |
| PM-5 | The mech turns instantly to face its movement direction (or its last direction while coasting). | `Quaternion.LookRotation` |
| PM-6 | Screen-right input moves the mech screen-right. (Unity negates input x because the camera looks down −Z. A Godot camera setup won't need that.) | `new Vector2(-x, y)` |
| PM-7 | Nothing stops the player at the edge of the Play Sphere. The sphere follows the player, so the world is effectively infinite. | — |
| PM-8 | Collision volume: CharacterController radius 0.75, height 1.5, plus a BoxCollider of 1×1×1.5. | prefab |

## 5. Camera

Source: `Game.unity` (`Main Camera`, `Player vcam`), `A/Scripts/Cameras/CameraAdjustsToOrientation.cs`.

| # | Parity item | Value |
| - | - | - |
| CA-1 | A perspective camera with **60° vertical FOV**, near 0.3, far 100. | Camera and vcam lens |
| CA-2 | It follows the player with a world-space offset of **22 units** straight out of the play plane (landscape). It looks straight at the plane and never rotates. | Transposer `m_BindingMode: 4` (WorldSpace), `m_FollowOffset: {0,0,22}` |
| CA-3 | Follow damping is **1** on x, y and z (Cinemachine damping, roughly a 1 s lag). | `m_XDamping/YDamping/ZDamping: 1` |
| CA-4 | In portrait orientation the offset becomes (0, −2, 32): further away and shifted down. It switches back on rotation. On WebGL `Screen.orientation` may never report portrait, so this may never trigger in production. **(verify)** | `portraitFollowOffset`, `landscapeFollowOffset` |
| CA-5 | Visible area at landscape 16:9: about 25.4 u tall and 45 u wide (±12.7 × ±22.6). Enemies spawn 25 u from the player, which is **just off-screen** horizontally and well off-screen vertically. | derived |
| CA-6 | Clear colour is solid **RGB(0, 0.194, 0.5)** (deep blue). Linear fog from **20 to 100**, colour RGB(0.296, 0.344, 0.519). | Camera, RenderSettings |
| CA-7 | One directional light: rotation (50°, 180°, 0), colour RGB(1, 0.957, 0.839), intensity 1, no shadows. | `Directional Light` |
| CA-8 | When the player respawns at the origin, the camera pans there with the same damping. | — |

## 6. Play Sphere

Source: `A/Scripts/GamePlay/PlaySphere.cs`, `A/Prefabs/Play Sphere.prefab`, scene override.

| # | Parity item | Value |
| - | - | - |
| PS-1 | The **Play Sphere** is a trigger sphere of **radius 40**, centred on and following the player. | `m_Radius: 40`, PositionConstraint source = player |
| PS-2 | An enemy that **leaves** the Play Sphere is despawned silently: no explosion, no sound, **no score**. Its indicator is removed. It frees a spawn slot. | `DeactivateWhenOutsidePlaySphere` |
| PS-3 | Only enemies react to the Play Sphere. Player shots don't (their lifetime caps them instead; see CB-4). | — |
| PS-4 | The Play Sphere is active only during Gameplay. | Player Container reactor |

## 7. Enemy spawning (Level 1 tuning)

Source: `A/Scripts/Spawners/*.cs`, the `Basic Enemy Spawner` in the scene.

| # | Parity item | Value |
| - | - | - |
| SP-1 | Spawn position: a random direction in the plane, at distance **radius − inset = 40 − 15 = 25** from the Play Sphere centre (the player). | `PositionOnSphereCollider.insetValue: 15` |
| SP-2 | **Concurrent cap**: `floor(limit)` live enemies. `limit` starts at **1.0** and grows by **+0.25 per enemy death**, so one more slot every 4 deaths. Nothing caps it. | `enemiesLimit: 1`, `amountToAddToEnemyCountPerKill: 0.25` |
| SP-3 | **Delay** between spawns is re-rolled after each spawn. While `buffer > 0` it is `U(0.1 + buffer, 0.8 + buffer)` s, otherwise `U(0.1, 0.8)` s. | `minDelayTimeInSeconds: 0.1`, `maxDelayTimeInSeconds: 0.8` |
| SP-4 | `buffer` starts at **4.0 s** and drops by **0.25 per enemy death**, so it reaches 0 after **16 deaths**. | `beginnerTimeBuffer: 4`, `bufferToDecreaseByPerKill: 0.25` |
| SP-5 | A spawn happens when `live < floor(limit)` **and** `now − lastSpawn > delay`. | `BeginnerRepeatSpawner.ShouldSpawn` |
| SP-6 | Counters (live, limit, buffer) reset each time the spawner activates (once per run, at intro end). The first spawn of a run is immediate. **(verify)** | `OnEnable` |
| SP-7 | "Death" here means **any** `Died`: shot down, crashed into the player, or crashed into another enemy. Leaving the Play Sphere or a player-death clear-out frees a slot but does **not** advance the ramp. | — |
| SP-8 | The enemy pool starts at 50 and grows as needed. A dead enemy isn't reused until 3 s after its death. | `poolCount: 50`, `ObjectPool` |
| SP-9 | When the player dies, every live enemy disappears at once (no explosion, no score). | `DeactivateOnPlayerDeath` |

## 8. Enemy AI and body ("Stage 1 Basic Enemy")

Source: `A/Scripts/OpposingForce/HostileAi.cs`, `A/Prefabs/Stage 1 Basic Enemy.prefab`.

| # | Parity item | Value |
| - | - | - |
| EN-1 | Speed is rolled once per spawn, uniform in **[6, 12] u/s**. | `minSpeed: 6`, `maxSpeed: 12` |
| EN-2 | Every frame it moves straight toward the player's current position (pure pursuit, no steering limit) and turns instantly to face the player. | `MoveTowards` and `LookAt` |
| EN-3 | It detects the player within 228 u (the Play Sphere radius is 40, so it always chases). It never stops short (`closeEnoughDistance: 0`). | prefab |
| EN-4 | Enemies never shoot. | — |
| EN-5 | Health **1**. | `maxHealth: 1` |
| EN-6 | **Any physical collision kills** the thing that collides (enemy↔player, enemy↔enemy). | `Health.OnCollisionEnter() => Damage(maxHealth)`. Layer matrix: everything collides with everything. |
| EN-7 | On death: explosion (see FX), **+100 score**, despawn. | `ScoreReward.scoreReward: 100`, `OnDiedTrigger` → SetActive(false) |
| EN-8 | Looks: three primitive cylinders (a body along its facing, plus a cross wing 2× wide), one yellow-orange jet trail and one white 1 s contrail. Colliders: box 1×1×2, box 4×1×1, capsule r 0.5 h 2. Physics layer "Bad Guys" (7). | prefab |
| EN-9 | Enemies vs. the world: there are no obstacles. The cloud layers' box colliders sit at z ≤ −4.5 and are never reached. | — |

## 9. Player weapon, projectiles and damage

Source: `PlayerController.Fire`, the `Projectile Particles` ParticleSystem in the player prefab, `DamageOnParticleCollision.cs`.

| # | Parity item | Value |
| - | - | - |
| CB-1 | Fire rate: at most one shot every **0.25 s** (4/s) while the Fire input is non-zero. The first shot is immediate. | `timeBetweenShotsInSeconds: 0.25` |
| CB-2 | Each shot spawns **one** projectile **3 u** from the player's centre in the aim direction, travelling straight along the aim direction at **24 u/s**. Player velocity isn't inherited. | `fireDirection.normalized * 3f`, particle `startSpeed: 24` |
| CB-3 | Projectile: a sphere of size 1, colour RGB(1, 0.964, 0.203) (yellow), with a very short trail (0.01 s). | `startSize: 1`, `startColor` |
| CB-4 | Lifetime **10 s** (so range is 240 u). It is not removed by the Play Sphere. | `startLifetime: 10` |
| CB-5 | A projectile is destroyed on its **first** collision with anything (`energyLossOnCollision: 1`) and deals **3 damage** to what it hits. Against 1-HP enemies, one shot kills. | `particleDamage: 3` |
| CB-6 | Each shot plays "Mecha Rifle Single" at volume **0.815** (2D). | `onWeaponFired → AudioSource.Play` |
| CB-7 | The visible gun arm swings toward the aim direction (constraint weight 0.4) and goes back to rest when not aiming. This is cosmetic. | Gun Position/Rotation constraints |
| CB-8 | Player health is **10**, but the only damage source is a collision, which deals full health. In practice: **one hit and the player is dead**. | `maxHealth: 10` |

## 10. Health, death and FX

| # | Parity item | Value |
| - | - | - |
| HD-1 | Health clamps at 0. On reaching 0 it emits *died* exactly once. It resets to max whenever the entity is (re)activated. | `Health.cs` |
| HD-2 | Player death: explosion at the player's position, player hidden, run end-time recorded, all enemies cleared, and Game Over 2 s later. **Crashing also kills the enemy, which scores +100.** | scene override on the player's `Health.onDied → ScoreManager.SetEndTime` |
| HD-3 | Explosion: a one-shot burst of **30–50** particles, lifetime 0.8 s, speed 12, size random 0.4–0.8, default particle material, plus "Explosion.wav" at volume **0.6** (2D). | `A/Prefabs/Explosion.prefab` |

## 11. Scoring and HUD

Source: `A/Scripts/Scoring/*.cs`.

| # | Parity item | Value |
| - | - | - |
| SC-1 | Score is an integer that starts at 0 on every Gameplay enter. | `ScoreManager.Reset` |
| SC-2 | The only source of points is **+100 per enemy death**, whatever the cause (shot, crash into the player, crash into another enemy). | `ScoreReward` |
| SC-3 | The HUD shows `Score: <n>`, top-centre (anchor top, y −24, 300×48, font size ≈34), and updates on every change. | `ScoreKeeper.beforeScoreText: 'Score:'` |
| SC-4 | Each score change carries `previous`, `updated` and `increase`. | `ScoreAddedResult` |
| SC-5 | Run time = time of player death − time Gameplay was entered (so it **includes the 2 s intro**). | `startTime`, `SetEndTime` |
| SC-6 | "Effort Until Boss" bar: a slider at bottom-centre (300×50), range 0–**30**, that fills by 1 per enemy death and clamps at 30. It resets every run. When it reaches 30 it fires an event **with no listeners**, so no boss exists. | `TrackerUntilBoss.enemiesBeforeBoss: 30` |

## 12. Off-screen (enemy) indicators

Source: `A/Scripts/GamePlay/Indicator.cs`, `IndicatorManager.cs`, `A/Prefabs/Enemy Indicator.prefab`.

| # | Parity item | Value |
| - | - | - |
| OI-1 | Every spawned enemy gets one indicator, **whether it is on-screen or off-screen**. The name "off-screen indicator" is aspirational. | `OnSpawnerSpawned → IndicatorManager.IndicatorFor` |
| OI-2 | The indicator is centred on the player and rotates to point at its enemy every frame. The arrow mesh sits about 2 u from the player, offset by local (−2, 0, 2). **(verify visually)** | LookAt and Position constraints |
| OI-3 | Look: four quads (URP Lit) forming an arrow/chevron, colour RGB(1, 0.971, 0) (yellow). | `A/Materials/Enemy Indicator.mat` |
| OI-4 | The indicator is removed the frame after its enemy deactivates for any reason. All indicators are cleared when Gameplay is exited. | `Indicator.Update`, `IndicatorManager.Reset` |

## 13. Scoreboard and save format

Source: `A/Scripts/Scoring/ScoreManager.cs`, `ScoreRecord.cs`, `ScoresTable.cs`, `ScoreTableRow.cs`, the row and header prefabs.

| # | Parity item | Value |
| - | - | - |
| SB-1 | A run is saved **only** when "Play Again" is pressed on Game Over. Closing the tab first loses the run. | `SaveScore` |
| SB-2 | Storage: PlayerPrefs key **`MF_Scores`**, a string of JSON (on WebGL this lives in browser IndexedDB). It loads once at startup. | `_saveKey = "MF_Scores"` |
| SB-3 | JSON shape: `{"scores":[{"score":int,"initials":"ABC","month":int,"day":int,"year":int,"startTime":float,"endTime":float}]}`. Times are seconds since app start. The date is the **local** date when the run started. | `ScoreSave`, `ScoreRecord` |
| SB-4 | The list is unbounded: every saved run is kept. Duplicate initials are fine. | — |
| SB-5 | Scoreboard screen: title "Score Board", then a header row **Initials, Score, Game Time, Date**, then one row per run **sorted by score descending**. Ties keep their insertion order (stable LINQ `OrderByDescending`). | `ScoresTable.RenderScores` |
| SB-6 | Row formatting: initials as-is. Score as an integer. Game Time is the **raw float seconds** (`endTime − startTime`, default C# float formatting, e.g. `37.48213`). Date is `M/D/YYYY` with no zero padding. | `ScoreTableRow.SyncScore` |
| SB-7 | With no saved runs the table shows the text **"No games have been played!"**. | — |
| SB-8 | Back button label "Back". | scene |

Migrating existing players' Unity PlayerPrefs into Godot isn't practical: the storage is
Emscripten IDBFS inside Unity's own file. The port should start with an empty Scoreboard, and the
`ScoreRecord` shape above is a reasonable starting schema for the storage interface.

## 14. UI copy and layout (all TextMeshPro, font LiberationSans SDF)

| Screen | Elements |
| - | - |
| Menu | Title **"Mecha Fighter"** (72 pt, top-centre). Buttons **"Play"** and **"Scores"** (48 pt, a 384×128 group at bottom-centre, y 128). Footer **"Tip: if experiencing audio issues ensure phone silent mode isn't enabled"** (24 pt, bottom stretch). Opaque background panel, RGB about (0.234, 0.279, 0.283). |
| Gameplay | `Score: n` (top-centre). "Level Start" (36 pt, centre, intro only). Twin sticks with labels "Move", "Attack" and "Joystick". Effort Until Boss slider (bottom-centre). |
| Game Over | Title **"Game Over"** (72 pt). **"Input Your Initials"** (36 pt). Three letter slots (36 pt). Button **"Play Again"** (≈55 pt, bottom-centre). On-screen D-pad (bottom-left). |
| Scoreboard | Title **"Score Board"** (48 pt). Table. **"Back"** button (36 pt). |

## 15. Audio

| Cue | Trigger | Clip | Volume |
| - | - | - | - |
| Rifle shot | Each player shot | `A/Audio/Mecha Rifle Single.wav` (0.115 s) | 0.815 |
| Explosion | Each enemy or player death | `A/Audio/Explosion.wav` (0.785 s) | 0.6 |
| — | none (unused) | `A/Audio/Laser_Shoot.wav` (only on the unused Bullet Projectile prefab) | — |
| — | none (unused) | `A/Audio/Jets.wav` (2.02 s, unreferenced) | — |

All audio is 2D (spatial blend 0). There is no music and no UI sounds. `AudioManager` restarts audio output
on mobile when the mute state changes to unmuted. The Godot port's equivalent is the usual "resume the
AudioContext on first user gesture" for the web.

## 16. Background

Source: `A/Scripts/Backgrounds/PrefabBackground.cs`, `BackgroundContainer.cs`, scene `Backgrounds`.

- BG-1: There are three static layers of cloud sprites behind the play plane (no scrolling; the parallax comes only from the perspective camera):

  | Layer | z (distance behind the plane) | Cell size | Clouds per cell |
  | - | - | - | - |
  | Clouds Foreground | −5 | 50×50 | 4 |
  | Clouds Background | −20 | 50×50 | 10 |
  | Clouds Background (1) | −60 | 100×100 | 4 |

- BG-2: The layers tile infinitely. Every **2 s**, each cell inside the camera frustum gets any missing
  4-neighbour cells generated, each filled with N clouds at random positions. Cells are never freed.
- BG-3: Cloud: `A/Sprites/Cloud.png` (256×256, 100 px/unit), scaled ×2, so about 5.12 u across, white, unlit sprite. The scene
  ships with 278 pre-placed cloud instances.
- BG-4: The fog (20 to 100) makes the far layers progressively hazier.

## 17. Game Events (implicit events today)

These behaviours are already event-shaped in Unity, through C# `event`s, UnityEvents or Timeline signals. They
are the natural candidates for the Godot global event bus. Payloads are what the Unity code passes today.

| Candidate Game Event | Unity source today | Current listeners |
| - | - | - |
| `game_state_entered(state)` / `game_state_exited(state)` | `GameManager.GameManagerStateEntered/Exited` | all `GameStateTransitionReactor`s (UI panels, player, Play Sphere, timeline, score reset, indicator reset) |
| `run_ended` / `game_over_left` (Unity: `GameIsOver`, fired on **exit** of Game Over) | `GameManager.GameIsOver` | `DeactivateOnGameOver` (spawner) |
| `level_intro_started` / `level_intro_completed` | Timeline signals at 0 s and 2 s | intro text, spawner on/off |
| `player_died(position)` | player `Health.Died` | GameManager (Game Over timer), ScoreManager.SetEndTime, enemies clear, explosion |
| `enemy_spawned(enemy)` | `Spawner.Spawned` | positioning, layer, parenting, indicator, boss tracker |
| `enemy_died(enemy, cause?)` | enemy `Health.Died` | score +100, spawner ramp, boss tracker, explosion |
| `enemy_left_play_sphere(enemy)` | `DeactivateWhenOutsidePlaySphere.Deactivated` | spawner live count, indicator (by polling) |
| `enemy_despawned(enemy)` (player-death clear) | `DeactivateOnPlayerDeath.Deactivated` | spawner live count |
| `damaged(target, amount)` | `Health.Damaged` | none |
| `score_changed(previous, updated, increase)` | `ScoreManager.onScoreAdded` | HUD |
| `weapon_fired(direction)` | `PlayerController.onWeaponFired` | rifle SFX |
| `boss_threshold_reached` | `TrackerUntilBoss.onEffortPotentialReached` | none (future boss) |
| `run_saved(record)` | `ScoreManager.SaveScore` (button-driven) | none |

Recommendation for the port: make `enemy_died` carry a cause, so the shot-vs-crash ambiguity in
SC-2 and SP-7 becomes visible and easy to change later without breaking parity.

## 18. Level 1 as data (values to lift out of code)

```text
player:    speed 10, coast_factor 0.3, initial_move (0, 0.5), max_health 10, fire_interval 0.25,
           muzzle_offset 3, projectile_speed 24, projectile_lifetime 10, projectile_damage 3
camera:    fov 60, offset_landscape (0,0,22), offset_portrait (0,-2,32), damping 1, far 100
play_sphere: radius 40
intro:     duration 2.0, text "Level Start"
spawner:   spawn_distance 25 (radius 40 - inset 15), pool 50, reuse_after_death 3.0,
           limit_start 1.0, limit_per_death 0.25, delay_min 0.1, delay_max 0.8,
           buffer_start 4.0, buffer_per_death 0.25
enemy:     health 1, speed_min 6, speed_max 12, detect 228, close_enough 0, score 100, contact_kills true
boss:      deaths_before_boss 30 (no boss yet)
game_over: delay_after_player_death 2.0
```

## 19. Bugs and oddities found

1. **Enemy-on-enemy crashes kill both and score +200.** `Health.OnCollisionEnter()` kills on any
   collision, and all layers collide (`DynamicsManager` matrix all `ff`). Since enemies converge on the
   player, this probably happens a lot. It's a hidden mechanic: decide whether to keep it for parity.
2. **Crashing into an enemy scores +100** (the enemy dies as well as the player), and it advances the
   difficulty ramp.
3. **Dead SignalReceivers.** `User Interface Container` and `Spawners Container` have receivers for the
   intro signals, but the timeline only notifies `Directors`. The `Spawners Container` state reactor is
   also disabled (`m_Enabled: 0`). The `Directors` receiver does all the work.
4. **`RepeatSpawner.OnEnable` is hidden** by `BeginnerRepeatSpawner.OnEnable` (both private, Unity calls the
   derived one only), so `TimeOfLastSpawn`/`_delayTime` aren't initialised. The result is that the first spawn is
   immediate, and later runs carry the last run's delay over.
5. **The spawner keeps running during the 2 s death delay and the whole Game Over screen.** Each spawned
   enemy deactivates itself on its first frame (the player is inactive) and creates and releases an indicator.
   It's harmless, but it's wasted work, and a port shouldn't copy it. The spawner only stops when Game Over is *exited*.
6. **The live-enemy count can be decremented twice.** The enemy that kills the player by crashing dies (−1)
   and is then also "despawned on player death" (−1). The count is reset on the next run, so nothing visible happens.
7. **Explosions leak.** `ExplosionOnDeath` gets one from a pool but never releases it (`stopAction: 0`).
   Every death creates a new, permanently active explosion GameObject. Each enemy instance also has its own pool.
8. **The helper labels ("Move", "Attack", "Joystick") vanish only once per page load.** `DisappearingGUI`
   runs in `Start`. If the first run is shorter than 10 s, the coroutine is cut off and the labels stay forever after.
9. **The initials Up and Down are inverted** compared with arcade convention (IE-3), and analog sticks rarely
   change letters (IE-4).
10. **The "Play Again" button goes to the Menu**, not into a new run (GS-6).
11. **Game Time is shown as an unformatted float** and includes the 2 s intro (SC-5, SB-6).
12. **Dead code and assets:** the `Bullet Projectile` prefab and the player's `ObjectPool` of 30 bullets (instantiated,
    never used; the real shots are particles), `Projectile.cs`, `PlayerInputActions.cs`, `ScoreRecordInput.cs`,
    `TrailRendererStopsOnDie.cs`, `DeactivateOnDie.cs`, `IScoreKeeper`, `IReactToProjectile`, `Laser_Shoot.wav`, `Jets.wav`,
    `On Screen Button.png`, `Jet Material.mat`, the On-Screen Controls sample.
13. **The enemy `OnDiedTrigger` calls `AudioSource.Play` on a null target.** It's a broken, no-op death sound.
    The audible death sound comes from the Explosion prefab.
14. **A player rotation hack:** when moving, if the yaw is exactly 0 it is forced to 90° (`PlayerController.Update`).
    It's a workaround for `LookRotation` in the XY plane, and the port shouldn't need it.
15. **The `Reset()` methods** on `PlayerController`, `ScoreManager`, `ScoreKeeper`, `IndicatorManager` and `PrefabBackground` clash
    with Unity's editor `Reset` message. `PrefabBackground.Reset` deletes the cloud children if someone clicks "Reset" in the
    Inspector. This only affects the editor.
16. **The portrait camera offset may never apply on WebGL** (CA-4). **(verify)**
17. **Naming:** the product name is "Mecha Pilot" in `ProjectSettings` but the in-game title is "Mecha Fighter". The scene
    PlayerInput lists stale action names (`Player/Move`, `Fire[/Mouse/leftButton…]`), but it binds by action ID, which
    matches the `GamePlay` map.
18. **No automated tests:** `A/Tests/*/NewTestScript.cs` are empty templates, so there is nothing to port.

## 20. Assets to carry over

| Asset | Path | Format | Used for | Carry over? |
| - | - | - | - | - |
| Explosion SFX | `unity/mecha-pilot/Assets/Audio/Explosion.wav` | WAV PCM 16-bit mono 44.1 kHz, 0.79 s, 69 KB | enemy and player death | **Yes** |
| Rifle SFX | `unity/mecha-pilot/Assets/Audio/Mecha Rifle Single.wav` | WAV PCM 16-bit mono 44.1 kHz, 0.12 s, 10 KB | each shot | **Yes** |
| Laser SFX | `unity/mecha-pilot/Assets/Audio/Laser_Shoot.wav` | WAV PCM 16-bit mono 44.1 kHz, 0.45 s | unused | Optional |
| Jets loop | `unity/mecha-pilot/Assets/Audio/Jets.wav` | WAV PCM 16-bit mono 44.1 kHz, 2.02 s | unused | Optional (an engine loop later) |
| Cloud sprite | `unity/mecha-pilot/Assets/Sprites/Cloud.png` | PNG 256×256 RGBA | background layers | **Yes** |
| Joystick background | `unity/mecha-pilot/Assets/Sprites/Joystick Background.png` | PNG 128×128 RGBA | touch sticks | **Yes** |
| Joystick handle | `unity/mecha-pilot/Assets/Sprites/Joystick Handle.png` | PNG 64×64 RGBA | touch sticks | **Yes** |
| On-screen button | `unity/mecha-pilot/Assets/Sprites/On Screen Button.png` | PNG 64×64 RGBA | unreferenced (the Game Over D-pad uses the default UI sprite) | Optional, but a good fit for the touch D-pad |
| Font | `unity/mecha-pilot/Assets/TextMesh Pro/Fonts/LiberationSans.ttf` | TTF (Liberation Sans, SIL OFL 1.1) | all UI text | **Yes** (or Godot's default font). Include the OFL licence if bundled |
| Input map | `unity/mecha-pilot/Assets/InputActions/PlayerInput.inputactions` | JSON | bindings | Reference only: re-express as a Godot InputMap (section 3) |
| Level intro | `unity/mecha-pilot/Assets/Scripts/Timelines/Level Opening.playable`, `Assets/Signals/*.signal` | Unity YAML | intro timing | Reference only: becomes Level 1 data plus Game Events |
| Materials | `unity/mecha-pilot/Assets/Materials/Enemy Indicator.mat` (yellow `#FFF800`), `Jet Material.mat` (orange, alpha 0.46, unused) | Unity YAML | colours | Colours only |
| Meshes | — | Unity built-in primitives (cube, sphere, cylinder, quad) | player mech, enemy, indicator | Rebuild with Godot primitive meshes. Proportions are in the prefabs |
| Page template | `unity/mecha-pilot/Assets/WebGLTemplates/Fullscreen/` | HTML/CSS/JS | full-window canvas | Reference only (Godot's web export has its own shell) |
| Marketing media | `media/prod-website.png`, `media/qa-env-qr.png` | PNG | README | Out of scope here (Marketing Site ticket) |

Player mech construction (for a primitive-mesh rebuild): torso cube 1×1×0.4, two smaller cubes
stepping back (0.73, 0.46), a fin (0.1×1×0.4), a sphere head (0.53) at (0, 0.42, 0.53), two cylinder legs,
a cylinder gun arm at local x 1.25, and two yellow→orange jet trails (0.2 s) at (0, ±0.25, −1). The enemy is three cylinders
plus one jet trail and a white contrail. All of them use the default lit grey material.

## Open questions for the human

- Keep enemy-vs-enemy and crash kills scoring (Oddities 1–2) for strict parity, or treat them as bugs?
- Keep "Play Again → Menu", the inverted initials Up/Down, and the raw-float Game Time, or fix them in the port?
- Should the "Effort Until Boss" bar ship in Level 1 even though it does nothing yet?
