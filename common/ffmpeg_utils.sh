#!/bin/bash

extract_frames_with_time() {
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo -e "Usage: extract_frames_with_time [OPTIONS] <input> [input2] [input3] ..."
    echo -e "\nExtracts frames from video(s) with timestamp labels."
    echo -e "\nOptions (choose one):"
    echo -e "  -dt SECONDS     Extract frames every SECONDS interval (e.g., -dt 20)"
    echo -e "  -n COUNT        Extract COUNT frames evenly spaced (including first and last)"
    echo -e "\nOptional:"
    echo -e "  --fontsize SIZE Font size for labels (default: 24)"
    echo -e "\nExamples:"
    echo -e "  extract_frames_with_time -dt 20 video.mp4                    # Every 20 seconds"
    echo -e "  extract_frames_with_time -n 5 video.mp4                      # 5 evenly spaced frames"
    echo -e "  extract_frames_with_time -n 10 --fontsize 36 video.mp4       # 10 frames, larger text"
    echo -e "  extract_frames_with_time -n 5 video1.mp4 video2.mp4 video3.mp4  # Multiple files"
    echo -e "  extract_frames_with_time -dt 20 *.mp4                        # All mp4 files in dir"
    echo -e "\nOutput:"
    echo -e "  -dt mode: Labels show timestamp (HH:MM:SS)"
    echo -e "  -n mode:  Labels show position (1/N, 2/N, etc.)"
    echo -e "  Each video creates a folder named after the video file."
    return 0
  fi

  # Parse options first
  local mode=""
  local interval=""
  local num_frames=""
  local fontsize=24
  local -a inputs=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -dt)
        mode="interval"
        interval="$2"
        shift 2
        ;;
      -n)
        mode="count"
        num_frames="$2"
        shift 2
        ;;
      --fontsize)
        fontsize="$2"
        shift 2
        ;;
      -*)
        echo "Unknown option: $1"
        return 1
        ;;
      *)
        # Not an option, must be an input file
        inputs+=("$1")
        shift
        ;;
    esac
  done

  if [ -z "$mode" ]; then
    echo "Error: Must specify either -dt or -n"
    echo "Usage: extract_frames_with_time [OPTIONS] <input> [input2] ..."
    return 1
  fi

  if [ ${#inputs[@]} -eq 0 ]; then
    echo "Error: No input file(s) specified"
    echo "Usage: extract_frames_with_time [OPTIONS] <input> [input2] ..."
    return 1
  fi

  # Process each input file
  local total=${#inputs[@]}
  local current=0

  for input in "${inputs[@]}"; do
    ((current++))

    # Check if file exists
    if [ ! -f "$input" ]; then
      echo "[$current/$total] Skipping: '$input' not found"
      continue
    fi

    echo "[$current/$total] Processing: $input"

    # Get base filename without path and extension
    local filename
    filename="$(basename "$input")"
    filename="${filename%.*}"

    # Create output directory in the same folder as the video
    local video_dir
    video_dir="$(dirname "$input")"
    local out_dir="${video_dir}/${filename}"
    mkdir -p "$out_dir"

    # Get video duration
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")

    if [ "$mode" == "interval" ]; then
      # Interval mode: extract every N seconds with timestamp label
      local out_pattern="${out_dir}/frame_%04d.png"

      echo "  Extracting frames every ${interval}s (duration: ${duration}s)"

      ffmpeg -y -loglevel error -i "$input" \
        -vf "select='eq(t\,0)+not(mod(t\,$interval))+gte(t\,$duration-0.1)', \
             drawtext=font=Arial: \
                      text='%{pts \: hms}': \
                      fontcolor=white: fontsize=${fontsize}: \
                      x=w-tw-20: y=h-th-20" \
        -vsync vfr "$out_pattern"

      echo "  -> Saved to ${out_dir}/"

    elif [ "$mode" == "count" ]; then
      # Count mode: extract N evenly spaced frames with 1/N labels
      echo "  Extracting ${num_frames} evenly spaced frames (duration: ${duration}s)"

      for ((i=1; i<=num_frames; i++)); do
        # Calculate timestamp for this frame
        # Frame 1 is at t=0, Frame N is at t=duration (but capped slightly before end)
        local t
        if [ "$num_frames" -eq 1 ]; then
          t=0
        elif [ "$i" -eq "$num_frames" ]; then
          # Last frame: seek slightly before end to ensure we get a valid frame
          t=$(awk "BEGIN{printf \"%.3f\", $duration - 0.1}")
          # Ensure t is not negative for very short videos
          if (( $(awk "BEGIN{print ($t < 0)}") )); then
            t=0
          fi
        else
          t=$(awk "BEGIN{printf \"%.3f\", ($i - 1) * $duration / ($num_frames - 1)}")
        fi

        local label="${i}/${num_frames}"
        local out_file="${out_dir}/frame_$(printf '%04d' $i).png"

        ffmpeg -y -loglevel error -ss "$t" -i "$input" \
          -vf "drawtext=font=Arial:text='${label}':fontcolor=white:fontsize=${fontsize}:x=w-tw-20:y=h-th-20" \
          -vframes 1 "$out_file"
      done

      echo "  -> Saved ${num_frames} frames to ${out_dir}/"
    fi
  done

  echo "Done! Processed $total video(s)"
}


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

ffmpeg_caption() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_caption <input_video> [OPTIONS] -c START,END,\"TEXT\" [-c ...]"
        echo -e "\nAdds timed captions/text overlays to a video."
        echo -e "\nOptions:"
        echo -e "  -c, --caption START,END,\"TEXT\""
        echo -e "                        Add a caption (repeatable for multiple captions)"
        echo -e "                        START: When to show caption (seconds, decimals, or HH:MM:SS.ms)"
        echo -e "                        END: When to hide caption (seconds, decimals, or HH:MM:SS.ms)"
        echo -e "                        TEXT: The caption text (quote if contains spaces)"
        echo -e "  --pos POSITION        Caption position (default: bottom-center)"
        echo -e "                        Options: top-left, top-center, top-right,"
        echo -e "                                 bottom-left, bottom-center, bottom-right"
        echo -e "  --fontsize SIZE       Font size (default: 10% of video height)"
        echo -e "  --fontcolor COLOR     Font color (default: white)"
        echo -e "  --box                 Add a semi-transparent background box behind text"
        echo -e "  --boxcolor COLOR      Box color with opacity (default: black@0.5)"
        echo -e "  -o, --output FILE     Output filename (default: <input>_captioned.<ext>)"
        echo -e "\nExamples:"
        echo -e "  # Single caption from 5s to 8s"
        echo -e "  ffmpeg_caption video.mp4 -c 5,8,\"Hello World\""
        echo -e ""
        echo -e "  # Multiple captions"
        echo -e "  ffmpeg_caption video.mp4 -c 0,2,\"Intro\" -c 5,8,\"Main Part\" -c 10,12,\"Outro\""
        echo -e ""
        echo -e "  # Caption at top-right with custom styling"
        echo -e "  ffmpeg_caption video.mp4 --pos top-right --fontcolor yellow --box -c 2,7,\"Notice\""
        echo -e ""
        echo -e "  # Using time format HH:MM:SS or with milliseconds"
        echo -e "  ffmpeg_caption video.mp4 -c 0:01:30,0:01:40,\"Chapter 2\""
        echo -e "  ffmpeg_caption video.mp4 -c 5.5,8.25,\"Precise timing\""
        echo -e "  ffmpeg_caption video.mp4 -c 0:01:30.500,0:01:33,\"At 1:30.5\""
        return
    fi

    local fullfile=""
    local position="bottom-center"
    local fontsize=""
    local fontcolor="white"
    local use_box=false
    local boxcolor="black@0.5"
    local output_file=""
    local -a captions=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--caption)
                captions+=("$2")
                shift 2
                ;;
            --pos)
                position="$2"
                shift 2
                ;;
            --fontsize)
                fontsize="$2"
                shift 2
                ;;
            --fontcolor)
                fontcolor="$2"
                shift 2
                ;;
            --box)
                use_box=true
                shift
                ;;
            --boxcolor)
                boxcolor="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
            *)
                if [ -z "$fullfile" ]; then
                    fullfile="$1"
                else
                    echo "Error: Multiple input files not supported"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$fullfile" ]; then
        echo "Error: Input video file required"
        echo "Run 'ffmpeg_caption --help' for usage information"
        return 1
    fi

    if [ ! -f "$fullfile" ]; then
        echo "Error: File '$fullfile' not found"
        return 1
    fi

    if [ ${#captions[@]} -eq 0 ]; then
        echo "Error: At least one caption required (-c START,END,\"TEXT\")"
        echo "Run 'ffmpeg_caption --help' for usage information"
        return 1
    fi

    # Validate position
    case "$position" in
        top-left|top-center|top-right|bottom-left|bottom-center|bottom-right)
            ;;
        *)
            echo "Error: Invalid position '$position'"
            echo "Valid positions: top-left, top-center, top-right, bottom-left, bottom-center, bottom-right"
            return 1
            ;;
    esac

    local filename=$(basename -- "$fullfile")
    local directory=$(dirname -- "$fullfile")
    local extension="${filename##*.}"
    filename="${filename%.*}"

    # Set output filename if not specified
    if [ -z "$output_file" ]; then
        output_file="${directory}/${filename}_captioned.${extension}"
    fi

    # Get video dimensions
    local video_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$fullfile")

    # Calculate font size (10% of video height if not specified)
    if [ -z "$fontsize" ]; then
        fontsize=$(awk "BEGIN{printf \"%.0f\", $video_height * 0.1}")
    fi

    # Determine text position based on position parameter
    local text_x
    local text_y

    case "$position" in
        top-left)
            text_x="40"
            text_y="40"
            ;;
        top-center)
            text_x="(w-tw)/2"
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
        bottom-center)
            text_x="(w-tw)/2"
            text_y="h-th-40"
            ;;
        bottom-right)
            text_x="w-tw-40"
            text_y="h-th-40"
            ;;
    esac

    # Build the drawtext filter chain
    local filter_parts=()

    for caption_spec in "${captions[@]}"; do
        # Parse caption: START,END,"TEXT"
        # Use a more robust parsing approach
        local start_time end_time caption_text

        # Split by comma, but handle text that might contain commas
        # Format: START,END,TEXT
        IFS=',' read -r start_time end_time caption_text <<< "$caption_spec"

        # If caption_text is empty but there are more fields, rejoin them
        # This handles cases where text contains commas
        local field_count=$(echo "$caption_spec" | awk -F',' '{print NF}')
        if [ "$field_count" -gt 3 ]; then
            # Text contains commas, need to rejoin fields 3+
            caption_text=$(echo "$caption_spec" | cut -d',' -f3-)
        fi

        # Remove surrounding quotes if present
        caption_text="${caption_text#\"}"
        caption_text="${caption_text%\"}"
        caption_text="${caption_text#\'}"
        caption_text="${caption_text%\'}"

        if [ -z "$start_time" ] || [ -z "$end_time" ] || [ -z "$caption_text" ]; then
            echo "Error: Invalid caption format: '$caption_spec'"
            echo "Expected format: START,END,\"TEXT\""
            return 1
        fi

        # Convert time formats to seconds for calculation
        local start_seconds end_seconds

        # Function to convert HH:MM:SS.ms or seconds to seconds
        convert_to_seconds() {
            local time_str="$1"
            if [[ "$time_str" =~ ^[0-9]+:[0-9]+:[0-9]+\.?[0-9]*$ ]] || [[ "$time_str" =~ ^[0-9]+:[0-9]+\.?[0-9]*$ ]]; then
                # HH:MM:SS.ms or MM:SS.ms format - use awk to convert
                echo "$time_str" | awk -F: '{
                    if (NF == 3) printf "%.3f", ($1 * 3600) + ($2 * 60) + $3
                    else if (NF == 2) printf "%.3f", ($1 * 60) + $2
                    else print $1
                }'
            else
                echo "$time_str"
            fi
        }

        start_seconds=$(convert_to_seconds "$start_time")
        end_seconds=$(convert_to_seconds "$end_time")

        # Escape special characters in caption text for ffmpeg drawtext
        # Escape single quotes, colons, and backslashes
        local escaped_text="$caption_text"
        escaped_text="${escaped_text//\\/\\\\\\\\}"  # Escape backslashes first
        escaped_text="${escaped_text//:/\\:}"         # Escape colons
        escaped_text="${escaped_text//\'/\'\\\'\'}"   # Escape single quotes

        # Build drawtext filter for this caption
        local box_params=""
        if [ "$use_box" = true ]; then
            box_params=":box=1:boxcolor=${boxcolor}:boxborderw=10"
        fi

        local drawtext="drawtext=text='${escaped_text}':x=${text_x}:y=${text_y}:fontcolor=${fontcolor}:fontsize=${fontsize}:font=Arial${box_params}:enable='between(t,${start_seconds},${end_seconds})'"

        filter_parts+=("$drawtext")
    done

    # Join all filter parts with commas
    local video_filter
    video_filter=$(IFS=','; echo "${filter_parts[*]}")

    echo "Adding ${#captions[@]} caption(s) to video..."
    echo "Position: $position, Font size: $fontsize, Color: $fontcolor"

    # Run ffmpeg
    ffmpeg -i "$fullfile" -vf "$video_filter" -c:a copy "$output_file"

    if [ $? -eq 0 ]; then
        echo "Done! Output saved to: $output_file"
    else
        echo "Error: ffmpeg failed"
        return 1
    fi
}

ffmpeg_video_to_gif_batch() {
    # Check for help flag
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_video_to_gif_batch [folder] [--fps N] [--width W | --height H]"
        echo -e "\nBatch converts all .mp4 videos in the specified folder to GIFs using ffmpeg."
        echo -e "\nOptions:"
        echo -e "  [folder]     Folder containing MP4 files. Defaults to current directory."
        echo -e "  --fps N      Frames per second for the GIF. Default: 30"
        echo -e "  --width W    Width of the output GIF (height auto-scales)"
        echo -e "  --height H   Height of the output GIF (width auto-scales)"
        echo -e "\nExample usage:"
        echo -e "  ffmpeg_video_to_gif_batch                              # Current dir, 30 fps, original size"
        echo -e "  ffmpeg_video_to_gif_batch videos                       # 'videos' dir, 30 fps, original size"
        echo -e "  ffmpeg_video_to_gif_batch videos --fps 24 --width 480  # 24 fps, 480px wide"
        echo -e "  ffmpeg_video_to_gif_batch --fps 15 --height 360        # Current dir, 15 fps, 360px tall"
        return 0
    fi

    local folder="."
    local fps=""
    local width=""
    local height=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fps)
                fps="$2"
                shift 2
                ;;
            --width)
                width="$2"
                shift 2
                ;;
            --height)
                height="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                folder="$1"
                shift
                ;;
        esac
    done

    # Check if the specified folder exists
    if [ ! -d "$folder" ]; then
        echo "Error: Folder '$folder' does not exist."
        return 1
    fi

    # Find all .mp4 files in the folder
    local mp4_files=$(find "$folder" -maxdepth 1 -type f -name "*.mp4")

    # Check if any .mp4 files were found
    if [ -z "$mp4_files" ]; then
        echo "No MP4 files found in '$folder'."
        return 0
    fi

    # Build args to pass to ffmpeg_video_to_gif
    local extra_args=""
    [ -n "$fps" ] && extra_args="$extra_args --fps $fps"
    [ -n "$width" ] && extra_args="$extra_args --width $width"
    [ -n "$height" ] && extra_args="$extra_args --height $height"

    # Process each .mp4 file
    for video in $mp4_files; do
        echo "Processing: $video"
        ffmpeg_video_to_gif "$video" $extra_args
    done

    echo "All videos have been processed."
}

ffmpeg_video_to_gif() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_video_to_gif <input_video> [--fps N] [--width W | --height H]"
        echo -e "\nConverts a video to a high-quality GIF using ffmpeg."
        echo -e "\nOptions:"
        echo -e "  --fps N      Frames per second for the GIF. Default: 30"
        echo -e "  --width W    Width of the output GIF (height auto-scales)"
        echo -e "  --height H   Height of the output GIF (width auto-scales)"
        echo -e "\nIf neither --width nor --height is specified, uses original video dimensions."
        echo -e "\nExample usage:"
        echo -e "  ffmpeg_video_to_gif video.mp4                       # 30 fps, original size"
        echo -e "  ffmpeg_video_to_gif video.mp4 --fps 24              # 24 fps, original size"
        echo -e "  ffmpeg_video_to_gif video.mp4 --fps 15 --width 480  # 15 fps, 480px wide"
        echo -e "  ffmpeg_video_to_gif video.mp4 --height 360          # 30 fps, 360px tall"
        return
    fi

    # Check for at least one argument (the input file)
    if [ $# -lt 1 ]; then
        echo "Error: Input video file required"
        echo "Run 'ffmpeg_video_to_gif --help' for usage information"
        return 1
    fi

    local fullfile=""
    local fps=30
    local width=""
    local height=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fps)
                fps="$2"
                shift 2
                ;;
            --width)
                width="$2"
                shift 2
                ;;
            --height)
                height="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$fullfile" ]; then
                    fullfile="$1"
                else
                    echo "Error: Multiple input files not supported"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$fullfile" ]; then
        echo "Error: Input video file required"
        return 1
    fi

    local filename=$(basename -- "$fullfile")
    local directory=$(dirname -- "$fullfile")
    filename="${filename%.*}"

    # Build scale filter and size suffix based on width/height options
    local scale_filter
    local size_suffix=""
    if [ -n "$width" ] && [ -n "$height" ]; then
        echo "Error: Cannot specify both --width and --height"
        return 1
    elif [ -n "$width" ]; then
        scale_filter="scale=${width}:-1:flags=lanczos"
        size_suffix="_width${width}"
    elif [ -n "$height" ]; then
        scale_filter="scale=-1:${height}:flags=lanczos"
        size_suffix="_height${height}"
    else
        # Use original dimensions
        local orig_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$fullfile")
        scale_filter="scale=${orig_width}:-1:flags=lanczos"
    fi

    ffmpeg -i "${fullfile}" -vf "fps=${fps},${scale_filter},split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        -loop 0 "${directory}/${filename}_fps${fps}${size_suffix}.gif"
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
        echo -e "Usage: ffmpeg_cut <input_video> -s TIME [-d TIME | -e TIME]"
        echo -e "\nCuts a portion of a video."
        echo -e "\nOptions:"
        echo -e "  -s, --start TIME      Start time (required). Format: seconds or HH:MM:SS"
        echo -e "  -d, --duration TIME   Duration of the cut. Format: seconds or HH:MM:SS"
        echo -e "  -e, --end TIME        End time (alternative to --duration). Format: seconds or HH:MM:SS"
        echo -e "\nIf neither --duration nor --end is specified, cuts to the end of video."
        echo -e "\nExample usage:"
        echo -e "  ffmpeg_cut video.mp4 -s 10 -d 30          # Cut 30s starting at 10s"
        echo -e "  ffmpeg_cut video.mp4 -s 10 -e 40          # Cut from 10s to 40s"
        echo -e "  ffmpeg_cut video.mp4 -s 1:30 -e 2:00      # Cut from 1:30 to 2:00"
        echo -e "  ffmpeg_cut video.mp4 --start 10           # Cut from 10s to end"
        return
    fi

    local fullfile=""
    local start_time=""
    local duration=""
    local end_time=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--start)
                start_time="$2"
                shift 2
                ;;
            -d|--duration)
                duration="$2"
                shift 2
                ;;
            -e|--end)
                end_time="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$fullfile" ]; then
                    fullfile="$1"
                else
                    echo "Error: Multiple input files not supported"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$fullfile" ]; then
        echo "Error: Input video file required"
        echo "Run 'ffmpeg_cut --help' for usage information"
        return 1
    fi

    if [ -z "$start_time" ]; then
        echo "Error: -s/--start is required"
        echo "Run 'ffmpeg_cut --help' for usage information"
        return 1
    fi

    if [ -n "$duration" ] && [ -n "$end_time" ]; then
        echo "Error: Cannot specify both --duration and --end"
        return 1
    fi

    local filename=$(basename -- "$fullfile")
    local directory=$(dirname -- "$fullfile")
    local extension="${filename##*.}"
    filename="${filename%.*}"

    # Build ffmpeg arguments
    local duration_args=""
    local output_suffix=""

    if [ -n "$duration" ]; then
        duration_args="-t ${duration}"
        output_suffix="_cut_${duration}s"
    elif [ -n "$end_time" ]; then
        duration_args="-to ${end_time}"
        output_suffix="_cut_${start_time}-${end_time}"
    else
        # No duration or end specified - cut to end of video
        local total_duration=$(ffprobe -i "$fullfile" -show_entries format=duration -v quiet -of csv="p=0")
        output_suffix="_cut_from${start_time}s"
    fi

    ffmpeg -ss "${start_time}" ${duration_args} -i "${fullfile}" -c copy "${directory}/${filename}${output_suffix}.${extension}"
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

ffmpeg_stack() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_stack [video1] [video2] ... [videoN] [-o output_file] [-d direction]"
        echo -e "\nStack N videos either horizontally or vertically"
        echo -e "\nOptions:"
        echo -e "  -d    Direction to stack: h (horizontal) or v (vertical). Default: h"
        echo -e "  -o    Output file path. If omitted, auto-generates from common filename parts"
        echo -e "\nExamples:"
        echo -e "  ffmpeg_stack v1.mp4 v2.mp4 -d h                    # 2 videos, horizontal"
        echo -e "  ffmpeg_stack v1.mp4 v2.mp4 v3.mp4 -d v             # 3 videos, vertical"
        echo -e "  ffmpeg_stack v1.mp4 v2.mp4 v3.mp4 v4.mp4 -o out.mp4  # 4 videos with explicit output"
        echo -e "  ffmpeg_stack *.mp4 -d h                            # All mp4 files, horizontal"
        return
    fi

    # Collect video files and parse options
    local -a video_files=()
    local output_path=""
    local direction="h"  # Default to horizontal

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d)
                direction="$2"
                shift 2
                ;;
            -o)
                output_path="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                return 1
                ;;
            *)
                video_files+=("$1")
                shift
                ;;
        esac
    done

    local num_videos=${#video_files[@]}

    # Check if we have at least 2 videos
    if [ $num_videos -lt 2 ]; then
        echo "Error: Need at least 2 video files"
        echo "Run 'ffmpeg_stack --help' for usage information"
        return 1
    fi

    # Validate direction parameter
    if [ "$direction" != "h" ] && [ "$direction" != "v" ]; then
        echo "Error: direction must be either 'h' (horizontal) or 'v' (vertical)"
        return 1
    fi

    # Auto-generate output name if not provided
    if [ -z "$output_path" ]; then
        # Get directory from first file
        local dir1=$(dirname -- "${video_files[0]}")

        # Get all basenames without extensions
        local -a names=()
        for f in "${video_files[@]}"; do
            local base=$(basename -- "$f")
            names+=("${base%.*}")
        done

        # Find common prefix across all files
        local common_prefix="${names[0]}"
        for name in "${names[@]:1}"; do
            local new_prefix=""
            local min_len=${#common_prefix}
            [ ${#name} -lt $min_len ] && min_len=${#name}
            for ((i=0; i<min_len; i++)); do
                if [ "${common_prefix:$i:1}" == "${name:$i:1}" ]; then
                    new_prefix="${new_prefix}${common_prefix:$i:1}"
                else
                    break
                fi
            done
            common_prefix="$new_prefix"
        done

        # Build output name
        if [ -n "$common_prefix" ]; then
            # Remove trailing underscores/dashes
            common_prefix="${common_prefix%%[_-]}"
            output_name="$common_prefix"
        else
            output_name="stacked_${num_videos}"
        fi

        # Add direction suffix
        if [ "$direction" == "h" ]; then
            output_path="${dir1}/${output_name}_hstack.mp4"
        else
            output_path="${dir1}/${output_name}_vstack.mp4"
        fi
        echo "Auto-generated output: $output_path"
    else
        # Handle output format if provided without extension
        if [[ ! "$output_path" =~ \.[a-zA-Z0-9]+$ ]]; then
            output_path="${output_path}.mp4"
        fi
    fi

    # Build ffmpeg input arguments
    local input_args=""
    for f in "${video_files[@]}"; do
        input_args="${input_args} -i \"${f}\""
    done

    # Build scale filter chain
    # For horizontal: scale to match height, preserve aspect ratio
    # For vertical: scale to match width, preserve aspect ratio
    local scale_filter=""
    local scale_expr
    if [ "$direction" == "h" ]; then
        scale_expr="oh*mdar:ih"
    else
        scale_expr="iw:iw/mdar"
    fi

    # First video (index 1) scales relative to video 0
    scale_filter="[1:v][0:v]scale2ref=${scale_expr}[1v][ref1]"

    # Subsequent videos scale relative to the previous reference
    for ((i=2; i<num_videos; i++)); do
        local prev=$((i-1))
        scale_filter="${scale_filter};[${i}:v][ref${prev}]scale2ref=${scale_expr}[${i}v][ref${i}]"
    done

    # Build the stack input labels: [refN-1][1v][2v]...[Nv]
    local last_ref=$((num_videos-1))
    local stack_inputs="[ref${last_ref}]"
    for ((i=1; i<num_videos; i++)); do
        stack_inputs="${stack_inputs}[${i}v]"
    done

    # Stack filter
    local stack_type
    if [ "$direction" == "h" ]; then
        stack_type="hstack"
    else
        stack_type="vstack"
    fi

    # Complete filter complex
    local filter_complex="${scale_filter};${stack_inputs}${stack_type}=inputs=${num_videos},scale='2*trunc(iw/2)':'2*trunc(ih/2)'[v]"

    # Execute ffmpeg
    echo "Stacking ${num_videos} videos ${direction}..."
    eval ffmpeg ${input_args} -filter_complex \
        "\"${filter_complex}\"" \
        -map '"[v]"' -map '"0:a?"' \
        -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p \
        -c:a aac -b:a 192k \
        "\"${output_path}\""
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

    # Filtering settings
    local -a patterns=()    # Include patterns (glob-style)
    local -a excludes=()    # Exclude patterns (glob-style)

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                cat << EOF
Usage: make_video_grid [OPTIONS]

Create a grid video from MP4 files matching pattern <video_name>_<number>.mp4

Options:
    -h, --help              Show this help message

  Input Options:
    --pattern PATTERN       Include only videos matching pattern (glob-style, repeatable)
                            Examples: --pattern "*_cam1*" --pattern "*_cam2*"
    --exclude PATTERN       Exclude videos matching pattern (glob-style, repeatable)
                            Examples: --exclude "*_debug*" --exclude "*_test*"

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
    make_video_grid --pattern "*_cam1*"                          # Only videos matching pattern
    make_video_grid --pattern "*_0.mp4" --pattern "*_1.mp4"      # Multiple include patterns
    make_video_grid --exclude "*_debug*" --exclude "*_test*"     # Exclude matching patterns
    make_video_grid --pattern "run*" --exclude "*_bad*"          # Combine include and exclude

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
            --pattern)
                patterns+=("$2")
                shift 2
                ;;
            --exclude)
                excludes+=("$2")
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
    if (( n == 0 )) || [[ "${videos[0]}" == "*.mp4" ]]; then
        echo "No MP4 files found."
        return 1
    fi

    # Apply pattern filtering (include patterns)
    if (( ${#patterns[@]} > 0 )); then
        local filtered=()
        for v in "${videos[@]}"; do
            local matched=false
            for pattern in "${patterns[@]}"; do
                # Use case statement for reliable glob matching
                case "$v" in
                    $pattern) matched=true; break ;;
                esac
            done
            if [ "$matched" = true ]; then
                filtered+=("$v")
            fi
        done
        videos=("${filtered[@]}")
        n=${#videos[@]}
        if (( n == 0 )); then
            echo "No MP4 files match the specified pattern(s): ${patterns[*]}"
            return 1
        fi
        echo "Pattern filter matched ${n} videos"
    fi

    # Apply exclude filtering
    if (( ${#excludes[@]} > 0 )); then
        local filtered=()
        for v in "${videos[@]}"; do
            local excluded=false
            for pattern in "${excludes[@]}"; do
                # Use case statement for reliable glob matching
                case "$v" in
                    $pattern) excluded=true; break ;;
                esac
            done
            if [ "$excluded" = false ]; then
                filtered+=("$v")
            fi
        done
        videos=("${filtered[@]}")
        n=${#videos[@]}
        if (( n == 0 )); then
            echo "No MP4 files remaining after exclusions: ${excludes[*]}"
            return 1
        fi
        echo "After exclusions: ${n} videos remain"
    fi

    echo "Found ${n} videos after filtering"

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

extract_first_last_frames() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: extract_first_last_frames [folder] [OPTIONS]"
        echo -e "\nRecursively extracts the first and last frame from all videos in a folder."
        echo -e "\nArguments:"
        echo -e "  [folder]              Folder to search. Defaults to current directory."
        echo -e "\nOptions:"
        echo -e "  --pattern PATTERN     Glob pattern for files to include (default: *.mp4)"
        echo -e "  --exclude PATTERN     Glob pattern for files to exclude"
        echo -e "  --dry-run, -n         Show what would be done without extracting"
        echo -e "\nOutput files:"
        echo -e "  <video_name>_t0.png   First frame of the video"
        echo -e "  <video_name>_tf.png   Last frame of the video"
        echo -e "\nExamples:"
        echo -e "  extract_first_last_frames                           # All mp4s in current dir"
        echo -e "  extract_first_last_frames /path/to/videos           # All mp4s in specified dir"
        echo -e "  extract_first_last_frames . --pattern '*.mov'       # Process mov files"
        echo -e "  extract_first_last_frames . --exclude '*_debug*'    # Exclude debug videos"
        echo -e "  extract_first_last_frames . --dry-run               # Preview without extracting"
        return
    fi

    local folder="${1:-.}"
    local pattern="*.mp4"
    local exclude=""
    local dry_run=false

    # Shift past folder argument if provided
    if [[ $# -gt 0 && "$1" != --* && "$1" != "-n" ]]; then
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
            -n|--dry-run)
                dry_run=true
                shift
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

    # Find matching files recursively
    local count=0
    local processed=0

    while IFS= read -r -d '' video; do
        local basename_video=$(basename "$video")

        # Skip if matches exclude pattern
        if [[ -n "$exclude" ]]; then
            if [[ "$basename_video" == $exclude ]]; then
                echo "Skipping (excluded): $video"
                continue
            fi
        fi

        ((count++))

        # Get directory and filename without extension
        local directory=$(dirname "$video")
        local filename="${basename_video%.*}"

        local output_t0="${directory}/${filename}_t0.png"
        local output_tf="${directory}/${filename}_tf.png"

        if [[ "$dry_run" == true ]]; then
            echo "[DRY RUN] Would extract from: $video"
            echo "          -> $output_t0"
            echo "          -> $output_tf"
        else
            echo "Processing: $video"

            # Extract first frame (t=0)
            # Note: < /dev/null prevents ffmpeg from consuming stdin (which breaks the while read loop)
            ffmpeg -y -loglevel error -i "$video" -vf "select=eq(n\,0)" -vframes 1 "$output_t0" < /dev/null

            # Get total frame count and extract last frame
            local total_frames=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$video" < /dev/null)
            local last_frame=$((total_frames - 1))

            ffmpeg -y -loglevel error -i "$video" -vf "select=eq(n\,$last_frame)" -vframes 1 "$output_tf" < /dev/null

            echo "  -> Created: ${filename}_t0.png, ${filename}_tf.png"
            ((processed++))
        fi
    done < <(find "$folder" -type f -name "$pattern" -print0)

    if [[ $count -eq 0 ]]; then
        echo "No matching files found in '$folder' with pattern '$pattern'"
    else
        if [[ "$dry_run" == true ]]; then
            echo -e "\nFound $count video(s) that would be processed"
        else
            echo -e "\n=== Complete: processed $processed video(s) ==="
        fi
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
