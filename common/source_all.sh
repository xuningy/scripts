#!/bin/bash
BASH_SCRIPTS_DIR=$HOME/scripts

source $BASH_SCRIPTS_DIR/common/settings.sh
source $BASH_SCRIPTS_DIR/common/shortcuts.sh
source $BASH_SCRIPTS_DIR/common/ffmpeg_utils.sh


source_all() {
    # Source distribution specific files
    if [ "$1" == "linux" ] || [ "$1" == "osx" ]; then
        # Loop through each .sh file in the directory and source it
        for file in "$BASH_SCRIPTS_DIR"/"$1"/*.sh; do
            if [ -f "$file" ]; then
                source "$file"
                echo -e "Sourced '$file' "
            fi
        done
    else
        echo "Usage: $0 [linux|osx](Optional)" 
        echo "Sources distribution specific bash files. In your ~/.bash_profile or ~/.bashrc, include:"
        echo "  \$HOME/scripts/source_all.sh [linux|osx]"
        exit 1
    fi

    # Loop through each .sh file in the directory and source it
    for file in "$BASH_SCRIPTS_DIR"/common/*.sh; do
        if [ -f "$file" ]; then
            source "$file"
            echo -e "Sourced '$file' "
        fi
    done
}