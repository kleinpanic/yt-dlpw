#!/usr/bin/env bash
#
# yt-dlp-wrapper — YouTube / YT Music helper with tidy Opus output
# Version 0.1.0
#

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Paths & constants
###############################################################################
LOGFILE="/tmp/yt-dlpw.log"
VERSION="0.1.0"

MUSIC_DIR="$HOME/Music"
VIDEO_DIR="$HOME/Videos/Youtube"
CACHEDIR="$HOME/.cache/yt-dlpw"

YTDLP_BIN="/usr/local/bin/yt-dlp"   # changed easily if you use a venv/conda
mkdir -p "$MUSIC_DIR" "$VIDEO_DIR" "$CACHEDIR"

###############################################################################
# Tiny helpers
###############################################################################
log()        { echo "$(date '+%F %T') - $*" >>"$LOGFILE"; }
p_info()     { printf '\e[32m>>> %s\e[m\n' "$*"; }
p_warn()     { printf '\e[33m>>> %s\e[m\n' "$*"; }
p_error()    { printf '\e[31;1m>>> %s\e[m\n' "$*"; }
p_ask()      { printf '\e[35;1m>>> %s\e[m\n' "$*"; }

trap 'p_warn "Download interrupted"; exit 130' INT TERM

###############################################################################
# Dependency install / update
###############################################################################
install_dependencies() {
  local pkgs=(jq curl git python3 ffmpeg)
  if [[ -f /etc/os-release ]]; then . /etc/os-release; fi
  case ${ID:-unknown} in
    debian|ubuntu)    sudo apt update && sudo apt install -y "${pkgs[@]}";;
    fedora|centos)    sudo dnf install -y "${pkgs[@]}";;
    arch)             sudo pacman -Syu --noconfirm "${pkgs[@]}";;
    darwin)           brew install "${pkgs[@]}";;
    *)                p_error "Unsupported OS"; exit 1;;
  esac

  if ! command -v yt-dlp &>/dev/null; then
    p_info "Installing yt-dlp from source …"
    git clone --depth 1 https://github.com/yt-dlp/yt-dlp "$CACHEDIR/yt-dlp-src"
    sudo make -C "$CACHEDIR/yt-dlp-src" install
    rm -rf "$CACHEDIR/yt-dlp-src"
  fi
}

update_yt_dlp() {
  local current latest
  current=$("$YTDLP_BIN" --version)
  latest=$(curl -s https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest | jq -r .tag_name)
  [[ $current == "$latest" ]] && { p_info "yt-dlp is up‑to‑date ($current)"; return; }
  p_info "Updating yt-dlp ($current → $latest)…"
  sudo "$YTDLP_BIN" -U && p_info "Update complete."
}

###############################################################################
# Metadata helpers
###############################################################################
get_metadata() { ffprobe -v quiet -show_entries "format_tags=$2" -of default=nw=1:nk=1 "$1" || echo "unknown"; }

organize_file() {
  local file=$1 tag target_dir artist norm
  [[ $file == "$MUSIC_DIR"* ]] && { tag=artist; target_dir=$MUSIC_DIR; } || { tag=uploader; target_dir=$VIDEO_DIR; }
  artist=$(get_metadata "$file" "$tag")
  norm=$(tr '[:upper:]' '[:lower:]' <<<"$artist" | tr -s '[:space:]' - | tr -cd '[:alnum:]-')
  mkdir -p "$target_dir/$norm"
  mv -f "$file" "$target_dir/$norm/"
}

###############################################################################
# yt-dlp wrappers
###############################################################################
download_single_music() {
  local url=$1 out_tpl="$MUSIC_DIR/%(title)s.%(ext)s"
  p_info "Downloading → Opus: $url"
  "$YTDLP_BIN" -f bestaudio \
               -x --audio-format opus \
               --embed-thumbnail --add-metadata \
               --convert-thumbnails jpg \
               --output "$out_tpl" \
               "$url"

  local outfile
  outfile=$("$YTDLP_BIN" --get-filename -f bestaudio -o "$out_tpl" "$url" | sed 's/\.[^.]*$/.opus/')
  organize_file "$outfile"
  p_info "Done: $outfile"
}

download_playlist() {
  local url=$1
  p_info "Playlist download → Opus"
  "$YTDLP_BIN" --yes-playlist -f bestaudio \
               -x --audio-format opus \
               --embed-thumbnail --add-metadata \
               --convert-thumbnails jpg \
               --output "$MUSIC_DIR/%(title)s.%(ext)s" \
               "$url"
  for f in "$MUSIC_DIR"/*.opus; do [[ -f $f ]] && organize_file "$f"; done
  p_info "Playlist finished."
}

download_music() {
  local url=$1
  if [[ $( "$YTDLP_BIN" --flat-playlist -J "$url" | jq '.entries|length') -gt 1 ]]; then
    download_playlist "$url"
  else
    download_single_music "$url"
  fi
}

download_single_media() {
  local url=$1 out_tpl="$VIDEO_DIR/%(title)s.%(ext)s"
  "$YTDLP_BIN" -f bestvideo+bestaudio \
               --embed-thumbnail --add-metadata \
               --output "$out_tpl" \
               "$url"
  local file=$("$YTDLP_BIN" --get-filename -f bestvideo+bestaudio -o "$out_tpl" "$url")
  organize_file "$file"
}

download_media_playlist() {
  local url=$1
  "$YTDLP_BIN" --yes-playlist -f bestvideo+bestaudio \
               --embed-thumbnail --add-metadata \
               --output "$VIDEO_DIR/%(title)s.%(ext)s" \
               "$url"
  for f in "$VIDEO_DIR"/*.{mp4,mkv,webm}; do [[ -f $f ]] && organize_file "$f"; done
}

download_media() {
  local url=$1
  if [[ $( "$YTDLP_BIN" --flat-playlist -J "$url" | jq '.entries|length') -gt 1 ]]; then
    download_media_playlist "$url"
  else
    download_single_media "$url"
  fi
}

###############################################################################
# Search helper
###############################################################################
search_and_download() {
  local func=$1
  p_ask "Enter track / video title:"; read -r title
  p_ask "Enter artist / uploader:" ; read -r artist
  local query="${title,,} ${artist,,}"

  p_info "Searching YouTube for \"$query\" …"
  local results ids
  results=$( "$YTDLP_BIN" "ytsearch5:$query" --print "%(title)s - %(uploader)s" --skip-download )
  ids=$(      "$YTDLP_BIN" "ytsearch5:$query" --print "%(id)s"                 --skip-download )

  if [[ -z $results ]]; then p_warn "No results."; return; fi
  paste <(printf '%s\n' $results) <(printf '%s\n' $ids) |
    nl -w2 -s' ' | while read -r n line id; do echo "$n) $line"; done

  p_ask "Pick 1‑5:"; read -r choice
  local id=$(echo "$ids" | sed -n "${choice}p")
  [[ -z $id ]] && { p_warn "Bad choice."; return; }
  "$func" "https://www.youtube.com/watch?v=$id"
}

###############################################################################
# Last.fm similar tracks
###############################################################################
get_similar_tracks() {
  p_ask "Song name:";   read -r track
  p_ask "Artist name:"; read -r artist
  local key=${API_KEY_LASTFM:-}
  [[ -z $key ]] && { p_error "API_KEY_LASTFM missing in ~/.env"; return; }
  curl -s "http://ws.audioscrobbler.com/2.0/?method=track.getsimilar&artist=${artist// /%20}&track=${track// /%20}&api_key=$key&format=json" |
    jq -r '.similartracks.track[]? | "\(.name) — \(.artist.name)"' | head -n 20
}

###############################################################################
# CLI
###############################################################################
show_help() {
cat <<EOF
Usage: $0 <command> [options]            Version $VERSION

Commands
  install               Install all dependencies
  update                Update yt-dlp to latest release
  music   [--search] <url> | --like
  media   [--search] <url>
  help                  Show this message

Examples
  $0 music --search
  $0 music https://youtu.be/abcdef
  $0 media --search
EOF
}

case ${1:-help} in
  install) install_dependencies ;;
  update)  update_yt_dlp ;;
  music)
    shift
    case ${1:-} in
      --search|-s) search_and_download download_single_music ;;
      --like)      get_similar_tracks ;;
      --) shift; download_music "$1" ;;
      *)  download_music "$1" ;;
    esac ;;
  media)
    shift
    case ${1:-} in
      --search|-s) search_and_download download_single_media ;;
      --) shift; download_media "$1" ;;
      *)  download_media "$1" ;;
    esac ;;
  help|--help|-h) show_help ;;
  *) show_help; exit 1 ;;
esac

