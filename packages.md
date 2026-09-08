# Installed software

Everything user-installed on this machine, by install channel. System packages and dependencies are left out. Regenerated 2026-09-08 after a cleanup pass.

Type: CLI, TUI, GUI, or Service.

## Desktop applications

### RPMs from third-party repos

| App | Type | Repo | Notes |
|---|---|---|---|
| Zed | GUI | Terra | Editor. `zed-cli` provides the `zed` command |
| VS Code | GUI | Microsoft | |
| Android Studio | GUI | Terra | Uses `~/Android` SDK and `~/flutter` |
| Google Chrome | GUI | Google | Hosts a WhatsApp Web PWA shortcut |
| 1Password | GUI | 1Password | Also `1password-mcp` in `/usr/local/bin` and the SSH signing agent git uses |
| Ghostty | GUI | Terra | Primary terminal. Shell integration, completions, Nautilus menu |
| Alacritty | GUI | Fedora | Secondary terminal |
| Ptyxis | GUI | Fedora | GNOME container terminal |
| VLC | GUI | Fedora | |
| Papers | GUI | Fedora | Document viewer |
| Decibels | GUI | Fedora | Audio player |
| Simple Scan | GUI | Fedora | |
| Orca | GUI | Fedora | Screen reader |
| PowerShell | CLI | Terra | |

### Flatpaks (system installation)

| App | Type | Notes |
|---|---|---|
| Spotify | GUI | |
| Termius | GUI | SSH client |
| Planify | GUI | Tasks |
| PDF Arranger | GUI | |
| Defuse | GUI | Image tool, 330 MB |
| Extension Manager | GUI | Manages GNOME extensions |
| Gear Lever | GUI | AppImage manager, autostarts |
| Obfuscate | GUI | Screenshot redaction |
| Embellish | GUI | Nerd Font installer |
| Bella | GUI | Colour picker |
| Keypunch | GUI | Typing practice |
| Emojify | GUI | Emoji picker |

### AppImages in `~/.appimages`

| App | Type | Notes |
|---|---|---|
| pCloud | GUI | Autostarts, mounts `~/pCloudDrive`. Being replaced by rclone, see `rclone.md` |
| Paper | GUI | Design tool. Pairs with the paper-desktop Claude Code plugin |
| T3 Code | GUI | Alpha. Has a URL handler entry |

## Developer tooling

### mise (`mise/.config/mise/config.toml`)

node 24, pnpm, bun, go, rust (via rustup), java 21, bat, direnv, marksman, heroku, wrangler, usage.

### AI coding agents (curl-installed)

| Tool | Type | Where | Notes |
|---|---|---|---|
| Claude Code | TUI | `~/.local/share/claude` | Plugins: typescript-lsp, paper-desktop |
| Antigravity CLI | TUI | `~/.local/bin/agy`, `~/.gemini/antigravity-cli` | 824 MB backend |
| herdr | TUI | `~/.local/bin` | Terminal workspace manager for agents |

### cargo

cargo-binstall.

### Python (uv tools and pip --user)

| Tool | Type | Notes |
|---|---|---|
| markitdown, trafilatura, mailaccess | CLI | uv tools |
| weasyprint | CLI | HTML to PDF |
| sherlock | CLI | Username search |
| Flask, pandas, numpy, fonttools | libs | pip --user, entry points in `~/.local/bin` |
| tor-prompt | CLI | From the stem library |

### Node globals

- npm: ast-grep, openapi-generator-cli, turbo, vercel
- pnpm: language servers for Astro, Tailwind, Bash, Docker, YAML, SQL, Svelte, TypeScript, GitHub Actions, Compose; vscode-langservers-extracted; portless
- bun: oh-my-posh

### Other curl-installed CLIs

| Tool | Type | Where | Notes |
|---|---|---|---|
| nub | CLI | `~/.nub` | Node.js toolkit |
| Vite+ | CLI | `~/.vite-plus` | `vp` command, 976 MB |
| hostinger | CLI | `/usr/local/bin` | Hostinger API CLI |

### RPM CLIs and TUIs

| Tool | Type | Notes |
|---|---|---|
| Helix | TUI | Editor, `hx` |
| yazi | TUI | File manager, Terra. Launcher hidden via `~/.local/share/applications/yazi.desktop` |
| lazygit | TUI | Terra |
| bottom | TUI | System monitor, Copr |
| hledger, hledger-web, ledger | CLI | Plain-text accounting |
| git, gh, git-lfs, stow | CLI | |
| ripgrep, fd-find, eza, zoxide, atuin, starship, fzf | CLI | Shell tooling |
| just, bear, ninja-build, sccache | CLI | Build helpers |
| typst, pandoc | CLI | Documents |
| uv, mise | CLI | Package managers |
| rclone, rsync | CLI | Sync |
| yt-dlp | CLI | Used by the `yt` and `ytm` fish functions |
| kubectl | CLI | |
| docker-ce, compose, buildx | Service | Docker daemon enabled. No images kept |
| doppler, tailscale | CLI | Tailscale daemon enabled |
| android-tools | CLI | adb, fastboot |
| xclip, wtype, dos2unix, mtr, nmap-ncat, sysbench, bcc-tools, wireguard-tools, sos | CLI | Utilities |
| gamemode | Service | No consumer since Steam was removed |
| virtualbox-guest-additions | Service | Only useful inside a VirtualBox VM |

## System-level extras

- Kernel: stock Fedora (CachyOS Copr kernel removed 2026-09-08)
- GNOME extensions (user-installed via Extension Manager): Accent Icons, Alphabetical App Grid, AppIndicator, Blur my Shell, Caffeine, Clipboard Indicator, Do Not Disturb While Screen Sharing, Edit Desktop Files, GSConnect, Just Perfection, Privacy Indicators Accent Color, Resource Monitor
- Icon theme: MoreWaita from Copr
- Cockpit installed, socket disabled
- User systemd: `rclone-bisync.timer`, not yet enabled

Not enumerated: extensions inside Zed, VS Code, and Android Studio.
