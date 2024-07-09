# ROS2 related shortcuts

source-ros2() {
    echo -e "${CYAN}source /opt/ros/humble/setup.bash${NC}"
    source /opt/ros/humble/setup.bash

    if [ $# -eq 1 ]; then
        ros2-domain $1
    fi
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

ros2-new-package() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}ros2-new-package package_name node_name ${NC}"
        return
    fi

    if [ $# -eq 2 ]; then
        echo -e "${CYAN}Creating package: ros2 pkg create --build-type ament_python --node-name ${LTCYAN}$2 $1${NC}"
        ros2 pkg create --build-type ament_python --node-name $2 $1
    elif [ $# -eq 1 ]; then
        echo -e "${CYAN}Creating package: ros2 pkg create --build-type ament_python ${LTCYAN}$1${NC}"
        ros2 pkg create --build-type ament_python $1
    else
        echo -e "${CYAN} Usage: ${LTCYAN}ros2-new-package package_name node_name ${NC}"
    fi

    cd $1
    mkdir config
    mkdir launch
    mkdir scripts

    #Modify setup.py
    text_to_append="import os\nfrom glob import glob"
    sed -i "/from setuptools import find_packages, setup/a $text_to_append" setup.py
    TAB=$'\t'
    text_to_append="\\\t\t(os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),\n${TAB}${TAB}(os.path.join('share', package_name, 'config'), glob('config/*')),\n${TAB}${TAB}(os.path.join('share', package_name, 'scripts'), glob('scripts/*.py')),"
    sed -i "/('share\/' + package_name, \['package.xml'\]),/ a $text_to_append" setup.py
    echo -e "${CYAN}Adding config, launch, scripts folders to be discoverable in /share/. ${NC}"

    cd $1
    if [ ! -s "__init__.py" ]; then
        echo "import os" >> "__init__.py"
        echo "from ament_index_python.packages import get_package_share_directory" >> "__init__.py"

        echo "PACKAGE_DIR = get_package_share_directory('se2_controller')" >> "__init__.py"
        echo "CONFIG_DIR = os.path.join(PACKAGE_DIR, 'config')" >> "__init__.py"
        echo "SCRIPTS_DIR = os.path.join(PACKAGE_DIR, 'scripts')" >> "__init__.py"
        echo "LAUNCH_DIR = os.path.join(PACKAGE_DIR, 'launch')" >> "__init__.py"
        echo -e "${CYAN}Updated package global directory paths to __init__.py. ${NC}"
    else
        echo -e "${CYAN}__init__.py is not empty, doing nothing. ${NC}"
    fi


    # Initialize repo as git
    cd ..
    git-init

    # Update readme
    if [ -s "README.md" ]; then
        echo >> README.md
        cat $BASH_SCRIPTS_DIR/linux/ros2_generic_readme.md >> README.md
        echo -e "${CYAN}Added generic readme text to README.md. ${NC}"
    fi
    echo -e "${LTCYAN}Created new package '$1' with node '$2'.${NC}"

}