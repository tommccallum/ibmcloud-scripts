#!/bin/bash

function _ok() {
  echo -e "[$(date)] \e[1;32m$@\e[0m"
}

function _err() {
  echo -e "[$(date)] \e[1;31m$@\e[0m"
}

function _out() {
  echo "[$(date)] $@"
}

function wait_for_service_to_become_active() {
    _out Waiting on $1 to become active
    while true
    do
        SERVICE_STATE=$( ibmcloud resource service-instance $1 | awk '/State/{print $2}' )
        if [ "x$SERVICE_STATE" == "xactive" ]
        then
            break
        else
            sleep 5
        fi
    done
}

