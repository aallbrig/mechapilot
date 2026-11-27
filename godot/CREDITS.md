# Mecha Fighter: game credits

Every asset the game uses, with its source and licence. `scripts/checks/asset-credits` (`task checks`) fails if an image, audio, model, font or texture file in the project has no row here, if a row names a licence outside its allowlist, or if a row points at a path that no longer exists. Paths are relative to `godot/`; a path ending in `/` covers everything below it. The Credits screen shows this list.

| Asset | Source | Licence |
| --- | --- | --- |
| Player mech, enemy and boss models (`game/visuals/player/`, `game/visuals/enemies/`, `game/visuals/bosses/`), built from primitive shapes | Original work made for this repository; the player mech follows the LAN feel prototype's design | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `game/visuals/sky/` Sky, cloud and rain shaders and the six level skies | Original work made for this repository | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `ui/title/` "MECHA FIGHTER" title treatment | Original work made for this repository | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Lettering font (the engine's built-in default font, Open Sans SemiBold) | Bundled with Godot Engine | [OFL 1.1](https://openfontlicense.org/) |
| Godot Engine | [godotengine.org](https://godotengine.org/license/) | [MIT](https://opensource.org/license/mit) |
| `addons/gdUnit4/` GdUnit4 test framework (tests only, not exported) | [MikeSchulze/gdUnit4](https://github.com/MikeSchulze/gdUnit4) | [MIT](https://opensource.org/license/mit) |

## Inspiration

Mecha Fighter is an independent remix inspired by Konami's 1982 arcade game *Time Pilot*. It uses no Konami assets and is not affiliated with Konami.
