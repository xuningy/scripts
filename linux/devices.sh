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