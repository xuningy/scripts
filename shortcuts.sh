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
}

# ROS2 related shortcuts
ros_version() {
    echo -e "${LTCYAN} ROS-related env paths:${NC}"
    printenv | grep -i ROS
    echo -e "${LTCYAN} rosversion -d ${NC}"
    rosversion -d
}

ros2_local() {
    source /opt/ros/foxy/setup.bash
    ros2_domain $1
    export ROS_LOCALHOST_ONLY=1
    echo "ROS2 set to localhost only."
}

ros2_domain() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ros2_domain N\n where N is a number between 0 to 101. This sets the ROS_DOMAIN_ID to N. For more info, see: https://docs.ros.org/en/foxy/Concepts/About-Domain-ID.html"
        return 
    fi 

    if [[ -z "$1" ]]; then
        export ROS_DOMAIN_ID=0
    else
        export ROS_DOMAIN_ID=$1
    fi

    echo -e "${LTCYAN}Set ROS_DOMAIN_ID to: ${CYAN}"$ROS_DOMAIN_ID"${NC}"
}

ros2_check_deps() {
    # Inside the ROS2 workspace folder
    rosdep install -i --from-path src --rosdistro foxy -y
    # should return All required rosdps installed successfully
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
        ros2_check_deps 
        source install/setup.bash 
    fi

}

wifi_connect() {
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