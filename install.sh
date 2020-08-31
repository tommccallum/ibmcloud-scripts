#!/bin/bash

# Installs any terminal requirements
# expect-devel has the unbuffer script which is useful for keeping the IBM Cloud terminal colours
UBUNTU=( "expect-dev" )
FEDORA=( "expect-devel" )

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
[[ $(which apt 2>/dev/null) ]] && PACMAN="apt"

if [ "x$PACMAN" == "x" ]
then
    echo "Failed to find 'dnf' or 'apt'. Do a manual install."
    exit 1
fi

[[ ${IS_UBUNTU} ]] && sudo $PACMAN -y install ${UBUNTU[*]}
[[ ${IS_FEDORA} ]] && sudo $PACMAN -y install ${FEDORA[*]}