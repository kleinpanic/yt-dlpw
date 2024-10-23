#!/bin/bash

# Log file for the script (same directory as the script)
LOGFILE="/tmp/yt-dlpw.log"

VERSION="0.0.1"  # Define the current version of yt-dlpw

# Music directory where files will be moved
MUSIC_DIR="$HOME/Music"
VIDEO_DIR="$HOME/Videos/Youtube"
CACHEDIR="$HOME/.cache/yt-dlpw"
OUTDIR="$VIDEO_DIR/SouthParkEpisodes"

YOUTUBE_DL="/usr/local/bin/yt-dlp"

# Initialize directories if they don't exist
[ ! -e "$OUTDIR" ] && mkdir -p "$OUTDIR"
[ ! -e "$CACHEDIR" ] && mkdir -p "$CACHEDIR"

# Function to log output
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOGFILE"
}

# Helper Functions for Messaging
p_info() {
    echo -e "\e[32m>>> $@\e[m"
}

p_warning() {
    echo -e "\e[33m>>> $@\e[m"
}

p_error() {
    echo -e "\e[1;31m>>> $@\e[m"
}

p_ask() {
    echo -e "\e[1;35m>>> $@\e[m"
}


# Source the API key from the .env file or .env directory
source_env_file() {
    if [ -f "$HOME/.env" ]; then
        source "$HOME/.env"
    elif [ -f "$HOME/.env/.env" ]; then
        source "$HOME/.env/.env"
    else
        p_error "Error: .env file not found in the home directory or in the .env directory."
        exit 1
    fi

    # Ensure the API_KEY_LASTFM is set
    if [ -z "$API_KEY_LASTFM" ]; then
        p_error "Error: API_KEY_LASTFM not found in the .env file."
        exit 1
    fi
}

source_env_file

# Signal handler to handle CTRL-C and clean exit
trap 'echo "Download interrupted by user."; kill_process; exit' SIGINT SIGTERM

# Function to safely kill processes if they're running
kill_process() {
    if [[ -n "$pid" ]]; then
        kill -SIGTERM "$pid" 2>/dev/null
        wait "$pid"
    fi
}

# Install function to check dependencies and install yt-dlp from source
function install_dependencies() {
    log "Checking system dependencies..."

    # Detect operating system
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi

    log "Operating system detected: $OS"

    # Define required packages
    PACKAGES=("jq" "curl" "git" "python3")

    # Install dependencies based on the OS
    case "$OS" in
        ubuntu|debian)
            log "Using apt for package installation..."
            sudo apt update
            sudo apt install -y "${PACKAGES[@]}"
            ;;
        fedora|centos)
            log "Using dnf for package installation..."
            sudo dnf install -y "${PACKAGES[@]}"
            ;;
        arch)
            log "Using pacman for package installation..."
            sudo pacman -Syu --noconfirm "${PACKAGES[@]}"
            ;;
        darwin)
            log "Using Homebrew for package installation..."
            brew install "${PACKAGES[@]}"
            ;;
        *)
            p_error "Unsupported operating system: $OS"
            log "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    # Check if yt-dlp is installed
    if ! command -v yt-dlp &> /dev/null; then
        log "yt-dlp is not installed. Proceeding with installation from source..."

        # Install yt-dlp from source
        log "Installing yt-dlp from source..."
        latest_version=$(curl -s https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest | jq -r '.tag_name')
        if [[ -z "$latest_version" ]]; then
            log "Failed to fetch the latest yt-dlp version from GitHub."
            p_error "Failed to fetch the latest yt-dlp version from GitHub."
            return
        fi
        p_info "Latest yt-dlp version: $latest_version"
        git clone https://github.com/yt-dlp/yt-dlp.git
        cd yt-dlp || exit
        git checkout "$latest_version"
        sudo make install
        cd .. && rm -rf yt-dlp

        log "yt-dlp installation completed."
    else
        log "yt-dlp is already installed. Skipping installation from source."
        p_info "yt-dlp is already installed. Skipping installation."
    fi

    # Check if script is in /usr/local/bin
    SCRIPT_PATH=$(readlink -f "$0")
    SCRIPT_NAME=$(basename "$SCRIPT_PATH" .sh)  # Remove the .sh extension from the filename
    log "Script is located at: $SCRIPT_PATH"
    if [[ "$SCRIPT_PATH" != "/usr/local/bin/"* ]]; then
        echo "The script is currently located at: $SCRIPT_PATH"
    
        # Check if the script already exists in /usr/local/bin
        if [ -f "/usr/local/bin/$SCRIPT_NAME" ]; then
            # Extract the existing versions
            existing_version=$(/usr/local/bin/$SCRIPT_NAME version | awk -F': ' '{print $2}')
            # Compare versions
            if [ "$existing_version" != "$VERSION" ]; then
                p_warning "Existing version of $SCRIPT_NAME in /usr/local/bin is $existing_version. Current version is $VERSION."
                read -rp "Do you want to update it to the latest version? (y/n): " choice
                case "$choice" in
                    y|Y)
                        sudo cp "$SCRIPT_PATH" "/usr/local/bin/$SCRIPT_NAME"
                        sudo chmod +x "/usr/local/bin/$SCRIPT_NAME"
                        log "Script updated to version $VERSION in /usr/local/bin."
                        p_info "Script successfully updated to version $VERSION in /usr/local/bin."
                        ;;
                    n|N)
                        log "User chose not to update the script."
                        p_info "Script will remain in its current location."
                        ;;
                    *)
                        p_error "Invalid input, aborting script move."
                        ;;
                esac
            else
                p_info "A matching version ($existing_version) of $SCRIPT_NAME already exists in /usr/local/bin. No action taken."
                log "No update needed. Existing script version ($existing_version) matches current version ($VERSION)."
            fi
        else
            # Script doesn't exist in /usr/local/bin, prompt to copy
            read -rp "Do you want to move it to /usr/local/bin as '$SCRIPT_NAME'? (y/n): " choice
            case "$choice" in
                y|Y)
                    sudo cp "$SCRIPT_PATH" "/usr/local/bin/$SCRIPT_NAME"
                    sudo chmod +x "/usr/local/bin/$SCRIPT_NAME"  # Ensure it's executable
                    log "Script copied to /usr/local/bin as $SCRIPT_NAME."
                    p_info "Script successfully moved to /usr/local/bin as $SCRIPT_NAME."
                    ;;
                n|N)
                    log "User chose not to move the script."
                    p_info "Script will remain in its current location."
                    ;;
                *)
                    p_error "Invalid input, aborting script move."
                    ;;
            esac
        fi
    fi

    log "Installation complete."
    p_info "Installation complete."

}

# Update yt-dlp version check function
function update_yt_dlp() {
    log "Checking for yt-dlp version..."

    # Get the current version
    current_version=$(yt-dlp --version)
    log "Current yt-dlp version: $current_version"
    p_info "Current yt-dlp version: $current_version"

    # Fetch the latest version from GitHub
    latest_version=$(curl -s https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest | jq -r '.tag_name')

    if [[ -z "$latest_version" ]]; then
        log "Failed to fetch the latest version from GitHub."
        p_error "Failed to fetch the latest version from GitHub."
        return
    fi

    log "Latest yt-dlp version: $latest_version"
    p_info "Latest yt-dlp version: $latest_version"


    # Compare the versions
    if [[ "$current_version" == "$latest_version" ]]; then
        log "yt-dlp is up-to-date."
        p_info "yt-dlp is up-to-date."
    else
        log "yt-dlp is out-of-date. Current version: $current_version, Latest version: $latest_version"
        p_warning "yt-dlp is out-of-date. Current version: $current_version, Latest version: $latest_version"

        # Ask the user if they want to update
        while true; do
            read -rp "Do you want to update yt-dlp to the latest version? (y/n): " choice
            case "$choice" in
                y|Y)
                    p_info "Updating yt-dlp..."
                    log "User chose to update yt-dlp."
                    # Run the update using sudo
                    if sudo yt-dlp -U; then
                        log "yt-dlp updated successfully."
                        p_info "yt-dlp updated successfully."
                    else
                        log "Error: Failed to update yt-dlp."
                        p_error "Error: Failed to update yt-dlp."
                    fi
                    break
                    ;;
                n|N)
                    p_info "Update skipped."
                    log "User chose not to update yt-dlp."
                    break
                    ;;
                *)
                    p_warning "Invalid input, please enter y or n."
                    ;;
            esac
        done

        # Recheck the version after the update attempt
        new_version=$(yt-dlp --version)
        if [[ "$new_version" == "$latest_version" ]]; then
            p_info "yt-dlp is now up-to-date (version: $new_version)."
            log "yt-dlp is now up-to-date (version: $new_version)."
        else
            p_info "yt-dlp is still outdated. Current version: $new_version, Latest version: $latest_version"
            log "yt-dlp is still outdated. Current version: $new_version, Latest version: $latest_version"
        fi
    fi
}

# Function to extract metadata using ffprobe or mediainfo
function get_metadata() {
    local file="$1"
    local tag="$2"

    # Extract metadata using ffprobe
    value=$(ffprobe -v quiet -show_entries format_tags="$tag" -of default=noprint_wrappers=1:nokey=1 "$file" | head -n 1)

    # Fallback to mediainfo if ffprobe fails
    if [[ -z "$value" ]]; then
        log "ffprobe failed to extract $tag for $file, falling back to mediainfo"
        value=$(mediainfo --Output="General;%${tag}%" "$file" | head -n 1)
    fi

    # If no metadata is found, log it and use a default value
    if [[ -z "$value" ]]; then
        log "$tag metadata not found for file: $file"
        if [[ "$tag" == "artist" ]]; then
            value="Unknown Artist"
        elif [[ "$tag" == "uploader" ]]; then
            value="Unknown Uploader"
        else
            value="Unknown"
        fi
    fi

    echo "$value"
}

# Function to organize and move the file based on artist or uploader
function organize_file() {
    local file="$1"
    
    # Determine if it's music or media based on where it was downloaded
    if [[ "$file" == *"$MUSIC_DIR"* ]]; then
        tag="artist"
        target_dir="$MUSIC_DIR"
    elif [[ "$file" == *"$VIDEO_DIR"* ]]; then
        tag="uploader"
        target_dir="$VIDEO_DIR"
    else
        log "Unrecognized directory for file: $file"
        return
    fi

    # Extract the artist or uploader using the appropriate tag
    metadata=$(get_metadata "$file" "$tag")

    # Normalize the artist/uploader name (replace spaces, handle capitalization)
    normalized_metadata=$(echo "$metadata" | sed 's/[[:space:]]/-/g' | tr '[:upper:]' '[:lower:]')

    log "Organizing file: $file under $tag: $metadata (normalized: $normalized_metadata)"

    # Create the artist/uploader directory if it doesn't exist
    metadata_dir="$target_dir/$normalized_metadata"
    if [[ ! -d "$metadata_dir" ]]; then
        log "Creating directory: $metadata_dir"
        mkdir -p "$metadata_dir"
    fi

    # Move the file to the appropriate directory
    log "Moving $file to $metadata_dir"
    mv "$file" "$metadata_dir/"
}

# General function to search for a song or media on YouTube and allow the user to choose one
function search_and_download() {
    local download_function="$1"  # This should be either 'download_single_music' or 'download_single_media'

    p_ask "Enter the name of the content you wish to download (song or video):"
    read -r content_name
    content_name=$(echo "$content_name" | tr '[:upper:]' '[:lower:]')

    p_ask "Enter the uploader/artist name:"
    read -r uploader_name
    uploader_name=$(echo "$uploader_name" | tr '[:upper:]' '[:lower:]')

    query="${content_name} ${uploader_name}"

    # Search YouTube for the content
    p_info "Searching YouTube for: $query"
    log "Searching YouTube for: $query"
    
    # Use yt-dlp to search for the top 5 results and get title, uploader, and URL
    search_results=$(yt-dlp "ytsearch5:$query" --print "%(title)s - %(uploader)s" --get-id --skip-download)

    if [[ -z "$search_results" ]]; then
        p_warning "No results found. Try again with a different search."
        log "No results found for: $query"
        return
    fi

    # Separate the video information (title, uploader) and the URLs for internal use
    titles_and_uploaders=$(echo "$search_results" | awk 'NR % 2 == 1')  # Extract the odd lines (title and uploader)
    video_urls=$(echo "$search_results" | awk 'NR % 2 == 0')            # Extract the even lines (URLs)

    # Output the search results in a numbered list
    p_info "Top 5 results:"
    echo "$titles_and_uploaders" | awk '{print NR, $0}'

    # Allow the user to choose which result to download
    p_ask "Enter the number (1-5) of the video you wish to download:"
    read -r choice
    
    # Extract the URL based on user choice
    chosen_url=$(echo "$video_urls" | awk -v num="$choice" 'NR==num')
    
    if [[ -z "$chosen_url" ]]; then
        p_warning "Invalid choice. Exiting."
        log "Invalid choice made by user."
        return
    fi
    
    p_info "Downloading the selected content..."
    log "Downloading from: $chosen_url"
    
    # Call the appropriate download function for music or media
    $download_function "https://www.youtube.com/watch?v=$chosen_url"
}

# Function to download a single music track
function download_single_music() {
    local url="$1"
    shift
    options=("$@")

    log "Starting download for single track: $url"
    p_info "Downloading single track: $url"

    output_path="$MUSIC_DIR/%(title)s.%(ext)s"
    log "Setting output path to: $output_path"

    # No background process, run synchronously
    yt-dlp -f bestaudio --extract-audio --audio-format flac --embed-thumbnail --convert-thumbnails jpg --add-metadata --output "$output_path" "$url" "${options[@]}"

    output_file=$(yt-dlp --get-filename -f bestaudio --extract-audio --audio-format flac --output "$output_path" "$url" | sed 's/\.[^.]*$/.flac/')
    
    log "Download and conversion to FLAC completed: $output_file"
    p_info "Download complete: $output_file"

    organize_file "$output_file"
}

# Function to download a playlist
function download_playlist() {
    local url="$1"
    shift
    options=("$@")

    p_info "Starting download for playlist: $url"
    log "Starting download for playlist: $url"

    # Add debug output to check if yt-dlp starts correctly
    p_info "Running yt-dlp to download playlist..."
    log "Running yt-dlp to download playlist..."

    # Enable verbose output from yt-dlp for debugging
    yt-dlp --yes-playlist -v -f bestaudio --extract-audio --audio-format flac --embed-thumbnail --convert-thumbnails jpg --add-metadata --output "$MUSIC_DIR/%(title)s.%(ext)s" "$url"

    # After downloading the playlist, organize the files
    p_info "Organizing files after playlist download..."
    log "Organizing files after playlist download..."
    for file in "$MUSIC_DIR"/*.flac; do
        log "Organizing file: $file"
        organize_file "$file"
    done

    p_info "Playlist download completed: $url"
    log "Playlist download completed: $url"
}

# Function to download music (handles both single tracks and playlists)
function download_music() {
    local url="$1"
    shift
    options=("$@")

    log "Checking URL: $url"
    p_info "Checking URL: $url"

    # Detect if it's a playlist using yt-dlp's JSON output
    is_playlist=$(yt-dlp --flat-playlist -J "$url" | jq -r '.entries | length')

    if [ "$is_playlist" -gt 1 ]; then
        log "Detected a playlist."
        p_info "Detected a playlist."
        download_playlist "$url" "${options[@]}"
    else
        log "Detected a single music track."
        p_info "Detected a single music track."
        download_single_music "$url" "${options[@]}"
    fi
}

# Function to download a single media file
function download_single_media() {
    local url="$1"
    shift
    options=("$@")

    log "Starting download for single media file: $url"
    p_info "Downloading single media file: $url"

    output_path="$VIDEO_DIR/%(title)s.%(ext)s"
    log "Setting output path to: $output_path"

    yt-dlp -f b --embed-thumbnail --add-metadata --output "$output_path" "$url" "${options[@]}"

    output_file=$(yt-dlp --get-filename -f b --output "$output_path" "$url")

    log "Download completed: $output_file"
    p_info "Download complete: $output_file"

    organize_file "$output_file" "uploader"
}

# Function to download a media playlist (downloads full videos, not just audio)
function download_media_playlist() {
    local url="$1"
    shift
    options=("$@")

    p_info "Starting download for media playlist: $url"
    log "Starting download for media playlist: $url"

    # Download the entire playlist in best video and audio format
    yt-dlp --yes-playlist -f b --embed-thumbnail --add-metadata --output "$VIDEO_DIR/%(title)s.%(ext)s" "$url"

    # Organize the files after download (by uploader)
    p_info "Organizing media files after playlist download..."
    log "Organizing media files after playlist download..."
    for file in "$VIDEO_DIR"/*.{mp4,mkv,webm}; do
        if [[ -f "$file" ]]; then
            log "Organizing file: $file"
            organize_file "$file" "uploader"  # Organize by uploader
        fi
    done

    p_info "Media playlist download completed: $url"
    log "Media playlist download completed: $url"
}

# Function to download media (similar to music but saves to VIDEO_DIR)
function download_media() {
    local url="$1"
    shift
    options=("$@")

    log "Checking URL: $url"
    p_info "Checking URL: $url"

    # Detect if it's a playlist using yt-dlp's JSON output
    is_playlist=$(yt-dlp --flat-playlist -J "$url" | jq -r '.entries | length')

    if [ "$is_playlist" -gt 1 ]; then
        log "Detected a media playlist."
        p_info "Detected a media playlist."
        download_media_playlist "$url" "${options[@]}"
    else
        log "Detected a single media file."
        p_info "Detected a single media file."
        download_single_media "$url" "${options[@]}"
    fi
}

# Enhanced download_southpark function
download_southpark() {
    local SEASON_NUMBER="$1"
    local EPISODE_NUMBER="$2"
    local LANG="$3"
    local ALL="$4"
    local PROGRESS="$5"
    local UPDATE_INDEX="$6"
    local DRY="$7"
    local REINIT="$8"

    # Set default language if not provided
    [ -z "$LANG" ] && LANG="EN"

    # Resolve base URL and domain
    BASE_URL="$(curl -LsI -o /dev/null -w '%{url_effective}' 'https://southparkstudios.com/' | sed 's@/$@@')"
    BASE_DOMAIN="$(echo "$BASE_URL" | sed -n 's@https://\(www\.\|\)\(.*\)@\2@p')"
    INDEX_FILENAME="$CACHEDIR/_episode_index_$(echo "$BASE_DOMAIN" | tr '.' '_')_${LANG}_"

    # Language-specific URL handling
    if [ "$LANG" = "DE" ]; then
        if [ "$BASE_DOMAIN" != 'southpark.de' ]; then
            p_error "Your region is on $BASE_DOMAIN. You need to be in Germany (southpark.de) for German episodes. If you don't want to buy a plane ticket to Germany, you can also use a VPN."
            exit 1
        fi
        INDEX_INITIAL_URL="$BASE_URL/folgen/940f8z/south-park-cartman-und-die-analsonde-staffel-1-ep-1"
        REGEX_EPISODE_URL="/folgen/[0-9a-z]+/south-park-[0-9a-z-]+-staffel-[0-9]+-ep-[0-9]+"
    else
        PATH_LANG_PREFIX=""
        case "$BASE_DOMAIN" in
            'southpark.de'|'southpark.lat')
                PATH_LANG_PREFIX='/en'
                ;;
            'southparkstudios.com'|'southparkstudios.nu'|'southparkstudios.dk'|'southpark.cc.com'|'southpark.nl')
                ;;
            *)
                p_warning "Your region is on $BASE_DOMAIN, which is currently unknown. Please open an issue on GitHub. If the program doesn't work, you can try to VPN into Germany."
                ;;
        esac
        INDEX_INITIAL_URL="$BASE_URL$PATH_LANG_PREFIX/episodes/940f8z/south-park-cartman-gets-an-anal-probe-season-1-ep-1"
        REGEX_EPISODE_URL="$PATH_LANG_PREFIX/episodes/[0-9a-z]+/south-park-[0-9a-z-]+-season-[0-9]+-ep-[0-9]+"
    fi

    # Initialize youtube-dlp if necessary
    init() {
        local CUSTOM_PYTHON=

        if ! which python > /dev/null; then
            if which python3 > /dev/null; then
                p_info ">>> python not found, using python3 instead"
                CUSTOM_PYTHON=python3
            else
                p_error ">>> No python executable found, please install python or python3"
                exit 1
            fi
        fi

        if [ ! -e "$DIR/yt-dlp" ]; then
            p_info ">>> Cloning youtube-dlp repo"
            git clone -c advice.detachedHead=false --depth 1 --branch "2023.03.04" "https://github.com/yt-dlp/yt-dlp.git" "$DIR/yt-dlp"
        fi

        p_info ">>> Building youtube-dlp"
        make -C "$DIR/yt-dlp" yt-dlp
        if [ -n "$CUSTOM_PYTHON" ]; then
            sed -i "1c\\#!/usr/bin/env $CUSTOM_PYTHON" "$DIR/yt-dlp/yt-dlp"
        fi
    }

    # Update episode index function
    update_index() {
        [ ! -e "$INDEX_FILENAME" ] && echo "$INDEX_INITIAL_URL" > "$INDEX_FILENAME"
        p_info "Updating episode index"
        while true; do
            local SEEDURL="$(tail -n1 "$INDEX_FILENAME" | tr -d '\n')"
            local HTML="$(curl -s "$SEEDURL")"
            local URLS="$(echo -n "$HTML" | sed 's@</a>@|@g' | tr '|' '\n' | sed -n "s@.*href=\"\\($REGEX_EPISODE_URL\\)\".*@\\1@p" | sed "s@^@$BASE_URL@g" | tr '\n' '|')"
            # Retain matches after the seed URL
            local NEWURLS="$(echo -n "$URLS" | tr '|' '\n' | sed -n "\\@^$SEEDURL\$@,\$p" | tail -n +2 | tr '\n' '|')"
            [ -z "$NEWURLS" ] && break
            echo -n "$NEWURLS" | tr '|' '\n' >> "$INDEX_FILENAME"
            echo -ne "\e[32m.\e[m"
        done
        echo -e " \e[32mDone.\e[m"
    }

    REGEX_TITLE='<meta data-rh="true" property="search:episodeTitle" content="\([^"]*\)"'

    # Get episode title
    get_title() {
        local URL="$1"
        curl -s "$URL" | sed -n "s@.*$REGEX_TITLE.*@\1@p"
    }

    # Get all episodes in a season
    get_season() {
        local SEASON_NUMBER="$1"
        grep "\-${SEASON_NUMBER}-ep-[0-9]\+$" "$INDEX_FILENAME"
    }

    # Get specific episode URL
    get_episode() {
        local SEASON_NUMBER="$1"
        local EPISODE_NUMBER="$2"
        grep "\-${SEASON_NUMBER}-ep-${EPISODE_NUMBER}$" "$INDEX_FILENAME"
    }

    # Get number of seasons
    get_num_seasons() {
        grep "\-[0-9]\+-ep-1$" "$INDEX_FILENAME" | wc -l
    }

    # Get number of episodes in a season
    get_num_episodes() {
        local SEASON_NUMBER="$1"
        get_season "$SEASON_NUMBER" | wc -l
    }

    # Clean up temporary files
    tmp_cleanup() {
        p_info "Cleaning up temporary files"
        rm -rf "$TMPDIR"
    }

    # Monitor download progress
    monitor_progress() {
        local TMP_DIR="$1"
        while true; do
            [ ! -e "$TMP_DIR" ] && break
            printf " Downloaded: %sMB\r" "$(du -m "$TMP_DIR" | cut -f1)"
            sleep 0.5
        done
    }

    # Handle user interrupt during download
    download_interrupt() {
        p_info "User interrupt received"
        tmp_cleanup
        exit 0
    }

    # Handle user interrupt during merging
    merge_interrupt() {
        p_info "User interrupt received"
        tmp_cleanup
        p_info "Cleaning up corrupted output file"
        rm -rf "$1"
        exit 0
    }

    # Download a single episode
    download_episode() {
        local SEASON_NUMBER="$1"
        local EPISODE_NUMBER="$2"
        local SEASON_STRING="$(printf "%02d" "$SEASON_NUMBER")"
        local EPISODE_STRING="$(printf "%02d" "$EPISODE_NUMBER")"
        local OUTFILE="${OUTDIR}/South_Park_${LANG}_S${SEASON_STRING}_E${EPISODE_STRING}.mp4"

        if [ -e "$OUTFILE" ]; then
            p_info "Already downloaded Season ${SEASON_NUMBER} Episode ${EPISODE_NUMBER}"
            return
        fi

        local URL="$(get_episode "$SEASON_NUMBER" "$EPISODE_NUMBER")"
        if [ -z "$URL" ]; then
            p_error "Unable to download Season ${SEASON_NUMBER} Episode ${EPISODE_NUMBER}; skipping"
            return
        fi

        local TITLE="$(get_title "$URL")"
        p_info "Downloading S$SEASON_NUMBER E$EPISODE_NUMBER: $TITLE"

        if [ "$DRY" = true ]; then
            p_info "Dry run: URL to download - $URL"
            log "Dry run: URL to download - $URL"
            return
        fi

        trap download_interrupt SIGINT
        TMPDIR="$(mktemp -d "/tmp/southparkdownloader.XXXXXXXXXX")"

        if [ "$PROGRESS" = true ]; then
            monitor_progress "$TMPDIR" &
            progress_pid=$!
        fi

        cd "$TMPDIR" > /dev/null
        if ! "$YOUTUBE_DL" "$URL" >log 2>&1; then
            p_error "Possible youtube-dl error! Log:"
            cat log
            p_error "End log"
            tmp_cleanup
            return
        fi

        p_info "Merging video files"
        trap "merge_interrupt \"$OUTFILE\"" SIGINT

        # Remove all single quotes and dashes from video files, as they cause problems
        for i in ./*.mp4; do
            mv -n "$i" "$(echo "$i" | tr -d \' -)"
        done

        # Find all video files and write them into the list
        printf "file '%s'\n" ./*.mp4 > list.txt

        # Merge video files
        ffmpeg -safe 0 -f concat -i "list.txt" -c copy "$OUTFILE" 2>/dev/null

        cd - > /dev/null
        trap - SIGINT
        tmp_cleanup

        if [ "$PROGRESS" = true ]; then
            kill "$progress_pid" 2>/dev/null
        fi

        p_info "Download and merging completed: $OUTFILE"
    }

    # Download an entire season
    download_season() {
        local SEASON_NUMBER="$1"
        local NUM_EPISODES="$(get_num_episodes "$SEASON_NUMBER")"
        p_info "Downloading Season $SEASON_NUMBER with $NUM_EPISODES episodes."
        for i in $(seq "$NUM_EPISODES"); do
            download_episode "$SEASON_NUMBER" "$i"
        done
    }

    # Download all seasons
    download_all() {
        local NUM_SEASONS="$(get_num_seasons)"
        p_info "Downloading all $NUM_SEASONS seasons."
        for i in $(seq "$NUM_SEASONS"); do
            download_season "$i"
        done
    }

    # Main logic based on options
    if [ "$REINIT" = true ] && [ "$YOUTUBE_DL" != "$DIR/./yt-dlp/yt-dlp" ]; then
        p_info 'Please change YOUTUBE_DL back to "./yt-dlp/yt-dlp" in order to re-initialize'
    fi

    if [ "$YOUTUBE_DL" = "$DIR/./yt-dlp/yt-dlp" ] && [ ! -e "$DIR/yt-dlp" ] || ([ "$REINIT" = true ] && rm -rf "$DIR/yt-dlp"); then
        init
    fi

    if [ "$UPDATE_INDEX" = true ]; then
        update_index
    fi

    if [ -n "$EPISODE_NUMBER" ] && [ -z "$SEASON_NUMBER" ]; then
        p_info "Season not specified, assuming season 1"
        SEASON_NUMBER=1
    fi

    if [ -n "$SEASON_NUMBER" ]; then
        if [ -z "$(get_season "$SEASON_NUMBER")" ]; then
            p_error "Unable to find Season $SEASON_NUMBER"
            exit 1
        fi
        if [ -n "$EPISODE_NUMBER" ]; then
            if [ -z "$(get_episode "$SEASON_NUMBER" "$EPISODE_NUMBER")" ]; then
                p_error "Unable to find Season $SEASON_NUMBER Episode $EPISODE_NUMBER"
                exit 1
            fi
            p_info "Going to download Season $SEASON_NUMBER Episode $EPISODE_NUMBER"
            download_episode "$SEASON_NUMBER" "$EPISODE_NUMBER"
        else
            p_info "Going to download Season $SEASON_NUMBER"
            download_season "$SEASON_NUMBER"
        fi
    elif [ "$ALL" = true ]; then
        p_info "Going to download ALL episodes"
        download_all
    else
        p_error "Specify a season and episode for South Park download."
        exit 1
    fi
}

# Function to get similar tracks from Last.fm API
function get_similar_tracks_from_lastfm() {
    p_ask "Enter the name of the song you wish to find similar tracks for:"
    read -r track_name
    track_name=$(echo "$track_name" | tr '[:upper:]' '[:lower:]')

    p_ask "Enter the artist name:"
    read -r artist_name
    artist_name=$(echo "$artist_name" | tr '[:upper:]' '[:lower:]')

    # Make the API request to Last.fm
    response=$(curl -s "http://ws.audioscrobbler.com/2.0/?method=track.getsimilar&artist=${artist_name// /%20}&track=${track_name// /%20}&api_key=${API_KEY_LASTFM}&format=json")

    # Check if the API returned an error or empty response
    if echo "$response" | jq -e '.similartracks.track | length > 0' > /dev/null 2>&1; then
        p_info "Tracks similar to '${track_name}' by '${artist_name}':"
        p_info "$response" | jq -r '.similartracks.track[] | "\(.name) by \(.artist.name)"'
    else
        echo "No similar tracks found for '${track_name}' by '${artist_name}'."
    fi
}

# Function to display help
show_help() {
    cat << EOF
Usage: $0 {update|music|media} [options]

Commands:
  update                Check for yt-dlp updates and apply them if needed.
  
  music                 Download music-related content.
    Options:
      -s, --search      Search YouTube for a song and download it.
      --like            Find similar tracks to a specified song using Last.fm.
      -- <url>          Download the music track or playlist from the provided URL.

  media                 Download media (video) content.
    Options:
      -s, --search      Search YouTube for a video and download it.
      -- <url>          Download the media file or playlist from the provided URL.

  help                  Display this help message.

Examples:
  $0 install
  $0 update
  $0 music --search
  $0 music --like
  $0 music -- https://www.youtube.com/watch?v=example
  $0 media --search
  $0 media --southpark -s 1 -e 5
  $0 media --southpark -a -l DE
  $0 media -- https://www.youtube.com/watch?v=example
  $0 version

For more details on a specific command, use '$0 {command} --help'.
EOF
}

# Argument parsing
case "$1" in
    update)
        update_yt_dlp
        ;;
    music)
        shift
        if [[ "$1" == "-s" || "$1" == "--search" ]]; then
            search_and_download download_single_music
        elif [[ "$1" == "--like" ]]; then
            get_similar_tracks_from_lastfm
        else
            if [[ "$1" == "--" ]]; then
                shift
            fi
            if [ -z "$1" ]; then
                log "Error: No URL provided for music."
                p_info "Usage: $0 music -- <url> [options]"
                exit 1
            fi
            url="$1"
            shift
            download_music "$url" "$@"
        fi
        ;;
    media)
        shift
        if [[ "$1" == "-s" || "$1" == "--search" ]]; then
            search_and_download download_single_media
    elif [[ "$1" == "--southpark" ]]; then
        shift
        # Initialize South Park options
        OPT_SEASON=""
        OPT_EPISODE=""
        OPT_LANG="EN"
        OPT_ALL=false
        OPT_PROGRESS=true
        OPT_UPDATE_INDEX=true
        OPT_DRY=false
        OPT_REINIT=false

        # Parse South Park-specific options
        while getopts ":s:e:l:apPdDiU" opt; do
            case "$opt" in
                s) OPT_SEASON="$OPTARG" ;;
                e) OPT_EPISODE="$OPTARG" ;;
                l) 
                    if [[ "$OPTARG" == "EN" || "$OPTARG" == "DE" ]]; then
                        OPT_LANG="$OPTARG"
                    else
                        p_error "Invalid language option! Use 'EN' or 'DE'."
                        exit 1
                    fi
                    ;;
                a) OPT_ALL=true ;;
                p) OPT_PROGRESS=true ;;
                P) OPT_PROGRESS=false ;;
                u) OPT_UPDATE_INDEX=true ;;
                U) OPT_UPDATE_INDEX=false ;;
                d) OPT_DRY=true ;;
                i) OPT_REINIT=true ;;
                \?)
                    p_error "Invalid option: -$OPTARG"
                    exit 1
                    ;;
                :)
                    p_error "Option -$OPTARG requires an argument."
                    exit 1
                    ;;
            esac
        done
        shift $((OPTIND -1))

        # Call download_southpark with parsed options
        download_southpark "$OPT_SEASON" "$OPT_EPISODE" "$OPT_LANG" "$OPT_ALL" "$OPT_PROGRESS" "$OPT_UPDATE_INDEX" "$OPT_DRY" "$OPT_REINIT"
        else
            if [[ "$1" == "--" ]]; then
                shift
            fi
            if [ -z "$1" ]; then
                log "Error: No URL provided for media."
                p_info "Usage: $0 media -- <url> [options]"
                exit 1
            fi
            url="$1"
            shift
            download_media "$url" "$@"
        fi
        ;;
    help|--help)
        show_help
        ;;
    install)
        install_dependencies
        ;;
    version)
        p_info "yt-dlp version: $VERSION"
        exit 0 
        ;;
    *)
        log "Error: Invalid argument $1."
        p_info "Usage: $0 {install|update|music|media|help|version} [options]"
        exit 1
        ;;
esac
