#!/bin/bash

ffmpeg_crf() {
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then 
        echo -e "Usage: $0 [filename_with_ext] [crf]"
        echo -e "crf values range from 0 to 51. 0 is lossless, 18 is visually lossless, 23 is default, 51 is worst possible."
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
        echo -e "Usage: $0 [filename_with_ext] [speed]X"
    fi 
    fullfile=$1
    speed=$2

    filename=$(basename -- "$fullfile")
    directory=$(dirname -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    ffmpeg -i ${fullfile} -filter:v setpts=PTS/${speed} "${directory}/${filename}_${speed}X.${extension}"
}

ffmpeg_gif_to_video() {

    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then 
        echo -e "Usage: $0 [pattern] [start_number](OPTIONAL, 0) [output_filename](OPTIONAL)"
    fi 

    pattern=$1 
    start_number="${2:-0}" # Default to 0 if not provided
    default_output_filename=$(echo ${pattern} | cut -d'%' -f1)
    output_filename="${3:-$default_output_filename.mp4}"

    ffmpeg -framerate 30 -start_number ${start_number} -i ${pattern} -c:v libx264 -pix_fmt yuv420p ${output_filename}
}