# Mecha Fighter

A 3D arcade shooter in the spirit of Time Pilot, played in the browser, plus the sites and workflow that ship it.

## Game

**Game Event**:
A named, game-level occurrence (e.g. player died, enemy killed, game state changed) that any part of the game may announce or react to.
_Avoid_: message, notification, callback

**Game State**:
The phase the game is in: Boot, Title, Level Intro, Skirmish, Boss Warning, Boss Fight, Level Clear, Paused, Game Over, Victory or Scoreboard. Only the four phases of play (Level Intro to Boss Fight) can be Paused.
_Avoid_: screen, mode, Menu (now the Title), Gameplay (now the phases of play)

**Run**:
One attempt at the game: the six Levels in order, starting with 3 lives, ending at Game Over or Victory. Its score, kills and time become a Scoreboard entry.
_Avoid_: game, session, playthrough

**Level**:
One stage of a Run, defined by a Level file (`levels/level_N.json`): its sky, enemy roster, spawn ramp, Boss Gauge threshold and Boss. It plays as Level Intro, Skirmish, Boss Warning, Boss Fight and Level Clear.
_Avoid_: stage, wave, mission

**Skirmish**:
The part of a Level before the Boss: enemies spawn from the Level's roster and their points fill the Boss Gauge.
_Avoid_: wave (a wave is a group of enemies spawned together inside the Skirmish)

**Boss**:
The large enemy that ends each Level, with a health pool, phases and telegraphed attacks. Defeating it clears the Level; defeating Level 6's Boss is Victory.
_Avoid_: mothership, end enemy

**Boss Gauge**:
The meter of points earned from kills in the current Level's Skirmish. When it reaches the Level's threshold, the Boss Warning starts and then the Boss enters. Losing a life does not empty it.
_Avoid_: boss bar (that is the Boss's health bar), progress

**Armor**:
The player mech's health, 0 to 100. Hits take Armor by source; at 0 the player loses a life and respawns at full Armor.
_Avoid_: health, HP, shield

**Repair Kit**:
A pickup that restores 30 Armor when the player flies through it. Kills sometimes drop one and a Boss always does.
_Avoid_: health pack, powerup

**Bonus Life**:
The single extra life awarded once per Run when the score first reaches 100,000.
_Avoid_: extra life, 1UP

**Combo**:
The score multiplier (x1 to x8) that rises with each kill made within 1.2 s of the last, and resets after 1.2 s without a kill or when the player takes damage.
_Avoid_: streak, chain

**Intel**:
The codex of enemies and Bosses. An entry shows "???" until that enemy or Boss is first encountered in play, and stays unlocked.
_Avoid_: bestiary, encyclopedia

**Play Sphere**:
The bounded region of space where play happens; things leaving it are out of play.
_Avoid_: arena, play area, bounds

**Scoreboard**:
The top 10 past Runs, each recorded with the player's three initials, score, Level reached and time. Local to the player's browser for now.
_Avoid_: leaderboard (reserved for a future internet-accessible version), high scores

## Web presence

**Game Site**:
Where the game itself is played: game.mechafighter.com.
_Avoid_: webgl site, app

**Marketing Site**:
The page at mechafighter.com that tells a player why they would want to play, and sends them to the Game Site.
_Avoid_: landing page, homepage

**QA Environment**:
The pre-release copy of the sites, updated on every merge to main. Also called Staging.
_Avoid_: preview

**Production**:
The public mechafighter.com and game.mechafighter.com, updated only on a release.
_Avoid_: live, prod site

## Workflow

**Agent Loop**:
A Claude session that checks Production, resumes or claims ready-for-agent work for its machine, and delivers it into main autonomously, shutting itself off when no work remains.
_Avoid_: build loop

**Supervisor**:
The token-free watcher that starts the Agent Loop when work exists, revives it when it stalls, and restarts it before its context grows too large.
_Avoid_: daemon, watchdog

**Provably Complete**:
An issue whose acceptance criteria are all demonstrated by the verification stack, so it may merge into main without a human.
_Avoid_: done, finished
