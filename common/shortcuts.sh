#!/bin/bash

# A set of scripts for projects that I work on. run the following line to access these functions
# echo "source ~/scripts/shortcuts.sh" >> ~/.bashrc


# End the current working session
bye() {

    # Close any conda windows
    if ! [[ -z "${CONDA_DEFAULT_ENV}" ]] ; then
        conda deactivate
    fi

    # Go to home
    cd
}


# generate ssh-key
generate-ssh() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "${CYAN} Generate new ssh key.\nUsage:\n\t generate-ssh${NC}"
        return
    fi
    echo -e "${CYAN}Setting up git ssh key ${NC}"
    ssh-keygen -t rsa -C "xuningy@gmail.com" -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
    xclip -sel clip < ~/.ssh/id_rsa.pub
    echo -e "${CYAN}New ssh key generated for ${LTCYAN}xuningy@gmail.com${CYAN} at ${LTCYAN}id_rsa.pub${CYAN}: ${NC}"
    cat ~/.ssh/id_rsa.pub
    echo -e "${CYAN} Key has been copied to clipboard. ${NC}"

    git config --global user.email "xuningy@gmail.com"
    git config --global user.name "Xuning Yang"
}

cuda-versions() {
    printf "==============================================================================\n"
    echo -e "${LTCYAN}CUDA Toolkit Version (nvcc --version) [Needs to be lower than Driver version]${NC}"
    nvcc --version
    echo " "

    printf "==============================================================================\n"
    echo -e "${LTCYAN}Cuda GPU Driver Version (nvidia-smi):${NC}"
    nvidia-smi
    echo " "
}

glibc-version() {
    printf "==============================================================================\n"
    echo -e "${LTCYAN}GLIBC Version (ldd --version):${NC}"
    ldd --version | head -n1
    echo " "
}

python-versions() {
    echo -e "${CYAN}which python${NC}"
    which python3
    which python
    echo -e "${CYAN}python3 --version${NC}"
    python3 --version
    echo -e "${CYAN}sys.path${NC}"
    python3 -c "import sys; print('\n'.join(sys.path))"
}

numpy-versions() {
    echo -e "${CYAN}numpy.__version__${NC}"
    python3 -c "import numpy; print(numpy.__version__)"
    echo -e "${CYAN}numpy.__file__${NC}"
    python3 -c "import numpy; print(numpy.__file__)"
}

pytorch-versions() {
    python3 $BASH_SCRIPTS_DIR/common/collect_env.py
}

kernel-versions() {
    printf "========================================================\n"
    echo -e "${LTCYAN}Kernel version:${NC}"
    uname -r

    echo -e "${LTCYAN}List of all kernels:${NC}"
    dpkg --list | grep linux-image
}

gcc-versions() {
    printf "========================================================\n"
    echo -e "${LTCYAN}GCC version:${NC}"
    gcc --version
    ls -al /usr/bin/gcc

    echo -e "\n${LTCYAN}G++ version:${NC}"
    g++ --version
    ls -al /usr/bin/g++

    echo -e "\n${LTCYAN}cc version:${NC}"
    cc --version
    ls -al /usr/bin/cc

}
versions() {
    kernel-versions
    cuda-versions
    gcc-versions
    glibc-version

    printf "========================================================\n"
    echo -e "${LTCYAN}Python Version (python3 version):${NC}"
    python-versions
    numpy-versions
    echo " "

    printf "========================================================\n"
    echo -e "${LTCYAN}Git Version (git --version):${NC}"
    git --version
    echo " "

    printf "========================================================\n"
    echo -e "${LTCYAN}Running PyTorch's collect_env.py:${NC}"
    pytorch-versions
    echo " "
}


wifi-connect() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}wifi_connect <WIFI_SSID>  ${NC}"
        return
    fi

    echo -e "${CYAN}Attempting to connect to wifi network ${LTCYAN}$1${NC}"

    # Connect to wifi networks until they come online
    while true; do
        if nmcli dev wifi connect $1 | grep -q "successfully"; then
            echo -e "${CYAN}Connected to ${LTCYAN}$1${CYAN} successfully${NC}"
            break
        fi
        sleep 2
    done
}


build-sphinx() {
    sphinx-build -b html docs public
}

grep-code-only() {
    grep -r --exclude-dir={public,docs,build,__pycache__,output,*.egg-info,log,.git} "$1" .
}

flatten_folders() {
    if [ -z "$1" ]; then
        echo "Usage: flatten_folders <target_directory>"
        return 1
    fi

    target_dir="$1"

    if [ ! -d "$target_dir" ]; then
        echo "Error: '$target_dir' is not a valid directory."
        return 1
    fi

    echo "Flattening contents of '$target_dir'..."

    find "$target_dir" -mindepth 2 -type f | while IFS= read -r file; do
        base_name=$(basename "$file")
        dest_path="$target_dir/$base_name"

        # If the file already exists, add a counter
        if [ -e "$dest_path" ]; then
            ext="${base_name##*.}"
            name="${base_name%.*}"

            # Handle filenames with no extension
            if [ "$name" = "$base_name" ]; then
                ext=""
            else
                ext=".$ext"
            fi

            counter=1
            while [ -e "$target_dir/${name}_$counter$ext" ]; do
                ((counter++))
            done

            dest_path="$target_dir/${name}_$counter$ext"
        fi

        echo "Moving: '$file' -> '$dest_path'"
        mv "$file" "$dest_path"
    done

    echo "Removing empty directories..."
    find "$target_dir" -mindepth 1 -type d -empty -delete

    echo "Flattening complete."
}
