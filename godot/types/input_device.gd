class_name InputDevice
extends RefCounted
## The kind of device the player used last. Prompts and glyphs follow it.
## A shared value type in types/, so game/, ui/ and the Events bus name one enum.

enum Kind { KEYBOARD, KEYBOARD_MOUSE, GAMEPAD, TOUCH }
