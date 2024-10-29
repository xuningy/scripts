#!/bin/bash

ffmpeg_crf() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_crf [filename_with_ext] [crf]"
        echo -e "crf values range from 0 to 51. 0 is lossless, 18 is visually lossless, 23 is default, 51 is worst possible."
        return
    fi
    fullfile=$1
    crf=$2

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    ffmpeg -i ${fullfile} -crf ${crf} "${directory}/${filename}_crf${crf}.${extension}"
}

ffmpeg_speed() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_speed [filename_with_ext] [speed]X"
        return
    fi
    fullfile=$1
    speed=$2

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    ffmpeg -i ${fullfile} -filter:v setpts=PTS/${speed} "${directory}/${filename}_${speed}X.${extension}"
}

ffmpeg_cut() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_cut [filename_with_ext] [start_time (s)] [duration (s)]"
        return
    fi
    fullfile=$1
    start_time=$2
    duration=$3

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    ffmpeg -ss ${start_time} -t ${duration} -i ${fullfile} "${directory}/${filename}_cut_${duration}s.${extension}"
}

ffmpeg_gif_to_video() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo -e "Usage: ffmpeg_gif_to_video [pattern](e.g., rgb_%d.png) [start_number](OPTIONAL, 0 otherwise) [output_filename](OPTIONAL)"
        return
    fi

    pattern=$1
    start_number="${2:-0}" # Default to 0 if not provided
    default_output_filename=$(echo ${pattern} | cut -d'%' -f1)
    output_filename="${3:-$default_output_filename.mp4}"

    ffmpeg -framerate 30 -start_number ${start_number} -i ${pattern} -c:v libx264 -pix_fmt yuv420p ${output_filename}
}


ffmpeg_all() {
    # Define supported video extensions in a regex pattern
    supported_extensions="mp4|mkv|avi|mov"
    delete_original=false
    overwrite=false 

    # Check if the --delete-original flag was provided
    if [[ "$1" == "--delete-original" ]]; then
        delete_original=true
    fi

    # Loop over each file in the directory
    for file in *; do
        # Check if the file has one of the supported extensions
        if [[ -f "$file" && "$file" =~ \.($supported_extensions)$ && ! "$file" =~ compressed ]]; then
            original_size=$(du -b "$file" | cut -f1)
            original_size_hr=$(du -h "$file" | cut -f1)
            echo -e "${CYAN}Compressing file ${LTCYAN}$file ${LTCYAN}($original_size_hr )${NC}"
            
            # Define the output filename
            output="${file%.*}_compressed.mp4"
            
            # Compress the video using ffmpeg
            ffmpeg -i "$file" -vcodec libx265 -crf 18 "$output" -hide_banner -loglevel error

            # Check if the compression was successful
            if [[ $? -eq 0 ]]; then
                # Display the new file size
                new_size=$(du -b "$output" | cut -f1)
                new_size_hr=$(du -h "$output" | cut -f1)
                
                echo -e "${CYAN}New size ${LTCYAN}$output${CYAN} (${LTCYAN}$new_size_hr${CYAN} )${NC}"    
                
                # Delete the original file if the flag was set
                if $delete_original; then
                    rm "$file"
                    echo -e "${CYAN}Deleting original: $file${NC}"
                fi
            fi
        fi
    done
}