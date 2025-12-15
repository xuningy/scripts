#!/bin/bash

ffmpeg_crf() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_crf [filename_with_ext] [crf](optional, default 23)"
        echo -e "crf values range from 0 to 51. 0 is lossless, 18 is visually lossless, 23 is default, 51 is worst possible."
        return
    fi
    fullfile=$1
    crf=${2:-23}

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    ffmpeg -i ${fullfile} -crf ${crf} "${directory}/${filename}_crf${crf}.${extension}"
}

ffmpeg_speed() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_speed [filename_with_ext] [speed]X [OPTIONS]"
        echo -e "\nAdjusts video playback speed and adds a speed label overlay."
        echo -e "\nArguments:"
        echo -e "  [filename_with_ext]   Input video file"
        echo -e "  [speed]              Speed multiplier (default: 1). Example: 2 for 2x speed, 0.5 for 0.5x"
        echo -e "\nOptions:"
        echo -e "  --label-pos POSITION  Label position: top-left, top-right, bottom-left, bottom-right,"
        echo -e "                        center-left, center-right, top-center, bottom-center, center (default: top-left)"
        echo -e "  --label-color COLOR   Label text color: white or black (default: white)"
        echo -e "  --no-label            Disable speed label overlay"
        echo -e "\nExamples:"
        echo -e "  ffmpeg_speed video.mp4 2                                      # 2x speed with default white label"
        echo -e "  ffmpeg_speed video.mp4 2 --label-pos bottom-right             # 2x speed, label at bottom-right"
        echo -e "  ffmpeg_speed video.mp4 0.5 --label-pos top-center             # 0.5x speed, label at top-center"
        echo -e "  ffmpeg_speed video.mp4 2 --label-color black                  # 2x speed with black text"
        echo -e "  ffmpeg_speed video.mp4 2 --label-pos bottom-left --label-color black  # Black text at bottom-left"
        echo -e "  ffmpeg_speed video.mp4 2 --no-label                           # 2x speed, no label"
        return
    fi

    # Parse arguments
    fullfile=$1
    speed=${2:-1}
    label_pos="top-left"
    label_color="white"
    show_label=true

    # Shift past filename and speed
    shift 2

    # Parse optional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --label-pos)
                label_pos="$2"
                shift 2
                ;;
            --label-color)
                label_color="$2"
                shift 2
                ;;
            --no-label)
                show_label=false
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done

    # Validate label color
    if [ "$label_color" != "white" ] && [ "$label_color" != "black" ]; then
        echo "Error: Invalid label color '$label_color'. Must be 'white' or 'black'"
        return 1
    fi

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # Get video dimensions
    video_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$fullfile")

    # Calculate font size as 20% of video height
    font_size=$(awk "BEGIN{printf \"%.0f\", $video_height * 0.1}")

    # Build the filter chain
    local video_filter="setpts=PTS/${speed}"

    if [ "$show_label" = true ]; then
        # Determine text position based on label_pos
        local text_x
        local text_y

        case "$label_pos" in
            top-left)
                text_x="40"
                text_y="40"
                ;;
            top-right)
                text_x="w-tw-40"
                text_y="40"
                ;;
            bottom-left)
                text_x="40"
                text_y="h-th-40"
                ;;
            bottom-right)
                text_x="w-tw-40"
                text_y="h-th-40"
                ;;
            center-left)
                text_x="40"
                text_y="(h-th)/2"
                ;;
            center-right)
                text_x="w-tw-40"
                text_y="(h-th)/2"
                ;;
            top-center)
                text_x="(w-tw)/2"
                text_y="40"
                ;;
            bottom-center)
                text_x="(w-tw)/2"
                text_y="h-th-40"
                ;;
            center)
                text_x="(w-tw)/2"
                text_y="(h-th)/2"
                ;;
            *)
                echo "Error: Invalid label position '$label_pos'"
                echo "Valid positions: top-left, top-right, bottom-left, bottom-right,"
                echo "                 center-left, center-right, top-center, bottom-center, center"
                return 1
                ;;
        esac

        # Add drawtext filter with speed label (Arial font, no background)
        video_filter="${video_filter},drawtext=text='${speed}x':x=${text_x}:y=${text_y}:fontcolor=${label_color}:fontsize=${font_size}:font=Arial"
    fi

    # Apply speed filter and optionally add label
    ffmpeg -i ${fullfile} -filter:v "${video_filter}" -filter:a "atempo=${speed}" "${directory}/${filename}_${speed}X.${extension}"
}

ffmpeg_video_to_gif_batch() {
    # Check for help flag
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_video_to_gif_batch [folder] [fps] [scale]"
        echo -e "\nBatch converts all .mp4 videos in the specified folder to GIFs using ffmpeg."
        echo -e "\nArguments:"
        echo -e "  [folder]  (Optional) Folder containing MP4 files. Defaults to the current directory."
        echo -e "  [fps]     (Optional) Frames per second for the GIF. Defaults to 30."
        echo -e "  [scale]   (Optional) Width of the output GIF. Defaults to the video's original width."
        echo -e "\nExample usage:"
        echo -e "  ./ffmpeg_video_to_gif_batch          # Converts all MP4s in the current directory"
        echo -e "  ./ffmpeg_video_to_gif_batch videos   # Converts all MP4s in 'videos' directory"
        echo -e "  ./ffmpeg_video_to_gif_batch videos 24 480  # Converts with 24 fps and width 480px"
        exit 0
    fi
    folder="${1:-.}"  # Default to current directory if no folder is specified
    fps="${2:-30}"    # Default to 30 fps
    scale="$3"        # Default to original width if not provided

    # Check if the specified folder exists
    if [ ! -d "$folder" ]; then
        echo "Error: Folder '$folder' does not exist."
        exit 1
    fi

    # Find all .mp4 files in the folder
    mp4_files=$(find "$folder" -maxdepth 1 -type f -name "*.mp4")

    # Check if any .mp4 files were found
    if [ -z "$mp4_files" ]; then
        echo "No MP4 files found in '$folder'."
        exit 0
    fi

    # Process each .mp4 file
    for video in $mp4_files; do
        echo "Processing: $video"
        ffmpeg_video_to_gif "$video" "$fps" "$scale"
    done

    echo "All videos have been processed."
}

ffmpeg_video_to_gif() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_video_to_gif <input_video> [fps] [scale]"
        echo -e "\nConverts a video to a high-quality GIF using ffmpeg."
        echo -e "\nArguments:"
        echo -e "  <input_video>   Path to the input video file."
        echo -e "  [fps]          (Optional) Frames per second for the GIF. Defaults to 30."
        echo -e "  [scale]        (Optional) Width of the output GIF. Defaults to the video's original width."
        echo -e "\nExample usage:"
        echo -e "  ffmpeg_video_to_gif video.mp4         # Uses defaults: 30 fps, original width"
        echo -e "  ffmpeg_video_to_gif video.mp4 24 480  # 24 fps, scaled to 480px width"
        return
    fi

    fullfile=$1
    fps=${2:-30}
    scale=$3

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # Get the original resolution if scale is not provided
    if [ -z "$scale" ]; then
        scale=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fullfile")
    fi

    ffmpeg -i "${fullfile}" -vf "fps=${fps},scale=${scale}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    -loop 0 "${directory}/${filename}_fps${fps}.gif"
}

ffmpeg_img_to_gif() {
  # Help message
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ffmpeg_img_to_gif [-d duration] [-o output.gif] img1 img2 ..."
    echo "Creates a GIF from a list of images using ffmpeg."
    echo
    echo "Options:"
    echo "  -d, --duration    Duration per image (in seconds, default: 0.3)"
    echo "  -o, --output      Output GIF filename (default: output.gif)"
    echo "  -h, --help        Show this help message and exit"
    echo
    echo "Example:"
    echo "  ffmpeg_img_to_gif -d 0.5 -o my.gif img1.png img2.jpg img3.png"
    return 0
  fi

  # Default values
  local duration=0.3
  local output="output.gif"
  local images=()

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--duration)
        duration="$2"
        shift 2
        ;;
      -o|--output)
        output="$2"
        shift 2
        ;;
      *)
        images+=("$1")
        shift
        ;;
    esac
  done

  # Validate input
  if [[ ${#images[@]} -eq 0 ]]; then
    echo "No images specified."
    echo "Try: ffmpeg_img_to_gif --help"
    return 1
  fi

  # Build input file list for ffmpeg
  local listfile
  listfile=$(mktemp)
  for img in "${images[@]}"; do
    # Convert to absolute path to avoid path resolution issues
    if [[ "$img" = /* ]]; then
      # Already absolute path
      abs_img="$img"
    else
      # Convert relative path to absolute
      abs_img="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")"
    fi
    echo "file '$abs_img'" >> "$listfile"
    echo "duration $duration" >> "$listfile"
  done

  # The last image should not specify duration again (ffmpeg quirk)
  sed -i '$d' "$listfile"

  ffmpeg -f concat -safe 0 -i "$listfile" -vf "palettegen" -y /tmp/palette.png
  ffmpeg -f concat -safe 0 -i "$listfile" -i /tmp/palette.png -lavfi "paletteuse" -y "$output"

  rm -f "$listfile" /tmp/palette.png
}


ffmpeg_cut() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_cut [filename_with_ext] [start_time (s)] [duration (s)] (optional, defaults to the end of video)"
        return
    fi
    fullfile=$1
    start_time=$2
    duration=$3

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # Get the total duration of the video if duration is not provided
    if [ -z "$duration" ]; then
        total_old_duration=$(ffprobe -i "$fullfile" -show_entries format=duration -v quiet -of csv="p=0")
        duration=$(awk "BEGIN {print $total_old_duration - $start_time}")
    fi

    ffmpeg -ss ${start_time} -t ${duration} -i ${fullfile} "${directory}/${filename}_cut_${duration}s.${extension}"
}

ffmpeg_img_to_video() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_img_to_video [pattern](e.g., rgb_%d.png) [start_number](OPTIONAL, 0 otherwise) [output_filename](OPTIONAL)"
        return
    fi

    pattern=$1
    start_number="${2:-0}" # Default to 0 if not provided
    default_output_filename=$(echo ${pattern} | cut -d'%' -f1)
    output_filename="${3:-$default_output_filename.mp4}"

    ffmpeg -framerate 30 -start_number ${start_number} -i ${pattern} -c:v libx264 -pix_fmt yuv420p ${output_filename}
}

ffmpeg_stack_two_videos() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_stack_two_videos [file_1] [file_2] [output_file] [-d direction]"
        echo -e "\nStack two videos either horizontally or vertically"
        echo -e "\nOptions:"
        echo -e "  -d    Direction to stack: h (horizontal) or v (vertical). Default: h"
        echo -e "\nExamples:"
        echo -e "  ffmpeg_stack_two_videos video1.mp4 video2.mp4 output.mp4 -d h  # Stack horizontally"
        echo -e "  ffmpeg_stack_two_videos video1.mp4 video2.mp4 output.mp4 -d v  # Stack vertically"
        echo -e "  ffmpeg_stack_two_videos video1.mp4 video2.mp4 output          # Stack horizontally, auto-adds .mp4"
        return
    fi

    # Check if we have at least 3 arguments
    if [ $# -lt 3 ]; then
        echo "Error: Not enough arguments"
        echo "Run 'ffmpeg_stack_two_videos --help' for usage information"
        return 1
    fi

    fullfile_1=$1
    fullfile_2=$2
    output_path=$3
    direction="h"  # Default to horizontal

    # Parse optional arguments
    shift 3
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d)
                direction="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate direction parameter
    if [ "$direction" != "h" ] && [ "$direction" != "v" ]; then
        echo "Error: direction must be either 'h' (horizontal) or 'v' (vertical)"
        return 1
    fi

    # Handle output format
    if [[ ! "$output_path" =~ \.[a-zA-Z0-9]+$ ]]; then
        output_path="${output_path}.mp4"
    fi

    # Get directory of output path
    output_directory=$(dirname -- "$output_path")

    # Set the stack filter based on direction
    if [ "$direction" == "h" ]; then
        stack_filter="hstack=2"
        scale_filter="[1:v][0:v]scale2ref=oh*mdar:ih[1v][ref1]"
    else
        stack_filter="vstack=2"
        scale_filter="[1:v][0:v]scale2ref=iw:iw/mdar[1v][ref1]"
    fi

    # This filter complex will:
    # 1. Scale the second video to match either height (for horizontal) or width (for vertical) of the first video
    # 2. Stack them according to the specified direction
    # 3. Ensure the final dimensions are even numbers (required for some codecs)
    ffmpeg -i ${fullfile_1} -i ${fullfile_2} -filter_complex \
        "${scale_filter};[ref1][1v]${stack_filter},scale='2*trunc(iw/2)':'2*trunc(ih/2)'" \
        "${output_path}"
}

ffmpeg_stack_three_videos() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_stack_three_videos [file_1] [file_2] [file_3] [output_file] [-d direction]"
        echo -e "\nStack three videos either horizontally or vertically"
        echo -e "\nOptions:"
        echo -e "  -d    Direction to stack: h (horizontal) or v (vertical). Default: h"
        echo -e "\nExamples:"
        echo -e "  ffmpeg_stack_three_videos v1.mp4 v2.mp4 v3.mp4 output.mp4 -d h  # Stack horizontally"
        echo -e "  ffmpeg_stack_three_videos v1.mp4 v2.mp4 v3.mp4 output.mp4 -d v  # Stack vertically"
        echo -e "  ffmpeg_stack_three_videos v1.mp4 v2.mp4 v3.mp4 output          # Stack horizontally, auto-adds .mp4"
        return
    fi

    # Check if we have at least 4 arguments
    if [ $# -lt 4 ]; then
        echo "Error: Not enough arguments"
        echo "Run 'ffmpeg_stack_three_videos --help' for usage information"
        return 1
    fi

    fullfile_1=$1
    fullfile_2=$2
    fullfile_3=$3
    output_path=$4
    direction="h"  # Default to horizontal

    # Parse optional arguments
    shift 4
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d)
                direction="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate direction parameter
    if [ "$direction" != "h" ] && [ "$direction" != "v" ]; then
        echo "Error: direction must be either 'h' (horizontal) or 'v' (vertical)"
        return 1
    fi

    # Handle output format
    if [[ ! "$output_path" =~ \.[a-zA-Z0-9]+$ ]]; then
        output_path="${output_path}.mp4"
    fi

    # Set the stack filter based on direction
    if [ "$direction" == "h" ]; then
        stack_filter="hstack=3"
        scale_filter="[1:v][0:v]scale2ref=oh*mdar:ih[1v][ref1];[2:v][ref1]scale2ref=oh*mdar:ih[2v][ref2]"
    else
        stack_filter="vstack=3"
        scale_filter="[1:v][0:v]scale2ref=iw:iw/mdar[1v][ref1];[2:v][ref1]scale2ref=iw:iw/mdar[2v][ref2]"
    fi

    # This filter complex will:
    # 1. Scale the second and third videos to match either height (for horizontal) or width (for vertical) of the first video
    # 2. Stack them according to the specified direction
    # 3. Ensure the final dimensions are even numbers (required for some codecs)
    ffmpeg -i ${fullfile_1} -i ${fullfile_2} -i ${fullfile_3} -filter_complex \
        "${scale_filter};[ref2][1v][2v]${stack_filter},scale='2*trunc(iw/2)':'2*trunc(ih/2)'" \
        "${output_path}"
}

ffmpeg_all() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Compresses all video files in the dir that this command is run in using CRF 23, renamed to _compressed.mp4."
        echo -e "Usage: ffmpeg_all --overwrite (OPTIONAL) --delete-original (OPTIONAL)"
        return
    fi

    # Define supported video extensions in a regex pattern
    supported_extensions="mp4|mkv|avi|mov"
    delete_original=false
    overwrite=false

    # Parse command-line arguments
    for arg in "$@"; do
        case $arg in
            --delete-original)
                echo -e "${LTRED}WARNING: Original files will be deleted!${NC}"
                delete_original=true
                ;;
            --overwrite)
                overwrite=true
                ;;
        esac
    done

    # Set ffmpeg overwrite option based on the flag
    if $overwrite; then
        ffmpeg_options="-y"  # Overwrite the output file
    else
        ffmpeg_options="-n"  # Do not overwrite; skip existing files
    fi

    # Loop over each file in the directory
    for file in *; do
        # Check if the file has one of the supported extensions
        if [[ -f "$file" && "$file" =~ \.($supported_extensions)$ && ! "$file" =~ compressed ]]; then
            original_size_hr=$(du -h "$file" | cut -f1)
            echo -e "${CYAN}Compressing file ${LTCYAN}$file ${LTCYAN}($original_size_hr)${NC}"

            # Define the output filename
            output="${file%.*}_compressed.mp4"

            # Compress the video using ffmpeg
            ffmpeg $ffmpeg_options -i "$file" -crf 23 "$output" -hide_banner -loglevel quiet

            # Check if the compression was successful
            if [[ $? -eq 0 ]]; then
                # Display the new file size
                new_size_hr=$(du -h "$output" | cut -f1)
                echo -e "${CYAN}...complete. ${LTCYAN}$output${CYAN} (${LTCYAN}$new_size_hr${CYAN})${NC}"

                # Delete the original file if the flag was set
                if $delete_original; then
                    echo -e "${LTRED}Deleting original: $file${NC}"
                    rm "$file"
                fi
            fi
        fi
    done
}

make_video_grid() {
    # Default settings
    local show_title=true
    local title_padding=80
    local max_width=640
    local padding_percent=2
    local output_file=""
    local freeze_frame_offset=3  # Freeze on Nth-to-last frame (3 = third-to-last)

    # Label settings
    local show_labels=true
    local label_size=24
    local label_color="white"
    local label_position="bottom"  # bottom or top
    local label_format="%s"  # %s will be replaced with the number
    local label_box=true
    local label_box_color="black@0.5"

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                cat << EOF
Usage: make_video_grid [OPTIONS]

Create a grid video from MP4 files matching pattern <video_name>_<number>.mp4

Options:
    -h, --help              Show this help message

  Title Options:
    --no-title              Hide the title at the top of the grid
    --title-padding SIZE    Padding height for title area in pixels (default: 80)

  Grid Options:
    --width WIDTH           Maximum width for each video cell (default: 640)
    --padding PERCENT       Black bar padding percentage for top/bottom (default: 2)
    --freeze-offset N       Freeze on Nth-to-last frame (default: 3)

  Label Options (numbers on each video):
    --no-labels             Hide the numbers/labels on each video
    --label-size SIZE       Font size for labels (default: 24)
    --label-color COLOR     Color for labels (default: white)
                            Examples: white, red, yellow, #FF0000
    --label-position POS    Position of labels: bottom or top (default: bottom)
    --label-format FORMAT   Format string for labels (default: "%s")
                            Examples: "%s", "Video %s", "#%s", "Cam %s"
    --no-label-box          Hide the background box behind labels
    --label-box-color COLOR Box color with transparency (default: black@0.5)
                            Examples: black@0.5, blue@0.3, red@0.8

  Output Options:
    --output FILE           Output filename (default: <video_name>_grid.mp4)

Examples:
    make_video_grid                                             # Use all defaults
    make_video_grid --no-title                                  # Grid without title
    make_video_grid --width 800 --padding 3                     # Custom width and padding
    make_video_grid --title-padding 100                         # More space for title
    make_video_grid --output my_grid.mp4                        # Custom output filename
    make_video_grid --freeze-offset 1                           # Freeze on last frame
    make_video_grid --no-labels                                 # Hide video numbers
    make_video_grid --label-size 36 --label-color yellow        # Bigger yellow labels
    make_video_grid --label-format "Camera %s"                  # Show "Camera 0", "Camera 1", etc.
    make_video_grid --label-position top                        # Labels at top of each video
    make_video_grid --no-label-box                              # No background box on labels
    make_video_grid --label-box-color "blue@0.8"                # Blue semi-transparent box

Expected input: MP4 files named like experiment_0.mp4, experiment_1.mp4, etc.
Output: Videos arranged in a grid with individual frame numbers and optional title.

Note: Videos that finish early and are frozen will show a checkmark (✓) next to their label.

EOF
                return 0
                ;;
            --no-title)
                show_title=false
                shift
                ;;
            --title-padding)
                title_padding="$2"
                shift 2
                ;;
            --width)
                max_width="$2"
                shift 2
                ;;
            --padding)
                padding_percent="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --freeze-offset)
                freeze_frame_offset="$2"
                shift 2
                ;;
            --no-labels)
                show_labels=false
                shift
                ;;
            --label-size)
                label_size="$2"
                shift 2
                ;;
            --label-color)
                label_color="$2"
                shift 2
                ;;
            --label-position)
                label_position="$2"
                shift 2
                ;;
            --label-format)
                label_format="$2"
                shift 2
                ;;
            --no-label-box)
                label_box=false
                shift
                ;;
            --label-box-color)
                label_box_color="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done

    # Detect mp4 files in current directory matching pattern <video_name>_<number>.mp4
    local videos=( *.mp4 )
    local n=${#videos[@]}
    if (( n == 0 )); then
        echo "No MP4 files found."
        return 1
    fi

    # Extract common video name by finding pattern <name>_<number>.mp4
    local common_name=""
    local video_numbers=()

    for v in "${videos[@]}"; do
        # Match pattern: <name>_<number>.mp4
        if [[ "$v" =~ ^(.+)_([0-9]+)\.mp4$ ]]; then
            local base_name="${BASH_REMATCH[1]}"
            local num="${BASH_REMATCH[2]}"

            if [ -z "$common_name" ]; then
                common_name="$base_name"
            elif [ "$common_name" != "$base_name" ]; then
                echo "Warning: Mixed video name patterns detected ('$common_name' vs '$base_name')"
            fi

            video_numbers+=("$num")
        else
            # Fallback: use filename without extension
            video_numbers+=("${v%.mp4}")
        fi
    done

    # Detect duration and framerate of each video and find the longest
    echo "Detecting video durations and framerates..."
    local durations=()
    local framerates=()
    local max_duration=0
    for v in "${videos[@]}"; do
        local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$v")
        local fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$v")
        # Convert fps from fraction to decimal
        local fps_decimal=$(awk "BEGIN{print $fps}")
        durations+=("$duration")
        framerates+=("$fps_decimal")
        # Compare durations (use awk for float comparison)
        local is_longer=$(awk "BEGIN{print ($duration > $max_duration)}")
        if (( $(echo "$is_longer == 1" | bc -l) )); then
            max_duration=$duration
        fi
    done
    echo "Longest video duration: ${max_duration}s"

    # Get dimensions from first video (assuming all have the same aspect ratio)
    echo "Detecting video dimensions..."
    local orig_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "${videos[0]}")
    local orig_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "${videos[0]}")
    echo "Original video size: ${orig_width}x${orig_height}"

    # Scale to max width (from parameter), maintaining aspect ratio
    local cell_width=$max_width
    local scaled_height=$(awk "BEGIN{printf \"%.0f\", $orig_height * ($cell_width / $orig_width)}")
    echo "Scaled video size: ${cell_width}x${scaled_height}"

    # Add padding (from parameter) black bar to top and bottom of scaled height
    local padding=$(awk "BEGIN{printf \"%.0f\", $scaled_height * ($padding_percent / 100.0)}")
    local cell_height=$((scaled_height + 2 * padding))
    echo "Cell size with padding: ${cell_width}x${cell_height} (padding: ${padding}px = ${padding_percent}% top/bottom)"

    # Calculate grid size (try for square grid)
    local rows
    local cols
    cols=$(awk "BEGIN{print int(sqrt($n) + 0.999)}")
    rows=$(awk "BEGIN{print int(($n + $cols - 1) / $cols)}")

    # Build filter_complex
    # First scale all videos to the same size, freeze last frame if needed, and add text labels
    local filters=""
    for i in "${!videos[@]}"; do
        local label="${video_numbers[$i]}"
        local duration="${durations[$i]}"

        # Calculate how much to pad (freeze last frame)
        local pad_duration=$(awk "BEGIN{printf \"%.3f\", $max_duration - $duration}")

        # Calculate frame duration and trim to Nth-to-last frame (based on freeze_frame_offset)
        local fps="${framerates[$i]}"
        local frame_duration=$(awk "BEGIN{printf \"%.6f\", 1.0 / $fps}")
        local frames_to_trim=$((freeze_frame_offset - 1))
        local trim_duration=$(awk "BEGIN{printf \"%.6f\", $frames_to_trim * $frame_duration}")
        local trim_end=$(awk "BEGIN{printf \"%.6f\", $duration - $trim_duration}")

        # Build label text with format
        local label_text=$(printf "$label_format" "$label")

        # Add checkmark if video finishes early (needs freezing)
        if (( $(awk "BEGIN{print ($pad_duration > 0.01)}") )); then
            label_text="${label_text} ✓"
        fi

        # Build drawtext filter for label (if enabled)
        local drawtext_filter=""
        if [ "$show_labels" = true ]; then
            # Determine Y position based on label_position
            local label_y
            if [ "$label_position" = "top" ]; then
                label_y="40"
            else
                label_y="h-40"
            fi

            # Build box parameters
            local box_params=""
            if [ "$label_box" = true ]; then
                box_params=":box=1:boxcolor=${label_box_color}"
            fi

            drawtext_filter=",drawtext=text='${label_text}':x=(w-tw)/2:y=${label_y}:fontcolor=${label_color}:fontsize=${label_size}${box_params}"
        fi

        # Build filter chain: scale maintaining aspect ratio, add black bars, trim frames, freeze, then optionally add text
        if (( $(awk "BEGIN{print ($pad_duration > 0.01)}") )); then
            # Trim off last N-1 frames, then freeze on Nth-to-last frame
            local freeze_duration=$(awk "BEGIN{printf \"%.3f\", $pad_duration + $trim_duration}")
            filters="${filters}[$i:v]fps=${fps},scale=${cell_width}:-1,pad=${cell_width}:${cell_height}:0:${padding}:black,trim=0:${trim_end},setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=${freeze_duration},setpts=PTS-STARTPTS${drawtext_filter}[v$i]; "
        else
            # Just trim off last N-1 frames and freeze on Nth-to-last frame
            filters="${filters}[$i:v]fps=${fps},scale=${cell_width}:-1,pad=${cell_width}:${cell_height}:0:${padding}:black,trim=0:${trim_end},setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=${trim_duration},setpts=PTS-STARTPTS${drawtext_filter}[v$i]; "
        fi
    done

    # Gather label references
    local refs=""
    for i in "${!videos[@]}"; do
        refs="${refs}[v$i]"
    done

    # Build xstack layout with proper positioning
    local layout=""
    for ((r=0; r < rows; r++)); do
        for ((c=0; c < cols; c++)); do
            idx=$((r*cols+c))
            if (( idx < n )); then
                local x=$((c * cell_width))
                local y=$((r * cell_height))
                if [ -n "$layout" ]; then
                    layout="${layout}|"
                fi
                layout="${layout}${x}_${y}"
            fi
        done
    done

    # Calculate total grid dimensions
    local grid_width=$((cols * cell_width))
    local grid_height=$((rows * cell_height))

    # The xstack filter arranges the videos in a grid, then add common title at top if enabled
    if [ "$show_title" = true ] && [ -n "$common_name" ]; then
        # Add padding for title at the top (use configured value)
        local padded_height=$((grid_height + title_padding))

        # Create grid, scale for even dimensions, add top padding, then draw title in padded area with Arial font
        filters="${filters}${refs}xstack=layout=${layout}:inputs=${n}[outv];[outv]scale='2*trunc(iw/2)':'2*trunc(ih/2)'[scaled];[scaled]pad=${grid_width}:${padded_height}:0:${title_padding}:black[padded];[padded]drawtext=text='${common_name}':x=(w-tw)/2:y=(${title_padding}-th)/2:font=Arial:fontcolor=white:fontsize=36:box=1:boxcolor=black@0.7[final]"
    else
        filters="${filters}${refs}xstack=layout=${layout}:inputs=${n}[outv];[outv]scale='2*trunc(iw/2)':'2*trunc(ih/2)'[final]"
    fi

    # Use provided output filename or auto-generate based on common video name
    if [ -z "$output_file" ]; then
        output_file="${common_name:-output}_GRID.mp4"
    fi

    # Use appropriate log level based on verbosity
    local loglevel="error"
    if [ "${FFMPEG_VERBOSE:-false}" = "true" ]; then
        loglevel="info"
    fi

    echo "Creating grid video: $output_file"
    echo "Processing ${#videos[@]} input videos"

    # Build the complete ffmpeg command with all inputs
    local ffmpeg_cmd=(ffmpeg -loglevel "$loglevel" -y -vsync cfr)

    # Add all input files
    for v in "${videos[@]}"; do
        ffmpeg_cmd+=(-i "$v")
    done

    # Add the rest of the command
    ffmpeg_cmd+=(-filter_complex "$filters" -map "[final]" -c:v libx264 -crf 23 -pix_fmt yuv420p "$output_file")

    # Debug: Show the command (first 200 chars)
    echo "Command built with ${#ffmpeg_cmd[@]} arguments"
    if [ "${FFMPEG_VERBOSE:-false}" = "true" ]; then
        printf '%s ' "${ffmpeg_cmd[@]:0:10}"
        echo "..."
    fi

    # Execute the command
    echo "Executing ffmpeg..."
    "${ffmpeg_cmd[@]}"
    local result=$?

    if [ $result -eq 0 ]; then
        echo "✓ Grid video created successfully"
    else
        echo "✗ ffmpeg exited with code $result"
    fi

    return $result
}


ffmpeg_chop_video() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_chop_video [filename_with_ext]"
        echo -e "\nSplits a wide video horizontally in half, creating left and right halves."
        echo -e "\nOutput files:"
        echo -e "  <filename>_left.<ext>   Left half of the video"
        echo -e "  <filename>_right.<ext>  Right half of the video"
        echo -e "\nExample:"
        echo -e "  ffmpeg_chop_video wide_video.mp4"
        return
    fi

    fullfile=$1

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # Get video width
    video_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$fullfile")
    half_width=$((video_width / 2))

    echo "Video width: ${video_width}px, splitting at ${half_width}px"

    # Extract left half
    echo "Extracting left half..."
    ffmpeg -i "$fullfile" -vf "crop=${half_width}:ih:0:0" -c:a copy "${directory}/${filename}_left.${extension}"

    # Extract right half
    echo "Extracting right half..."
    ffmpeg -i "$fullfile" -vf "crop=${half_width}:ih:${half_width}:0" -c:a copy "${directory}/${filename}_right.${extension}"

    echo "Done! Created:"
    echo "  ${directory}/${filename}_left.${extension}"
    echo "  ${directory}/${filename}_right.${extension}"
}

ffmpeg_chop_video_batch() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_chop_video_batch [folder] [OPTIONS]"
        echo -e "\nBatch splits wide videos horizontally in half."
        echo -e "\nArguments:"
        echo -e "  [folder]              Folder containing videos. Defaults to current directory."
        echo -e "\nOptions:"
        echo -e "  --pattern PATTERN     Glob pattern for files to include (default: *.mp4)"
        echo -e "  --exclude PATTERN     Glob pattern for files to exclude (e.g., *_viewport.mp4)"
        echo -e "\nExamples:"
        echo -e "  ffmpeg_chop_video_batch                                    # All mp4s in current dir"
        echo -e "  ffmpeg_chop_video_batch /path/to/videos                    # All mp4s in specified dir"
        echo -e "  ffmpeg_chop_video_batch . --exclude '*_viewport.mp4'       # Exclude viewport files"
        echo -e "  ffmpeg_chop_video_batch . --pattern '*.mov'                # Process mov files instead"
        return
    fi

    local folder="${1:-.}"
    local pattern="*.mp4"
    local exclude=""

    # Shift past folder argument if provided
    if [[ $# -gt 0 && "$1" != --* ]]; then
        shift
    fi

    # Parse optional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pattern)
                pattern="$2"
                shift 2
                ;;
            --exclude)
                exclude="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done

    # Check if the specified folder exists
    if [ ! -d "$folder" ]; then
        echo "Error: Folder '$folder' does not exist."
        return 1
    fi

    # Find matching files
    local count=0
    local processed=0

    for video in "$folder"/$pattern; do
        # Skip if no matches (glob returns pattern itself)
        [[ -e "$video" ]] || continue

        # Skip if matches exclude pattern
        if [[ -n "$exclude" ]]; then
            local basename_video=$(basename "$video")
            if [[ "$basename_video" == $exclude ]]; then
                echo "Skipping (excluded): $video"
                continue
            fi
        fi

        # Skip files that are already chopped (contain _left or _right)
        if [[ "$video" == *_left.* ]] || [[ "$video" == *_right.* ]]; then
            echo "Skipping (already chopped): $video"
            continue
        fi

        ((count++))
        echo -e "\n=== Processing ($count): $video ==="
        ffmpeg_chop_video "$video"
        ((processed++))
    done

    if [[ $count -eq 0 ]]; then
        echo "No matching files found in '$folder' with pattern '$pattern'"
    else
        echo -e "\n=== Batch complete: processed $processed video(s) ==="
    fi
}

# Recursively rename all files ending with _env.mp4 to .mp4
rename_env_mp4() {
    local target_dir="${1:-.}"
    local dry_run=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            *)
                target_dir="$1"
                shift
                ;;
        esac
    done

    # Check if directory exists
    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Directory '$target_dir' does not exist"
        return 1
    fi

    # Find and rename files
    local count=0
    while IFS= read -r -d '' file; do
        local new_name="${file%_env.mp4}.mp4"

        if [[ "$dry_run" == true ]]; then
            echo "[DRY RUN] Would rename: $file -> $new_name"
        else
            echo "Renaming: $file -> $new_name"
            mv "$file" "$new_name"
        fi
        ((count++))
    done < <(find "$target_dir" -type f -name "*_env.mp4" -print0)

    if [[ $count -eq 0 ]]; then
        echo "No files ending with '_env.mp4' found in $target_dir"
    else
        if [[ "$dry_run" == true ]]; then
            echo "Found $count file(s) that would be renamed"
        else
            echo "Successfully renamed $count file(s)"
        fi
    fi
}
