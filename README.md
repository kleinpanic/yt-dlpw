# yt‑dlpw – a friendly Bash wrapper for **yt‑dlp**

[yt‑dlp](https://github.com/yt-dlp/yt-dlp) is an amazing downloader, but its CLI can feel heavyweight for everyday use.  
**yt‑dlpw** ( *yt‑dlp wrapper* ) streamlines common tasks—especially **music downloads remuxed to OPUS**, thumbnail embedding, and automatic library organisation—while still exposing the power of yt‑dlp when you need it.

> **Repo:** <https://github.com/kleinpanic/yt-dlpw>  
> **License:** MIT

---

## Table of Contents

1. [Features](#features)
2. [Dependencies](#dependencies)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Examples](#examples)
6. [Road‑map](#road-map)
7. [Credits](#credits)
8. [License](#license)

---

## Features

* **One‑liner music grabs** – bestaudio → **OPUS** remux, embedded cover art, metadata, and auto‑sort into `~/Music/<artist>/`.
* **Video downloads** – best quality video+audio saved to `~/Videos/Youtube/<uploader>/`.
* **Interactive search mode** – fuzzy‑search YouTube, preview top 5 results, then pick what to grab.
* **Last.fm “similar tracks” lookup** – discover songs related to a track/artist.
* **Self‑update & dependency installer** – keep yt‑dlp and the wrapper current with a single command.
* Works everywhere Bash does (Linux, macOS, WSL).

---

## Dependencies

| Package | Why it’s needed |
|---------|-----------------|
| `bash`  | the wrapper itself |
| `yt-dlp` | actual downloader (installed automatically if missing) |
| `ffmpeg`| remuxing / thumbnail embedding |
| `jq`    | parsing JSON from yt‑dlp and APIs |
| `curl`  | API & web requests |
| `git`   | cloning yt‑dlp when installing from source |
| `python3` | yt‑dlp runtime |

### Quick install on popular distros

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y jq curl git ffmpeg python3
# Fedora
sudo dnf install -y jq curl git ffmpeg python3
# Arch
sudo pacman -S --noconfirm jq curl git ffmpeg python3
# macOS (Homebrew)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install jq curl git ffmpeg python3
```

---

## Installation

```bash
git clone https://github.com/kleinpanic/yt-dlpw.git
cd yt-dlpw
./yt-dlpw.sh install      # installs yt‑dlp (latest) & checks deps
```

> **Optional:** The installer offers to move the script to `/usr/local/bin/yt-dlpw` so you can run `yt-dlpw` from anywhere.

---

## Usage

```bash
yt-dlpw <command> [options] [-- <url>]
```

| Command | Purpose |
|---------|---------|
| `install` | install dependencies & latest yt‑dlp |
| `update`  | update yt‑dlp to the newest release |
| `music`   | download a single track or playlist |
| `media`   | download video content |
| `help`    | show built‑in help |
| `version` | print wrapper version |

### `music` options

| Option | Description |
|--------|-------------|
| `--search` | interactive YouTube search (pick 1‑5) |
| `--like`   | list similar tracks via Last.fm |
| `--` `<url>` | download directly from a URL (single video or playlist) |

### `media` options

| Option | Description |
|--------|-------------|
| `--search` | interactive YouTube search for videos |
| `--` `<url>` | download a single video or playlist |

---

## Examples

```bash
# 1. Grab a song via search (will prompt)
yt-dlpw music --search

# 2. Download a whole music playlist
yt-dlpw music -- https://www.youtube.com/playlist?list=PL...

# 3. Fetch a video at full quality
yt-dlpw media -- https://www.youtube.com/watch?v=dQw4w9WgXcQ

# 4. Check for new yt‑dlp version
yt-dlpw update
```

---

## Road‑map

* **Metadata picker** – choose which tags to keep or override.
* **Lyrics fetcher** – auto‑download `.lrc` or plain text.
* **Headless / cron mode** – silent downloads for automation.
* **Smarter search filters** – duration, channel, upload date, etc.

---

## Credits

* [yt‑dlp](https://github.com/yt-dlp/yt-dlp) – the engine.
* [jq](https://stedolan.github.io/jq/) – lightweight JSON parsing.
* [Last.fm API](https://www.last.fm/api) – “similar tracks” data.

