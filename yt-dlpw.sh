#!/bin/bash

# Log file for the script (same directory as the script)
LOGFILE="/tmp/yt-dlpw.log"

# Music directory where files will be moved
MUSIC_DIR="$HOME/Music"
VIDEO_DIR="$HOME/Videos/Youtube"

# Function to log output
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOGFILE"
}

# Source the API key from the .env file or .env directory
source_env_file() {
    if [ -f "$HOME/.env" ]; then
        source "$HOME/.env"
    elif [ -f "$HOME/.env/.env" ]; then
        source "$HOME/.env/.env"
    else
        echo "Error: .env file not found in the home directory or in the .env directory."
        exit 1
    fi

    # Ensure the API_KEY_LASTFM is set
    if [ -z "$API_KEY_LASTFM" ]; then
        echo "Error: API_KEY_LASTFM not found in the .env file."
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
            echo "Unsupported operating system: $OS"
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
            echo "Failed to fetch the latest yt-dlp version from GitHub."
            return
        fi
        echo "Latest yt-dlp version: $latest_version"
        git clone https://github.com/yt-dlp/yt-dlp.git
        cd yt-dlp || exit
        git checkout "$latest_version"
        sudo make install
        cd .. && rm -rf yt-dlp

        log "yt-dlp installation completed."
    else
        log "yt-dlp is already installed. Skipping installation from source."
        echo "yt-dlp is already installed. Skipping installation."
    fi

    # Check if script is in /usr/local/bin
    SCRIPT_PATH=$(readlink -f "$0")
    SCRIPT_NAME=$(basename "$SCRIPT_PATH" .sh)  # Remove the .sh extension from the filename
    log "Script is located at: $SCRIPT_PATH"

    if [[ "$SCRIPT_PATH" != "/usr/local/bin/"* ]]; then
        echo "The script is currently located at: $SCRIPT_PATH"
        read -rp "Do you want to move it to /usr/local/bin as '$SCRIPT_NAME'? (y/n): " choice
        case "$choice" in
            y|Y)
                sudo cp "$SCRIPT_PATH" "/usr/local/bin/$SCRIPT_NAME"
                sudo chmod +x "/usr/local/bin/$SCRIPT_NAME"  # Ensure it's executable
                log "Script copied to /usr/local/bin as $SCRIPT_NAME."
                echo "Script successfully moved to /usr/local/bin as $SCRIPT_NAME."
                ;;
            n|N)
                log "User chose not to move the script."
                echo "Script will remain in its current location."
                ;;
            *)
                echo "Invalid input, aborting script move."
                ;;
        esac
    fi

    log "Installation complete."
    echo "Installation complete."
}

# Update yt-dlp version check function
function update_yt_dlp() {
    log "Checking for yt-dlp version..."

    # Get the current version
    current_version=$(yt-dlp --version)
    log "Current yt-dlp version: $current_version"
    echo "Current yt-dlp version: $current_version"

    # Fetch the latest version from GitHub
    latest_version=$(curl -s https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest | jq -r '.tag_name')

    if [[ -z "$latest_version" ]]; then
        log "Failed to fetch the latest version from GitHub."
        echo "Failed to fetch the latest version from GitHub."
        return
    fi

    log "Latest yt-dlp version: $latest_version"
    echo "Latest yt-dlp version: $latest_version"

    # Compare the versions
    if [[ "$current_version" == "$latest_version" ]]; then
        log "yt-dlp is up-to-date."
        echo "yt-dlp is up-to-date."
    else
        log "yt-dlp is out-of-date. Current version: $current_version, Latest version: $latest_version"
        echo "yt-dlp is out-of-date. Current version: $current_version, Latest version: $latest_version"

        # Ask the user if they want to update
        while true; do
            read -rp "Do you want to update yt-dlp to the latest version? (y/n): " choice
            case "$choice" in
                y|Y)
                    echo "Updating yt-dlp..."
                    log "User chose to update yt-dlp."
                    # Run the update using sudo
                    if sudo yt-dlp -U; then
                        log "yt-dlp updated successfully."
                        echo "yt-dlp updated successfully."
                    else
                        log "Error: Failed to update yt-dlp."
                        echo "Error: Failed to update yt-dlp."
                    fi
                    break
                    ;;
                n|N)
                    echo "Update skipped."
                    log "User chose not to update yt-dlp."
                    break
                    ;;
                *)
                    echo "Invalid input, please enter y or n."
                    ;;
            esac
        done

        # Recheck the version after the update attempt
        new_version=$(yt-dlp --version)
        if [[ "$new_version" == "$latest_version" ]]; then
            echo "yt-dlp is now up-to-date (version: $new_version)."
            log "yt-dlp is now up-to-date (version: $new_version)."
        else
            echo "yt-dlp is still outdated. Current version: $new_version, Latest version: $latest_version"
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

    echo "Enter the name of the content you wish to download (song or video):"
    read -r content_name
    content_name=$(echo "$content_name" | tr '[:upper:]' '[:lower:]')

    echo "Enter the uploader/artist name:"
    read -r uploader_name
    uploader_name=$(echo "$uploader_name" | tr '[:upper:]' '[:lower:]')

    query="${content_name} ${uploader_name}"

    # Search YouTube for the content
    echo "Searching YouTube for: $query"
    log "Searching YouTube for: $query"
    
    # Use yt-dlp to search for the top 5 results and get title, uploader, and URL
    search_results=$(yt-dlp "ytsearch5:$query" --print "%(title)s - %(uploader)s" --get-id --skip-download)

    if [[ -z "$search_results" ]]; then
        echo "No results found. Try again with a different search."
        log "No results found for: $query"
        return
    fi

    # Separate the video information (title, uploader) and the URLs for internal use
    titles_and_uploaders=$(echo "$search_results" | awk 'NR % 2 == 1')  # Extract the odd lines (title and uploader)
    video_urls=$(echo "$search_results" | awk 'NR % 2 == 0')            # Extract the even lines (URLs)

    # Output the search results in a numbered list
    echo "Top 5 results:"
    echo "$titles_and_uploaders" | awk '{print NR, $0}'

    # Allow the user to choose which result to download
    echo "Enter the number (1-5) of the video you wish to download:"
    read -r choice
    
    # Extract the URL based on user choice
    chosen_url=$(echo "$video_urls" | awk -v num="$choice" 'NR==num')
    
    if [[ -z "$chosen_url" ]]; then
        echo "Invalid choice. Exiting."
        log "Invalid choice made by user."
        return
    fi
    
    echo "Downloading the selected content..."
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
    echo "Downloading single track: $url"

    output_path="$MUSIC_DIR/%(title)s.%(ext)s"
    log "Setting output path to: $output_path"

    # No background process, run synchronously
    yt-dlp -f bestaudio --extract-audio --audio-format flac --embed-thumbnail --convert-thumbnails jpg --add-metadata --output "$output_path" "$url" "${options[@]}"

    output_file=$(yt-dlp --get-filename -f bestaudio --extract-audio --audio-format flac --output "$output_path" "$url" | sed 's/\.[^.]*$/.flac/')
    
    log "Download and conversion to FLAC completed: $output_file"
    echo "Download complete: $output_file"

    organize_file "$output_file"
}

# Function to download a playlist
function download_playlist() {
    local url="$1"
    shift
    options=("$@")

    echo "Starting download for playlist: $url"
    log "Starting download for playlist: $url"

    # Add debug output to check if yt-dlp starts correctly
    echo "Running yt-dlp to download playlist..."
    log "Running yt-dlp to download playlist..."

    # Enable verbose output from yt-dlp for debugging
    yt-dlp --yes-playlist -v -f bestaudio --extract-audio --audio-format flac --embed-thumbnail --convert-thumbnails jpg --add-metadata --output "$MUSIC_DIR/%(title)s.%(ext)s" "$url"

    # After downloading the playlist, organize the files
    echo "Organizing files after playlist download..."
    log "Organizing files after playlist download..."
    for file in "$MUSIC_DIR"/*.flac; do
        log "Organizing file: $file"
        organize_file "$file"
    done

    echo "Playlist download completed: $url"
    log "Playlist download completed: $url"
}

# Function to download music (handles both single tracks and playlists)
function download_music() {
    local url="$1"
    shift
    options=("$@")

    log "Checking URL: $url"
    echo "Checking URL: $url"

    # Detect if it's a playlist using yt-dlp's JSON output
    is_playlist=$(yt-dlp --flat-playlist -J "$url" | jq -r '.entries | length')

    if [ "$is_playlist" -gt 1 ]; then
        log "Detected a playlist."
        echo "Detected a playlist."
        download_playlist "$url" "${options[@]}"
    else
        log "Detected a single music track."
        echo "Detected a single music track."
        download_single_music "$url" "${options[@]}"
    fi
}

# Function to download a single media file
function download_single_media() {
    local url="$1"
    shift
    options=("$@")

    log "Starting download for single media file: $url"
    echo "Downloading single media file: $url"

    output_path="$VIDEO_DIR/%(title)s.%(ext)s"
    log "Setting output path to: $output_path"

    yt-dlp -f b --embed-thumbnail --add-metadata --output "$output_path" "$url" "${options[@]}"

    output_file=$(yt-dlp --get-filename -f b --output "$output_path" "$url")

    log "Download completed: $output_file"
    echo "Download complete: $output_file"

    organize_file "$output_file" "uploader"
}

# Function to download a media playlist (downloads full videos, not just audio)
function download_media_playlist() {
    local url="$1"
    shift
    options=("$@")

    echo "Starting download for media playlist: $url"
    log "Starting download for media playlist: $url"

    # Download the entire playlist in best video and audio format
    yt-dlp --yes-playlist -f b --embed-thumbnail --add-metadata --output "$VIDEO_DIR/%(title)s.%(ext)s" "$url"

    # Organize the files after download (by uploader)
    echo "Organizing media files after playlist download..."
    log "Organizing media files after playlist download..."
    for file in "$VIDEO_DIR"/*.{mp4,mkv,webm}; do
        if [[ -f "$file" ]]; then
            log "Organizing file: $file"
            organize_file "$file" "uploader"  # Organize by uploader
        fi
    done

    echo "Media playlist download completed: $url"
    log "Media playlist download completed: $url"
}

# Function to download media (similar to music but saves to VIDEO_DIR)
function download_media() {
    local url="$1"
    shift
    options=("$@")

    log "Checking URL: $url"
    echo "Checking URL: $url"

    # Detect if it's a playlist using yt-dlp's JSON output
    is_playlist=$(yt-dlp --flat-playlist -J "$url" | jq -r '.entries | length')

    if [ "$is_playlist" -gt 1 ]; then
        log "Detected a media playlist."
        echo "Detected a media playlist."
        download_media_playlist "$url" "${options[@]}"
    else
        log "Detected a single media file."
        echo "Detected a single media file."
        download_single_media "$url" "${options[@]}"
    fi
}

# Function to get similar tracks from Last.fm API
function get_similar_tracks_from_lastfm() {
    echo "Enter the name of the song you wish to find similar tracks for:"
    read -r track_name
    track_name=$(echo "$track_name" | tr '[:upper:]' '[:lower:]')

    echo "Enter the artist name:"
    read -r artist_name
    artist_name=$(echo "$artist_name" | tr '[:upper:]' '[:lower:]')

    # Make the API request to Last.fm
    response=$(curl -s "http://ws.audioscrobbler.com/2.0/?method=track.getsimilar&artist=${artist_name// /%20}&track=${track_name// /%20}&api_key=${API_KEY_LASTFM}&format=json")

    # Check if the API returned an error or empty response
    if echo "$response" | jq -e '.similartracks.track | length > 0' > /dev/null 2>&1; then
        echo "Tracks similar to '${track_name}' by '${artist_name}':"
        echo "$response" | jq -r '.similartracks.track[] | "\(.name) by \(.artist.name)"'
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
  $0 update
  $0 music --search
  $0 media -- https://www.youtube.com/watch?v=example

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
                echo "Usage: $0 music -- <url> [options]"
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
        else
            if [[ "$1" == "--" ]]; then
                shift
            fi
            if [ -z "$1" ]; then
                log "Error: No URL provided for media."
                echo "Usage: $0 media -- <url> [options]"
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
    *)
        log "Error: Invalid argument $1."
        echo "Usage: $0 {install|update|music|media|help} [options]"
        exit 1
        ;;
esac
