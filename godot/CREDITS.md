# Mecha Fighter: game credits

Every asset the game uses, with its source and licence. The Credits screen (`ui/screens/credits_screen.gd`) reads this table at runtime, so add a row whenever you add an asset. `scripts/checks/asset-credits` (`task checks`) fails if an image, audio, model, font or texture file in the project has no row here, if a row names a licence outside its allowlist, or if a row points at a path that no longer exists. Paths are relative to `godot/`; a path ending in `/` covers everything below it, but only on a third-party row: original work is credited file by file, or with no path when it ships no asset file, so a folder credit can never cover a third-party file added later.

| Asset | Source | Licence |
| --- | --- | --- |
| `ui/theme/fonts/Orbitron-Variable.ttf` Orbitron, the display font (licence: `ui/theme/fonts/Orbitron-OFL.txt`) | [The Orbitron Project Authors, via Google Fonts](https://github.com/google/fonts/tree/main/ofl/orbitron) | [OFL 1.1](https://openfontlicense.org/) |
| `ui/theme/fonts/ChakraPetch-SemiBold.ttf` Chakra Petch, the body font (licence: `ui/theme/fonts/ChakraPetch-OFL.txt`) | [The Chakra Petch Project Authors, via Google Fonts](https://github.com/google/fonts/tree/main/ofl/chakrapetch) | [OFL 1.1](https://openfontlicense.org/) |
| `ui/theme/theme.tres` UI theme and life icons | Original work made for this repository | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Attract-mode dogfight on the Title, built from the game's own models and skies | Original work made for this repository | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Player mech, enemy and boss models, built from primitive shapes in their scenes; no model file ships | Original work made for this repository; the player mech follows the LAN feel prototype's design | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Sky, cloud and rain shaders and the six level skies; no image ships | Original work made for this repository | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| "MECHA FIGHTER" title treatment, drawn with a shader | Original work made for this repository | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Every sound effect (SfxBank) and the music (SongBook): the title theme, the level loop, the boss loop and the Level Clear and Game Over stings. They are synthesized when the game starts; no audio file ships | Original work made for this repository; the sound design follows the LAN feel prototype's sfx.gd | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Explosions, debris, flashes, score pop-ups and the screen overlay shaders, built from primitive meshes and code; no image ships | Original work made for this repository; the feel follows the LAN feel prototype's fx.gd | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Godot Engine | [godotengine.org](https://godotengine.org/license/) | [MIT](https://opensource.org/license/mit) |
| `addons/gdUnit4/` GdUnit4 test framework (tests only, not exported) | [Mike Schulze, GdUnit4](https://github.com/MikeSchulze/gdUnit4) | [MIT](https://opensource.org/license/mit) |

## Inspiration

Mecha Fighter is an independent remix inspired by Konami's 1982 arcade game *Time Pilot*. It uses no Konami assets and is not affiliated with Konami.
