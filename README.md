# Usher

A tiny macOS background agent that becomes your default browser and ushers each
clicked link to the right Google Chrome profile.

- Link opened from **Slack** (or any app in `work-apps.txt`) → **work** profile
- Link whose host matches **`work-domains.txt`** → **work** profile
- Everything else → **personal** profile

Both lists are read on every click, so editing them takes effect immediately —
no rebuild.

## Requirements

- macOS 12 or later
- **Xcode Command Line Tools** (`xcode-select --install`) — provides `swiftc`
- Google Chrome (Chrome Beta/Canary, Chromium, and Brave are auto-detected too)

You build it yourself from source, so there is no notarization/Gatekeeper prompt.

## Install

```bash
git clone https://github.com/<you>/usher.git
cd usher
./list-profiles.sh                 # see your Chrome profile directory names
# edit ~/.config/usher/config after the first build (see Configure)
./build.sh
./set-default.sh                   # or set it in System Settings
```

`set-default.sh` sets Usher as the default handler for `http`/`https`. macOS
shows a confirmation dialog for `https` — click **Use "Usher"**. Alternatively:
**System Settings → Desktop & Dock → Default web browser → Usher**.

## Configure

`build.sh` seeds these into `~/.config/usher/` on first run (existing files are
never overwritten):

| File               | Purpose                                             |
|--------------------|-----------------------------------------------------|
| `config`           | Profile directory names + optional Chrome path      |
| `work-domains.txt` | Domains that force the work profile                 |
| `work-apps.txt`    | Source-app bundle IDs that force the work profile   |

- Run `./list-profiles.sh` to find your profile **directory** names (e.g.
  `Default`, `Profile 1`) — that's what goes into `config`, not the display name.
- `chrome_path` is optional; if omitted or wrong, Usher auto-detects Chrome.
- Find an app's bundle id with `osascript -e 'id of app "Slack"'`.

If Chrome can't be found at all, the link opens in Safari and an error is written
to the log (below) so links are never silently lost.

## Debug

Every routed link is logged with the decision reason:

```bash
tail -f ~/.local/state/usher/log
```

## How it works

Registered as an `http`/`https` handler, it receives Apple `GetURL` events. It
reads the sender PID off the event to identify the originating app (that's how
"opened from Slack" is detected), then launches the Chrome binary directly with
`--profile-directory=<name> <url>` so the link lands in the correct profile even
when Chrome is already running.

## Uninstall

```bash
pkill -f Usher.app
rm -rf ~/Applications/Usher.app ~/.config/usher ~/.local/state/usher
```

Then reset your default browser in System Settings.

## License

MIT — see [LICENSE](LICENSE).
