#!/bin/bash

function _ok() {
  echo -e "[$(date)] \e[1;32m$@\e[0m"
}

function _err() {
  echo -e "[$(date)] \e[1;31m$@\e[0m"
}

function _fatal() {
  _err $@
  exit 1
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

function remove_var_from_env() {
  if [ "x${cur_dir}" == "x" ]
  then
    _fatal "cur_dir variable cannot be empty"
  fi
  sed -i "/^$1=/d" ${cur_dir}/.env
}

function set_var_in_env() {
  if [ "x${cur_dir}" == "x" ]
  then
    _fatal "cur_dir variable cannot be empty"
  fi
  echo "$1=$2" >> ${cur_dir}/.env
}

function check_tools() {
    MISSING_TOOLS=""
    git --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} git"
    curl --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} curl"
    ibmcloud --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} ibmcloud"    
    if [[ -n "$MISSING_TOOLS" ]]; then
      _err "Some tools (${MISSING_TOOLS# }) could not be found, please install them first and then run scripts/setup-app-id.sh"
      exit 1
    fi
}

function is_plugin_installed() {
  INSTALLED=$( ibmcloud plugin list | grep -i "$1" | wc -l )
  if [ $INSTALLED -gt 0 ] 
  then
    return 0
  fi
  return 1
}

function check_plugin_installed_and_install_if_not() {
  is_plugin_installed $1
  if [ $? -ne 0 ]
  then
    ibmcloud plugin install $1
  fi
}

function check_plugins_are_installed() {
  check_plugin_installed_and_install_if_not "cloud-object-storage"
  check_plugin_installed_and_install_if_not "cloud-databases"
  check_plugin_installed_and_install_if_not "cloud-functions"
}

function update_plugins() {
  REQUIRES_UPDATE=$( ibmcloud plugin list | grep -i "Update Available" | wc -l )
  if [ $REQUIRES_UPDATE -gt 0 ]
  then
    _out "Updating all plugins...please wait"
    ibmcloud plugin update --all -f
    if [ $? -ne 0 ] 
    then
      _fatal "Plugins failed to install properly, check output and try again"
    else
      _ok "Plugins were updated successfully."
    fi
  else
    _out "No plugins required updating"
  fi
}