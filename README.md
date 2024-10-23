# yt-dlp-wrapper

`yt-dlp-wrapper` is a Bash-based script that simplifies downloading audio and video from YouTube and other platforms using `yt-dlp`. The script also offers enhanced features like organizing files, searching for similar tracks using Last.fm, and more. This document covers installation, usage, dependencies, and planned future improvements.

---

## Table of Contents
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Usage](#usage)
- [Features](#features)
- [Future Additions](#future-additions)
- [Credits](#credits)
- [License](#license)

---

## Dependencies

Before running the script, the following dependencies are required:

### Required Packages:
- `jq` - for JSON parsing
- `curl` - for making web requests
- `git` - for cloning repositories
- `python3` - for running the `yt-dlp` Python-based downloader

These can be installed with the following package managers:

#### Debian/Ubuntu
```bash
sudo apt update && sudo apt install jq curl git python3 -y
```

#### Fedora/CentOS
```bash
sudo dnf install jq curl git python3 -y
```

#### Arch Linux
```bash
sudo pacman -S jq curl git python3 --noconfirm
```

#### macOS (Homebrew)
```bash
brew install jq curl git python3
```

### yt-dlp
`yt-dlp` is downloaded from source and installed by the script itself, ensuring you always have the latest version. The script handles this automatically during the installation step if `yt-dlp` is missing.

---

## Installation

To install and set up the `yt-dlp-wrapper`, clone the repository and run the install command to verify dependencies:

```bash
git clone <repo_url> yt-dlp-wrapper
cd yt-dlp-wrapper
./yt-dlp-wrapper.sh install
```

The `install` command will:
- Verify that all necessary dependencies are installed.
- Install `yt-dlp` from the latest release on GitHub.
- Optionally, move the script to `/usr/local/bin` for easier use.

---

## Usage

The `yt-dlp-wrapper` script provides the following commands:

### General Commands
```bash
./yt-dlp-wrapper.sh {command} [options]
```

#### Commands:
- **install**: Installs dependencies and ensures `yt-dlp` is available.
- **update**: Checks for new versions of `yt-dlp` and updates it.
- **music**: Downloads music content.
  - **Options**:
    - `--search`: Search YouTube for a song and download it.
    - `--like`: Find similar tracks to a specified song using Last.fm.
    - `-- <url>`: Download a music track or playlist from the provided URL.
- **media**: Downloads media content (video).
  - **Options**:
    - `--search`: Search YouTube for a video and download it.
    - `-- <url>`: Download a media file or playlist from the provided URL.
    - `--southpark`: Download episodes from South Park Studios.

        - -s <season>: Specify the season number.
        - -e <episode>: Specify the episode number.
        - -l <language>: Specify the language ('EN' for English, 'DE' for German).
- **help**: Displays a help message.

### Example Usage

1. **Search for a song and download:**
```bash
./yt-dlp-wrapper.sh music --search
```

2. **Download a media file from a URL:**
```bash
./yt-dlp-wrapper.sh media -- https://www.youtube.com/watch?v=example
```

3. **Check for similar tracks using Last.fm:**
```bash
./yt-dlp-wrapper.sh music --like
```

4. **Update yt-dlp to the latest version:**
```bash
./yt-dlp-wrapper.sh update
```

---

## Features

### 1. **Download and Organize Files:**
The script automatically organizes downloaded files into respective directories:
- **Music**: Saved under `~/Music`, organized by artist name.
- **Media**: Saved under `~/Videos/Youtube`, organized by uploader name.

### 2. **Track Similarity with Last.fm:**
Use the Last.fm API to find songs similar to a given track.

### 3. **Script Management:**
During the install process, the script checks whether it's located in `/usr/local/bin` and offers to move it there, renaming the file without the `.sh` extension.

---

## Future Additions

1. **User-Selected Metadata:**
   - Add an interactive feature that allows users to select which metadata (e.g., album, genre, etc.) should be saved with each downloaded file.

2. **Remove External Dependencies:**
   - Explore ways to remove dependencies like `jq` and `curl` and instead rely purely on Bash commands or native utilities for better portability.

3. **Download Lyrics:**
   - Add an option to download lyrics for songs from available sources and store them alongside the downloaded files.

4. **Ghost Running:**
   - Implement a "ghost mode" where the program runs silently in the background without terminal output, ideal for automation in cron jobs.

5. **Improved Search Algorithms:**
   - Improve YouTube search handling by refining search queries and allowing advanced filtering options.

---

## Credits

This script makes use of the following software and resources:
- **yt-dlp**: [GitHub Repository](https://github.com/yt-dlp/yt-dlp)
- **jq**: JSON processing in Bash.
- **curl**: Command-line tool for transferring data with URLs.
- **Last.fm API**: For finding similar tracks based on artist and song.

---

## License

Please refer to the `LICENSE` file in the repository for details.

