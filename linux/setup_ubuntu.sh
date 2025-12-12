#!/bin/bash

# ------------------------------------------------------------------
# Script to setup ubuntu environment from scratch
# Author: Xuning Yang xuningy@gmail.com
# Last updated: 5/11/2022
# ------------------------------------------------------------------

set -eu -o pipefail # fail on error and report it, debug all lines

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
echo -e "Colortest ${RED}RED ${GREEN} GREEN ${ORANGE} ORANGE ${BLUE} BLUE ${PURPLE} PURPLE ${CYAN} CYAN ${LTGRAY}  LTGRAY ${DKGRAY} DARKGRAY ${LTRED}LTRED ${LTGREEN} LTGREEN ${YELLOW} YELLOW ${LTBLUE} LTBLUE ${LTPURPLE} LTPURPLE${LTCYAN} LTCYAN ${WHITE} WHITE \n COLORTEST COMPLETE. CHECK COLORS ARE OK."

# some functions

# check if a debian package has already been installed
debianInstalled() {
    dpkg-query -Wf'${db:Status-abbrev}' "$1" 2>/dev/null | grep -q '^i'
}

# print that a package has been installed
alreadyInstalled() {
    echo -e "${LTCYAN}$1 ${CYAN}already installed ${NC}"
}

installing() {
    echo -e "${CYAN}sudo apt install ${LTCYAN}$1 ${NC}"
}

success() {
    echo -e "${CYAN}Installed ${LTCYAN}$1${CYAN} successfully${NC}"
}

#sudo -n true # check if in sudo, exit if not.
test $? -eq 0 || exit 1 "you should have sudo privilege to run this script"

# run sudo apt update
echo -e "${CYAN}sudo apt update ${NC}"
sudo apt update

# install packages that only require sudo apt install
echo -e "\n${CYAN}Installing packages...${NC}\n"
while read -r package ; do
    if ! debianInstalled "$package"; then
         installing "${package}"
         sudo apt install -y $package
         success "${package}"
    else
      	alreadyInstalled "$package"
    fi
done < <(cat << "EOF"
terminator
curl
wget
git
vim
htop
xclip
vlc
caffeine
python3-pip
software-properties-common
apt-transport-https
net-tools
git-lfs
ffmpeg
openssh-server
EOF
)

# install Slack (requires snap or manual repository setup)
if ! command -v slack &> /dev/null; then
    installing "slack-desktop"
    sudo snap install slack --classic
    success "slack-desktop"
else
    alreadyInstalled "slack-desktop"
fi

# install autojump
if ! debianInstalled autojump; then
    installing "autojump"
    sudo apt install autojump -y
    echo '. /usr/share/autojump/autojump.sh' >> ~/.bashrc
    success "autojump"
else
    alreadyInstalled "autojump"
fi

# install python stuff
# Note: Using --break-system-packages because Ubuntu 24.04+ blocks pip installs
# These packages won't conflict with system packages. Use conda (installed below) for future package management.
echo -e "\n${CYAN}Install python related stuff... ${NC}"
python3 -m pip install --break-system-packages colored
python3 -m pip install --break-system-packages matplotlib
python3 -m pip install --break-system-packages uv

#echo -e "${CYAN}Installing gitcheck"
python3 -m pip install --break-system-packages git+https://github.com/xuningy/gitcheck.git

# install miniforge3
INSTALL_DIR="${HOME}/conda"
if [ ! -d "$INSTALL_DIR" ]; then
    installing "miniforge3"
    wget -O Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
    bash Miniforge3.sh -b -p "${INSTALL_DIR}"
    rm Miniforge3.sh
    SHELL_CONFIG="$HOME/.bashrc"  # Adjust if using a different shell (e.g., .zshrc)
    echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\"" >> $SHELL_CONFIG
    source $SHELL_CONFIG
else
    alreadyInstalled "miniforge3 at $INSTALL_DIR"
fi

#-------------------------------------------------------------------------------
echo -e "\n${BLUE}Installing theme and fonts... ${NC}"

# gnome layout manager
if [[ "$(find . -name layoutmanager.sh)" == "" ]]; then
  echo -e "${CYAN}Install gnome layout manager ${NC}"
  wget https://raw.githubusercontent.com/bill-mavromatis/gnome-layout-manager/master/layoutmanager.sh
  chmod +x layoutmanager.sh
  ./layoutmanager.sh
else
  echo -e "${LTBLUE}gnome layout manager ${BLUE}already installed ${NC}"
fi

# flat remix theme - installed from GitHub instead of PPA (PPA doesn't support Noble/24.04)
if [ ! -d "/usr/share/themes/Flat-Remix-GTK-Blue-Dark" ]; then
    echo -e "${BLUE}Installing ${LTBLUE}flat remix gtk theme and icon pack ${NC}"
    cd /tmp
    
    # Install GTK theme
    wget -O flat-remix-gtk.tar.gz https://github.com/daniruiz/flat-remix-gtk/archive/refs/heads/master.tar.gz
    tar -xzf flat-remix-gtk.tar.gz
    sudo cp -r flat-remix-gtk-master/themes/* /usr/share/themes/
    rm -rf flat-remix-gtk-master flat-remix-gtk.tar.gz
    
    # Install icon theme
    wget -O flat-remix-icons.tar.gz https://github.com/daniruiz/flat-remix/archive/refs/heads/master.tar.gz
    tar -xzf flat-remix-icons.tar.gz
    sudo cp -r flat-remix-master/Flat-Remix* /usr/share/icons/
    rm -rf flat-remix-master flat-remix-icons.tar.gz
    
    gsettings set org.gnome.desktop.interface gtk-theme "Flat-Remix-GTK-Blue-Dark"
    gsettings set org.gnome.desktop.interface icon-theme "Flat-Remix-Blue-Dark"
    gsettings set org.gnome.desktop.interface cursor-theme 'Whiteglass'
    echo -e "${LTBLUE}flat remix ${BLUE}successfully installed ${NC}"
else
    echo -e "${LTBLUE}GNOME layout flat-remix-gtk ${BLUE}already installed ${NC}"
fi

# fonts, inconsolata and source pro
if [[ "$(fc-list | grep -i inconsolata)" == "" ]]; then
    echo -e "${BLUE}Installing ${LTBLUE}inconsolata font ${NC}"
    sudo apt-get install fonts-inconsolata -y
    gsettings set org.gnome.desktop.interface monospace-font-name 'Inconsolata Medium 11'
    sudo fc-cache -fv
    echo -e "${LTBLUE}inconsolata ${BLUE}successfully installed, monospace font set to inconsolata medium 11 ${NC}"
else
    echo -e "${LTBLUE}inconsolata font ${BLUE}already installed ${NC}"
fi

if [[ "$(fc-list | grep -i SourceSansPro)" == "" ]]; then
    echo -e "${BLUE}Installing ${LTBLUE}Source Sans/Serif/Code Pro${NC}"
    mkdir -p /tmp/adodefont
    cd /tmp/adodefont
    mkdir -p ~/.fonts

    wget https://github.com/adobe-fonts/source-code-pro/archive/2.030R-ro/1.050R-it.zip
    unzip 1.050R-it.zip
    cp source-code-pro-2.030R-ro-1.050R-it/OTF/*.otf ~/.fonts/

    wget https://github.com/adobe-fonts/source-serif-pro/archive/2.000R.zip
    unzip 2.000R.zip
    cp source-serif-2.000R/OTF/*.otf ~/.fonts/

    wget https://github.com/adobe-fonts/source-sans-pro/archive/2.020R-ro/1.075R-it.zip
    unzip 1.075R-it.zip
    cp source-sans-2.020R-ro-1.075R-it/OTF/*.otf ~/.fonts/

    sudo fc-cache -fv

    gsettings set org.gnome.desktop.interface document-font-name 'Source Sans Pro Regular 11'
    gsettings set org.gnome.desktop.interface font-name 'Source Sans Pro Regular 10'
    # Note: org.gnome.nautilus.desktop schema removed in Ubuntu 24.04/GNOME 46+
    gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Source Sans Pro Regular 11'

    echo -e "${LTBLUE}Source Serif/Code/Sans Pro ${BLUE}successfully installed, gnome interface set to Source Sans Pro ${NC}"
else
    echo -e "${LTBLUE}Source Serif/Code/Sans Pro ${BLUE}already installed ${NC}"
fi

# Set dock style and size
echo -e "${BLUE}Set dock to be permanently fixed on the bottom, icon size 40 ${NC}"
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 40
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'


# set keyboard delay and repeat rate on terminal startup.
if grep -q "xset r rate" ~/.bash_aliases 2>/dev/null | grep -q '^i'; then
  echo -e "${BLUE}Set keyboard delay and repeat rates in bash_aliases${NC}"
  echo '# set keyboard delay and repeat rate to 200 and 60' >> ~/.bash_aliases
  echo 'xset r rate 200 60' >> ~/.bash_aliases
fi

echo -e "${BLUE}Note: Any additional style elements can be set using dconf-editor or programmatically using gsettings.${NC}"

# ------------------------------------------------------------------------------
# generate git key etc
echo -e "${CYAN}Setting up git global user email and name (gmail) ${NC}"
ssh-keygen -t ed25519 -C "xuningy@gmail.com" -N '' -f ~/.ssh/id_github <<<y >/dev/null 2>&1
xclip -sel clip < ~/.ssh/id_github.pub

git config --global user.email "xuningy@gmail.com"
git config --global user.name "Xuning Yang"

echo -e "${CYAN}Git setup complete ${NC}"

# ------------------------------------------------------------------------------
# Add source_all_linux.sh to bashrc if not already present
if ! grep -q "source_all_linux.sh" ~/.bashrc; then
    echo -e "${CYAN}Adding source_all_linux.sh to ~/.bashrc ${NC}"
    echo "" >> ~/.bashrc
    echo "# Source linux scripts and shortcuts" >> ~/.bashrc
    echo "source $HOME/scripts/linux/source_all_linux.sh" >> ~/.bashrc
    echo -e "${CYAN}source_all_linux.sh ${GREEN}added to bashrc ${NC}"
else
    echo -e "${LTCYAN}source_all_linux.sh ${CYAN}already in bashrc ${NC}"
fi

