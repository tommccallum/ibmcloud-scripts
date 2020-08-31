#!/bin/bash

# Installs any terminal requirements
# expect-devel has the unbuffer script which is useful for keeping the IBM Cloud terminal colours
UBUNTU=( "python3 expect-dev" )
FEDORA=( "python3 expect-devel" )

DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
PACMAN=""

IS_FEDORA=$( grep -i "fedora" <<< ${DISTRO})
IS_UBUNTU=$( grep -i "ubuntu" <<< ${DISTRO})
if [ "x${IS_FEDORA}" == "x" -a "x${IS_UBUNTU}" == "x" ]
then
    echo "Linux distro is not supported.  Try manual installation or add a check."
    exit 1
fi

[[ $(which dnf 2>/dev/null) ]] && PACMAN="dnf" 
[[ $(which apt-get 2>/dev/null) ]] && PACMAN="apt-get"

if [ "x$PACMAN" == "x" ]
then
    echo "Failed to find 'dnf' or 'apt-get'. Do a manual install."
    exit 1
fi

if [[ ${IS_UBUNTU} ]]; then
    echo "Installing Ubuntu dependencies"
    sudo apt-get -y update
    sudo $PACMAN -y install ${UBUNTU[*]}
    if [ $? -ne 0 ]; then
        echo "Failed to install all Ubuntu dependencies"
        exit 1
    fi
fi
if [[ ${IS_FEDORA} ]]; then
    echo "Installing Fedora dependencies"
    sudo $PACMAN -y install ${FEDORA[*]}
    if [ $? -ne 0 ]; then
        echo "Failed to install all Fedora dependencies"
        exit 1
    fi
fi
