## Mecha Pilot

Time pilot + Daigaiku + UN squadron

### Play the Game
#### [Play the game in QA environment](https://aallbrig.github.io/mechapilot/game/)
![QR code for QA environment](./media/qa-env-qr.png)

## (alpha) [Play the game in production (https://mechafighter.com)](https://mechafighter.com)
![QR code for production website  environment](./media/prod-website.png)

## Development

Run `task setup` once, then `task --list` for every target. `task ci` is the full gate (see `AGENTS.md`), and `task dev` starts the tmux dev session.

### LAN Preview

`task lan:up` serves the sites over HTTPS to phones and other devices on your local network. nginx runs in Docker Compose (`compose.yaml`, image pinned by digest), so you need Docker: Docker Desktop on macOS, or Docker Engine with the compose plugin on Linux. Without Docker, the tasks stop and say why.

| Path | What it serves |
| --- | --- |
| `/` | An index that links the two sites |
| `/current/` | The legacy site, as it is in production today (the 2022 Unity WebGL build on the `github-pages` branch, read straight from git) |
| `/new/` | The Marketing Site, built with `baseURL` `/new/` |
| `/new/game/` | The Godot web export (`lan:build` runs `task godot:export:web`), or a placeholder where that task is missing |

- `task lan:up` assembles `build/lan/www/` (`task lan:build`), creates or reuses the self-signed certificate in `build/lan-tls/` (`scripts/dev/lan-cert`), starts nginx and prints the URLs.
- `task lan:url` prints the URLs again, and `task lan:down` stops nginx.
- The certificate names `localhost` and your current LAN IP. It is regenerated when the IP changes or when it has fewer than 30 days left. Each device asks you to accept it once. HTTPS gives the game the secure context it needs.
- nginx listens on port 8471 on `127.0.0.1` and on your LAN IP only. Set `MECHAFIGHTER_LAN_PORT` to use another port. If the default route is a VPN, set `MECHAFIGHTER_LAN_IP` to your LAN address.
- In `task dev`, the `serve` window's `lan` pane runs the preview. While Docker is unavailable, the pane says why and waits.
