
open() {
    nautilus --browser $@
}

restart-nomachine() { 
    sudo /etc/NX/nxserver --status 
    sudo /etc/NX/nxserver --restart
}
