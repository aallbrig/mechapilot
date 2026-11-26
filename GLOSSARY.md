# Mecha Fighter

A 3D arcade shooter in the spirit of Time Pilot, played in the browser, plus the sites and workflow that ship it.

## Game

**Game Event**:
A named, game-level occurrence (e.g. player died, enemy killed, game state changed) that any part of the game may announce or react to.
_Avoid_: message, notification, callback

**Game State**:
The phase the game is in: Menu, Gameplay, Game Over, or Scoreboard.
_Avoid_: screen, mode

**Play Sphere**:
The bounded region of space where play happens; things leaving it are out of play.
_Avoid_: arena, play area, bounds

**Scoreboard**:
The ranked list of past runs, each recorded with the player's initials. Local to the player's browser for now.
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
