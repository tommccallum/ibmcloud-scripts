#!/bin/bash

cur_dir=$( cd $(dirname $0) && pwd )

source ${cur_dir}/ibm_std_functions.sh
standard_start

_out Starting login process
if [ -e "${cur_dir}/ibm_api_key.txt" -a "x${IBMCLOUD_API_KEY}" == "x" ]
then
  _out "Logging in using api key file"
  ibmcloud login --apikey @${cur_dir}/ibm_api_key.txt -r eu-gb
else  
  if [ "x${IBMCLOUD_API_KEY}" == "x" ]; then
    _out "Logging in expecting user intervention"
    ibmcloud login -r eu-gb
  else
    _out "Logging in using IBMCLOUD_API_KEY"
    ibmcloud login -r eu-gb -apikey "${IBMCLOUD_API_KEY}"
  fi
fi
if [ $? -ne 0 ]
then
  _err "Failed to login to IBM Cloud"
  exit 1
else
  _ok "Login was successful"
fi

_out "Setting target to cloud foundry"
ibmcloud target --cf
if [ $? -ne 0 ]
then
  _err "Failed to set target as Cloud Foundry"
  exit 1
fi

_out "Retrieving resource group"
RESOURCE_GROUP=$(ibmcloud resource groups | grep -i " active " | head -n 1 | awk '{print $1}')
if [ "x${RESOURCE_GROUP}" == "x" ]; then
  # try again
  _out "Resource group was empty, attempt 2..."
  sleep 5
  RESOURCE_GROUP=$(ibmcloud resource groups | grep -i " active " | head -n 1 | awk '{print $1}')
  if [ "x${RESOURCE_GROUP}" == "x" ]; then
    _fatal "Failed to find resource group, try again as this can "
  fi
fi
_out "Setting resource group to ${RESOURCE_GROUP}"
ibmcloud target -g "$RESOURCE_GROUP"
if [ $? -ne 0 ]
then
  _err "Failed to set resource group"
  ibmcloud resource groups
  exit 1
fi

_out Checking you are using the latest CLI
ibmcloud update
_out Checking you have the minimum set of plugins installed
check_plugins_are_installed
_out Ensure the plugins are the latest
update_plugins

_out "Your current settings are:"
show ibmcloud config --list 
show ibmcloud target
