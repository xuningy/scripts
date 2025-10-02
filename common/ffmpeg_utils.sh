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
        echo -e "Usage: ffmpeg_speed [filename_with_ext] [speed]X (default 1)"
        return
    fi
    fullfile=$1
    speed=${2:-1}

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    ffmpeg -i ${fullfile} -filter:v setpts=PTS/${speed} "${directory}/${filename}_${speed}X.${extension}"
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