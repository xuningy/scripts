#!/bin/bash

# A set of scripts for projects that I work on. run the following line to access these functions
# echo "source ~/scripts/shortcuts.sh" >> ~/.bashrc

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LTGRAY='\033[0;37m'
DKGRAY='\033[1;30m'
LTRED='\033[1;31m'
LTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LTBLUE='\033[1;34m'
LTPURPLE='\033[1;35m'
LTCYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# End the current working session
bye() {

    # Close any conda windows
    if ! [[ -z "${CONDA_DEFAULT_ENV}" ]] ; then
        conda deactivate
    fi

    # Go to home
    cd
}

open() {
    nautilus --browser $@
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

install-pytorch-116() {
    # Super simple script for installing pytorch in a given conda env for cuda 11.6. first run `versions` to get the cuda version.
    pip install torch==1.13.1+cu116 torchvision==0.14.1+cu116 torchaudio==0.13.1 --extra-index-url https://download.pytorch.org/whl/cu116
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

pytorch-versions() {
    python3 ~/scripts/collect_env.py
}

versions() {
    cuda-versions
    glibc-version

    printf "========================================================\n"
    echo -e "${LTCYAN}Python Version (python3 version):${NC}"
    python3 --version
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

# ROS2 related shortcuts

source-ros2() {
    echo -e "${CYAN}source /opt/ros/humble/setup.bash${NC}"
    source /opt/ros/humble/setup.bash
}

source-ros() {
    echo -e "${CYAN}source /opt/ros/noetic/setup.bash${NC}"
    source /opt/ros/noetic/setup.bash
}


ros-version() {
    echo -e "${LTCYAN} ROS-related env paths:${NC}"
    printenv | grep -i ROS
    echo -e "${LTCYAN} rosversion -d ${NC}"
    rosversion -d
}

ros2-local() {
    source /opt/ros/humble/setup.bash
    ros2-domain $1
    export ROS_LOCALHOST_ONLY=1
    echo "ROS2 set to localhost only."
}

ros2-domain() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ros2_domain N\n where N is a number between 0 to 101. This sets the ROS_DOMAIN_ID to N. For more info, see: https://docs.ros.org/en/humble/Concepts/About-Domain-ID.html"
        return
    fi

    if [[ -z "$1" ]]; then
        export ROS_DOMAIN_ID=0
    else
        export ROS_DOMAIN_ID=$1
    fi

    echo -e "${LTCYAN}Set ROS_DOMAIN_ID to: ${CYAN}"$ROS_DOMAIN_ID"${NC}"
}

ros2-check-deps() {
    # Inside the ROS2 workspace folder
    rosdep install -i --from-path src --rosdistro humble -y
    # should return All required rosdps installed successfully
}

ros2-view-frames() {
    # Generates a TF Tree in frames.pdf and displays it after its been constructed
    source-ros2
    ros2 run tf2_tools view_frames.py && evince frames.pdf
}

ros-view-frames() {
    source-ros
    rosrun tf2_tools view_frames.py && evince frames.pdf
}

cb() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}cb <PACKAGES>[OPTIONAL] ... ${NC}\n   Runs colcon build --symlink-install (saves from rebuilding every time a python script is tweaked) --packages-select <PACKAGES> which only builds the package(s) you specified."
        echo -e " ${LTCYAN}cb <PACKAGES>[OPTIONAL] ... --packages-skip <PACKAGES_TO_SKIP>[OPTIONAL] ... ${NC}\n   Runs colcon build on specified packages and skips the specified packages. If no package is provided, then it builds everything except the skip packages."
        return
    fi

    if [[ $1 = "--packages-skip" ]]; then
        echo -e "${LTCYAN}Building all packages except ${@:2}: ${CYAN}colcon build --symlink-install $@${NC}"
        colcon build --symlink-install "$@"
    elif [ -n "$1" ]; then
        echo -e "${LTCYAN}Building select packages $@: ${CYAN}colcon build --symlink-install --packages-select $@${NC}"
        colcon build --symlink-install --packages-select "$@"
    else
        echo -e "${LTCYAN}Building all packages in workspace: ${CYAN}colcon build --symlink-install ${NC}"
        colcon build --symlink-install
    fi
}

workon() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}workon <WORKSPACE_NAME> ${NC}"
        return
    fi

    if [[ -z "$1" ]]; then
        echo -e "${LTRED}No workspace name provided. Use: ${RED}workon <WORKSPACE_NAME> ${NC}"
    else
        echo -e "${LTCYAN}Setting up workspace: ${CYAN}$1${NC}"
        cd $HOME/$1  # replace this with cd <workspace folder>
        echo -e "${LTCYAN}Checking dependencies are built... ${NC}"
        ros2-check-deps
        source install/setup.bash
    fi

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

spacemouse-status() {
    echo -e "Please make sure your spacemouse is plugged into system. Checking..."
    echo -e "If using wireless spacemouse, check 256f:c652 exists.\nlsusb:\n"
    lsusb


    # Check that udev rules are set up correctly
    if test -f "/etc/udev/rules.d/99-spacemouse.rules" ; then
        echo -e "\nFile /etc/udev/rules.d/99-spacemouse.rules found:\n"
        cat "/etc/udev/rules.d/99-spacemouse.rules"
        echo -e "\nPlease check that the above looks correct."
    else
        echo -e "\n[ERROR] You have not set up the appropriate spacemouse rule! Please add the following line:\n\t"
        echo "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"256f\", ATTRS{idProduct}==\"c652\", MODE=\"0666\", SYMLINK+=\"spacemouse\""
        echo -e "to:       /etc/udev/rules.d/99-spacemouse.rules"
    fi
}

git-init() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}git-init${NC}"
        return
    fi

    if [ -d ".git" ]; then
        echo -e "${CYAN}Git already initialized! Exiting.${NC}"
        return
    fi

    PACKAGE_NAME=$(basename "$PWD")
    echo -e "${CYAN}Initializing git for ${LTCYAN}$PACKAGE_NAME${NC}"

    # git init
    git init

    # Check if a .gitignore already exist. If not, create a .gitignore file.
    if [ ! -f ".gitignore" ]; then
        cp ${HOME}/scripts/gitignore_template.txt .gitignore

        echo -e "${CYAN}Added .gitignore${NC}"
    fi

    # Create a readme if the file doesn't already exist. If not, create a README.md file.
    if ! find . -iname "readme.md" -type f -print -quit | grep -q .; then

        echo "# $PACKAGE_NAME"  > README.md
        echo "Author: Xuning Yang" >> README.md

        echo -e "${CYAN}Added README.md${NC}"
    fi

    # Set config for the package
    git config user.email "xuningy@gmail.com"
    git config user.name "Xuning Yang"
    echo -e "${CYAN}Set user.name user.email to ${LTCYAN}Xuning Yang xuningy@gmail.com${NC}"

    git config -l

    return
}

build-sphinx() {
    sphinx-build -b html docs public
}

code-grep() {
    grep -r --exclude-dir={public,docs,build,__pycache__,} "$1" .
}
