class_name DestroyCause
extends RefCounted
## Why something was destroyed. A SHOT kill scores; a COLLISION (a crash into
## the player) never does.

enum Cause { SHOT, COLLISION }
