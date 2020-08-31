#!/bin/bash

#
#  RETVAL should be used if returning a value and we expect more than just that value to be piped to STDOUT
#  If expecting to be used as VAR=$(my_function) then do not call _fatal as this will not exit
#  instead you will need to call _err and return 1.  The calling code then must check for this by
#  using exit_on_error.
#
#

function exit_on_error() {
    exit_code=$1
    if [ $exit_code -ne 0 ]; then
        exit $exit_code
    fi
}

# Get the location the current script is running from
function get_root_folder() {
  local root_folder=$(
    cd $(dirname $0)
    pwd
  )
  echo "${root_folder}"
}

function abbreviate_file_path() {
  local file_path="$1"
  local root=$(get_absolute_path "$(get_root_folder)/../../")
  local short=$(shorten_file_path.py "${file_path}" "${root}")
  echo "${short}"
}

function get_absolute_path() {
  local file_path="$1"
  echo "$(readlink -f ${file_path})"
}

function find_environment() {
  local user_specified_env_file="$2"
  local exp_env_file="${user_specified_env_file}"
  if [ "x${exp_env_file}" == "x" ]; then
    exp_env_file="local.env"
  fi
  local root_folder="$(get_root_folder)"
  local env_file=""
  [[ "x$env_file" == "x" && -e "${root_folder}/${exp_env_file}" ]] && env_file="${root_folder}/${exp_env_file}"
  [[ "x$env_file" == "x" && -e "${root_folder}/../${exp_env_file}" ]] && env_file="${root_folder}/../${exp_env_file}"
  [[ "x$env_file" == "x" && -e "${root_folder}/../../${exp_env_file}" ]] && env_file="${root_folder}/../../${exp_env_file}"
  [[ "x$env_file" == "x" && -e "${root_folder}/../../../${exp_env_file}" ]] && env_file="${root_folder}/../../../${exp_env_file}"
  [[ "x$env_file" == "x" && -e "~/${exp_env_file}" ]] && env_file="~/${exp_env_file}"
  if [ "x${env_file}" != "x" ]; then
    env_file=$(get_absolute_path ${env_file})
    echo "${env_file}"
  else
    _fatal "Could not find ${exp_env_file}."
  fi
}

function load_project_functions() {
  local project_functions_file="$1"
  local root_folder="$(get_root_folder)"
  [[ "x${project_functions_file}" == "x" ]] && project_functions_file="project-functions.sh"
  if [[ -e "${root_folder}/${project_functions_file}" ]]; then
    source "${root_folder}/${project_functions_file}"
    return 0
  fi
  return 1
}

# Sets out stdout and stderr to also pipe to a log file.
# Sets file descriptor 3 to also pipe to stdout
# Sets file descriptior 4 to also pipe to stderr
function setup_logging() {
  local log_file=$1
  local redirect_output=$2
  if [ "x$redirect_output" == "x" ]; then
    exec 3>&1 # Set 3 to be a copy of stdin
    exec 4>&2 # Set 4 to be a copy of stderr
    exec 1>$log_file 2>&1
    LOG_FILE="$log_file"
    _out "Logging to $(abbreviate_file_path ${LOG_FILE})"
  else
    IBM_STD_FUNCTIONS_REDIRECT_OUTPUT="FALSE"
    unset LOG_FILE
  fi
}

function _ok() {
  if [ "x${IBM_STD_FUNCTIONS_REDIRECT_OUTPUT}" == "x" ]; then
    echo -e "[$(date)] \e[1;32m$@\e[0m" >&3
    echo -e "[$(date)] $@" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  else
    echo -e "[$(date)] \e[1;32m$@\e[0m"
  fi
}

function _err() {
  if [ "x${IBM_STD_FUNCTIONS_REDIRECT_OUTPUT}" == "x" ]; then
    echo -e "[$(date)] \e[1;31m$@\e[0m" >&4
    echo -e "[$(date)] $@" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  else
    echo -e "[$(date)] \e[1;32m$@\e[0m"
  fi
}

function _fatal() {
  _err $@
  exit 1
}

function _out() {
  if [ "x${IBM_STD_FUNCTIONS_REDIRECT_OUTPUT}" == "x" ]; then
    echo "[$(date)] $@" >&3
    echo "[$(date)] $@" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  else
    echo -e "[$(date)] \e[1;32m$@\e[0m"
  fi
}

function show() {
  echo "[$(date)] $*"
  if [ "x${IBM_STD_FUNCTIONS_REDIRECT_OUTPUT}" == "x" ]; then
    unbuffer $* | tee /dev/tty | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  else
    $*
  fi
}

function get_standard_log_name() {
  local name=$1
  local result=$(sed "s/setup[_\-]//" <<<"${name}" | sed "s/\.sh//")
  echo "deploy-${result}.log"
}

function standard_start() {
  local redirect_output=$1
  local log_filename=$(get_standard_log_name $(basename $0))
  local root_folder=$(get_root_folder)
  LOG_FILE="${root_folder}/${log_filename}"
  setup_logging ${LOG_FILE} ${redirect_output}
}

function standard_project_script_start() {
  local log_filename=$(get_standard_log_name $(basename $0))
  local root_folder=$(get_root_folder)
  LOG_FILE="${root_folder}/${log_filename}"
  setup_logging ${LOG_FILE}
  ENV_FILE=$(find_environment)
  _out "Loading variables from $(abbreviate_file_path ${ENV_FILE})"
  source ${ENV_FILE}
  load_project_functions
}

function wait_for_service_to_become_active() {
  _out Waiting on $1 to become active
  while true; do
    SERVICE_STATE=$(ibmcloud resource service-instance $1)
    if [ $? -ne 0 ]
    then
      _fatal "Service '$1' failed to be created, check logs and ensure you do not have an existing service."
    fi
    SERVICE_STATE=$(ibmcloud resource service-instance $1 | awk '/State/{print $2}')
    if [ "x$SERVICE_STATE" == "xactive" ]; then
      break
    else
      # TODO check log for errors
      sleep 5
    fi
  done
}

function remove_var_from_env() {
  if [ "x${cur_dir}" == "x" ]; then
    _fatal "cur_dir variable cannot be empty"
  fi
  sed -i "/^$1=/d" ${cur_dir}/.env
}

function set_var_in_env() {
  local key="$1"
  local val="$2"
  if [ "x$key" == "x" ]; then
    _fatal "Key is missing"
  fi
  if [ "x$ENV_FILE" == "x" ]; then
    _fatal "No environment file set"
  fi
  if [ "x$val" == "x" ]; then
    ## remove value from file
    sed -i "/^$key=/d" ${ENV_FILE}
    local exists=$(grep "^$key=" ${ENV_FILE})
    if [ "x$exists" == "x" ]; then
      _ok "$key removed from $(abbreviate_file_path ${ENV_FILE})"
      return 0
    else
      _fatal "Failed to remove '$key' from $(abbreviate_file_path ${ENV_FILE})"
    fi
  fi
  local exists=$(grep "^$key=" ${ENV_FILE})
  if [ "x$exists" == "x" ]; then
    printf "\n$key=\"$val\"" >> ${ENV_FILE}
  else  
    sed -i "s#^$key=.*#$key=\"$val\"#" ${ENV_FILE}
  fi
  local exists=$(grep "^$key=\"$val\"" ${ENV_FILE})
  if [ "x$exists" != "x" ]; then
    _ok "$key was added to $(abbreviate_file_path ${ENV_FILE})"
  else
    _fatal "Failed to add '$key' to $(abbreviate_file_path ${ENV_FILE})"
  fi
}

function check_tools() {
  MISSING_TOOLS=""
  git --version &>/dev/null || MISSING_TOOLS="${MISSING_TOOLS} git"
  curl --version &>/dev/null || MISSING_TOOLS="${MISSING_TOOLS} curl"
  ibmcloud --version &>/dev/null || MISSING_TOOLS="${MISSING_TOOLS} ibmcloud"
  if [[ -n "$MISSING_TOOLS" ]]; then
    _err "Some tools (${MISSING_TOOLS# }) could not be found, please install them first and then run scripts/setup-app-id.sh"
    exit 1
  fi
}

function is_plugin_installed() {
  INSTALLED=$(ibmcloud plugin list | grep -i "$1" | wc -l)
  if [ $INSTALLED -gt 0 ]; then
    return 0
  fi
  return 1
}

function check_plugin_installed_and_install_if_not() {
  is_plugin_installed $1
  if [ $? -ne 0 ]; then
    ibmcloud plugin install $1
  fi
}

function check_plugins_are_installed() {
  check_plugin_installed_and_install_if_not "cloud-object-storage"
  check_plugin_installed_and_install_if_not "cloud-databases"
  check_plugin_installed_and_install_if_not "cloud-functions"
}

function update_plugins() {
  REQUIRES_UPDATE=$(ibmcloud plugin list | grep -i "Update Available" | wc -l)
  if [ $REQUIRES_UPDATE -gt 0 ]; then
    _out "Updating all plugins...please wait"
    ibmcloud plugin update --all -f
    if [ $? -ne 0 ]; then
      _fatal "Plugins failed to install properly, check output and try again"
    else
      _ok "Plugins were updated successfully."
    fi
  else
    _out "No plugins required updating"
  fi
}

function launch_browser_if_available() {
  URL=$1

  PREFERRED_APP_LAUNCHER=$(which xdg-open)
  if [ "x${PREFERRED_APP_LAUNCHER}" != "x" ]; then
    [[ -x ${PREFERRED_APP_LAUNCHER} ]] && exec "${PREFERRED_APP_LAUNCHER}" "$URL"
  else
    _err "Could not find xdg-open to launch preferred browser."
  fi
}

function requires() {
  valid=0
  for v in "$@"; do
    value=${!v}
    if [ "x$value" == "x" ]; then
      valid=1
    fi
  done
  return $valid
}

function requires_or_fatal() {
  valid=0
  for v in "$@"; do
    value=${!v}
    if [ "x$value" == "x" ]; then
      _err "Missing required variable '${v}'"
      valid=1
    fi
  done
  if [ $valid -ne 0 ]; then
    _fatal "Required variables are missing, please check and try again."
  fi
  return $valid
}

function get_current_org() {
  local ibmcloud_org=$(ibmcloud target | awk '/Org/{print $2}')
  echo "${ibmcloud_org}"
}

function get_current_space() {
  local ibmcloud_space=$(ibmcloud target | awk '/Space/{print $2}')
  echo "${ibmcloud_space}"
}

function search_for_region() {
  _out "Searching for region value"
  if [ "x$BLUEMIX_REGION" == "x" ]; then
    BLUEMIX_REGION=$(ibmcloud target | awk '/Region/ { print $2 }')
    if [ "x$BLUEMIX_REGION" == "x" ]; then
      _out "Logging in to IBM Cloud as user"
      ibm_login.sh
      BLUEMIX_REGION=$(ibmcloud target | awk '/Region/ { print $2 }')
      if [ "x$BLUEMIX_REGION" == "x" ]; then
        _err "search_for_region: Could not find if the region is set."
        ibmcloud target
        _fatal
      fi
    fi
  fi
}

function search_for_ibmcloud_org_and_space() {
  _out "Searching for IBM Cloud Org and Space values"
  if [ "x${IBMCLOUD_ORG}" == "x" -o "x${IBMCLOUD_SPACE}" == "x" ]; then
    IBMCLOUD_ORG="$(get_current_org)"
    IBMCLOUD_SPACE="$(get_current_org)"
    if [ "x${IBMCLOUD_ORG}" == "x" -o "x${IBMCLOUD_SPACE}" == "x" ]; then
      ibm_login.sh
    fi
    IBMCLOUD_ORG=$(get_current_org)
    IBMCLOUD_SPACE=$(get_current_space)
    if [ "x${IBMCLOUD_ORG}" == "x" ]; then
      _err "search_for_ibmcloud_org_and_space: Could not find IBM Cloud org in 'ibmcloud target'."
      ibmcloud target
      _fatal
    fi
    if [ "x${IBMCLOUD_SPACE}" == "x" ]; then
      _err "search_for_ibmcloud_org_and_space: Could not find IBM Cloud space in 'ibmcloud target'."
      ibmcloud target
      _fatal
    fi
  fi
}

function ibmcloud_project_login() {
  local project_name="$1"
  if [ "x${project_name}" == "x" ]; then
    _fatal "ibmcloud_project_login: No project name given."
  fi
  local api_key=$(get_project_api_key ${project_name} || echo )
  if [ "x$api_key" == "x" ]; then
    return 1
  fi

  search_for_region
  search_for_ibmcloud_org_and_space
  IBMCLOUD_ORG=$(get_current_org)
  IBMCLOUD_SPACE=$(get_current_space)

  # Skip version check updates
  ibmcloud config --check-version=false
  local IBMCLOUD_API_ENDPOINT=$(ibmcloud api | awk '/API endpoint/{print $3}')
  _out IBMCLOUD_API_ENDPOINT=${IBMCLOUD_API_ENDPOINT}

  # Obtain the API endpoint from BLUEMIX_REGION and set it as default
  _out Logging in to IBM cloud
  # Login to ibmcloud, generate .wskprops
  ibmcloud login --apikey ${api_key} -a ${IBMCLOUD_API_ENDPOINT} -r ${BLUEMIX_REGION}
  if [ $? -ne 0 ]; then
    _fatal Failed to login to ibmcloud using api key ${api_key}
  fi

  ibmcloud target -o "$IBMCLOUD_ORG" -s "$IBMCLOUD_SPACE"
  if [ $? -ne 0 ]; then
    _fatal Failed to set target using org ${IBMCLOUD_ORG} and space ${IBMCLOUD_SPACE}
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
  ibmcloud target -g $RESOURCE_GROUP
  if [ $? -ne 0 ]; then
    _err "Failed to set resource group"
    ibmcloud resource groups
    _fatal
  fi
}

function bump_version() {
  _out "Bumping version"
  local file_to_bump="$1"
  local n=$(grep "^VERSION=\d*" ${file_to_bump} | sed "s/VERSION=//")
  n=$((n + 1))
  sed -i "s/^VERSION=[0-9][0-9]*/VERSION=${n}/" ${file_to_bump}
}

function run() {
  CMD="$*"
  SHORT=$(abbreviate_file_path $CMD)
  $*
  if [ $? -ne 0 ]; then
    if [ "x$LOG_FILE" == "x" ]; then
      _fatal "script '${SHORT}' failed."
    else
      _fatal "script '${SHORT}' failed, check $LOG_FILE for more information."
    fi
  fi
  _ok ${SHORT} completed successful
}

function call_api() {
  local api_call_regex="$1"
  _out "Calling api matching regex: ${api_call_regex}"
  local possible_api_calls=$(ibmcloud fn api list | grep "${api_call_regex}" | wc -l)
  if [ ${possible_api_calls} -eq 0 ]; then
    _fatal "No api call with regex '${api_call_regex}' found."
  fi
  if [ ${possible_api_calls} -gt 1 ]; then
    _err "Multiple possible calls found using regex '${api_call_regex}', please be more specific."
    ibmcloud fn api list | grep "${api_call_regex}" >&3
    _fatal
  fi
  local home=$(ibmcloud fn api list | grep "${api_call_regex}" | awk '{print $4}')
  launch_browser_if_available ${home}
  _out "Done! Your browser should have loaded '${home}'."
}

function create_app_id_instance() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x"]; then
    _fatal "create_app_id_instance: missing name of App Id service"
  fi
  requires_or_fatal "BLUEMIX_REGION"
  SERVICE_EXISTS=$(ibmcloud resource service-instance "${app_id_name}")
  if [ $? -eq 0 ]; then
    _out "create_app_id_instance: APP ID service already exists"
    return 1
  fi
  _out Creating App ID service instance ${app_id_name}
  ibmcloud resource service-instance-create ${app_id_name} appid lite ${BLUEMIX_REGION}
  wait_for_service_to_become_active ${app_id_name}
  return 0
}

function create_alias_for_instance() {
  local service="$1"
  if [ "x$service" == "x"]; then
    _fatal "create_alias_for_instance: missing name of service"
  fi
  ALIAS_EXISTS=$(ibmcloud resource service-aliases | grep ${service} | wc -l)
  if [ ${ALIAS_EXISTS} -gt 0 ]; then
    _fatal "create_alias_for_instance: Alias already exists: ${service}"
  fi
  _out Creating alias: ${service}
  ibmcloud resource service-alias-create ${service} --instance-name ${service}
}

function create_app_id_credentials() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x"]; then
    _fatal "create_app_id_credentials: missing name of App Id service"
  fi
  _out Creating App ID credentials
  ibmcloud resource service-key-create ${app_id_name}-credentials Reader --instance-name ${app_id_name}
  ibmcloud resource service-key ${app_id_name}-credentials
}

# TODO may be better for these get functions to return blank, and rely on caller to check a valid
# value exists
function app_id_get_management_url() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x" ]; then
    _fatal "app_id_get_management_url: missing name of App Id service"
  fi
  local val=$(ibmcloud resource service-key ${app_id_name}-credentials | awk '/managementUrl/{ print $2 }')
  if [ "x$val" == "x" ]; then
    _err "app_id_get_management_url: failed to find value"
    ibmcloud resource service-key ${app_id_name}-credentials
    _fatal
  fi
  echo "${val}"
}

function app_id_get_tenant_id() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x" ]; then
    _fatal "app_id_get_tenant_id: missing name of App Id service"
  fi
  local val=$(ibmcloud resource service-key ${app_id_name}-credentials | awk '/tenantId/{ print $2 }')
  if [ "x$val" == "x" ]; then
    _err "app_id_get_management_url: failed to find value"
    ibmcloud resource service-key ${app_id_name}-credentials
    _fatal
  fi
  echo "${val}"
}

function app_id_get_oauth_server_url() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x" ]; then
    _err "app_id_get_oauth_server_url: missing name of App Id service"
    return 1
  fi
  local val=$(ibmcloud resource service-key ${app_id_name}-credentials | awk '/oauthServerUrl/{ print $2 }')
  if [ "x$val" == "x" ]; then
    _err "app_id_get_management_url: failed to find value"
    ibmcloud resource service-key ${app_id_name}-credentials
    return 1
  fi
  echo "${val}"
}

function app_id_get_client_id() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x" ]; then
    _err "app_id_get_client_id: missing name of App Id service"
    return 1
  fi
  local val=$(ibmcloud resource service-key ${app_id_name}-credentials | awk '/clientId/{ print $2 }')
  if [ "x$val" == "x" ]; then
    _err "app_id_get_management_url: failed to find value"
    ibmcloud resource service-key ${app_id_name}-credentials
    return 1
  fi
  echo "${val}"
}

function app_id_get_secret() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x" ]; then
    _err "app_id_get_secret: missing name of App Id service"
    return 1
  fi
  local val=$(ibmcloud resource service-key ${app_id_name}-credentials | awk '/secret/{ print $2 }')
  if [ "x$val" == "x" ]; then
    _err "app_id_get_management_url: failed to find value"
    ibmcloud resource service-key ${app_id_name}-credentials
    return 1
  fi
  echo "${val}"
}

function app_id_add_user() {
  local app_id_name="$1"
  if [ "x$app_id_name" == "x" ]; then
    _err "app_id_add_user: missing name of App Id service"
    return 1
  fi
  local user_email="$2"
  if [ "x$user_email" == "x" ]; then
    _err "app_id_add_user: missing user_email"
    return 1
  fi
  local user_pwd="$3"
  if [ "x$user_pwd" == "x" ]; then
    _err "app_id_add_user: missing user password"
    return 1
  fi
  _out Creating cloud directory test user: $user_email, $user_pwd

  local appid_mgmturl=$(app_id_get_management_url ${app_id_name})
  local IBMCLOUD_BEARER_TOKEN=$(ibmcloud iam oauth-tokens | awk '/IAM/{ print $3" "$4 }')
  if [ "x${IBMCLOUD_BEARER_TOKEN}" == "x" ]; then
    _err "app_id_add_user: Failed to get Bearer Token from iam service (exec: ibmcloud iam oauth-tokens)"
    ibmcloud iam oauth-tokens
    _fatal
  fi
  curl -s -X POST \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: $IBMCLOUD_BEARER_TOKEN" \
    -d '{"emails": [
            {"value": "'$user_email'","primary": true}
          ],
         "userName": "'$user_email'",
         "password": "'$user_pwd'"
        }' \
    "${appid_mgmturl}/cloud_directory/Users"
  if [ $? -ne 0 ]; then
    _fatal "app_id_add_user: Failed to add user '${user_email}' to APP ID" 
  else 
    _ok "User '${user_email}' was added to APP ID"
  fi
}

# The IBM url that is the base of their functions api
function functions_get_base_url() {
  requires_or_fatal "BLUEMIX_REGION"
  echo "https://${BLUEMIX_REGION}.functions.appdomain.cloud/api/v1/web"
}

# @return the file holding the key information
function create_new_project_key() {
  local project_name="$1"
  _out "Creating new API key for project"
  local root_folder=$(get_root_folder)
  local api_key_file="${root_folder}/${project_name}.json"
  ibmcloud iam api-key-create ${project_name} -d "${project_name}" --file "${api_key_file}"
  if [ $? -ne 0 ]; then
    _fatal "Failed to create api-key file $(abbreviate_file_path ${api_key_file}), no key created."
  fi
  _out "[WARNING] Remember not to save the file $(abbreviate_file_path ${api_key_file}) to the git repository!"
  RETVAL="${api_key_file}"
}

function get_project_api_key() {
  local project_name="$1"
  if [ "x$project_name" == "x" ]; then
    _fatal "get_project_api_key: no project name given"
  fi
  local root_folder=$(get_root_folder)
  local api_key_file="${root_folder}/${project_name}.json"
  if [ ! -e "${api_key_file}" ]; then
    api_key_file=$( find "${root_folder}/../.." -type f -iname "${project_name}.json" )
    if [ "x${api_key_file}" == "x" ]; then
      _fatal "get_project_api_key: could not find ${api_key_file}"
    fi
  fi
  local api_key=$(grep "\"apikey" ${api_key_file} | awk '{print $2}' | sed "s/[\",]//g")
  if [ "x$api_key" == "x" ]; then
    _fatal "get_project_api_key: apikey field was empty or not found"
  fi
  echo "${api_key}"
}

function check_if_api_key_exists() {
  local key="$1"
  if [ "x$key" == "x" ]; then
    _fatal "check_if_api_key_exists: no key specified to check"
  fi
  local found=$(ibmcloud iam api-keys | grep "^${key}")
  if [ "x$found" == "x" ]; then
    return 1
  else
    return 0
  fi
}

function check_if_object_storage_exists() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "check_if_object_storage_exists: name required"
  fi
  ibmcloud resource service-instance ${name}
  if [ $? -eq 0 ]; then
    _out "Object storage ${name} already exists"
    return 1
  fi
  return 0
}

function create_object_storage_instance() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_object_storage_instance: name required"
  fi
  check_if_object_storage_exists "${name}"
  if [ $? -ne 0 ]; then
    return 1
  fi
  _out Creating Object Storage service instance: ${name}
  ibmcloud resource service-instance-create ${name} cloud-object-storage lite global
  wait_for_service_to_become_active ${name}
  return 0
}

function get_object_storage_id() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "get_object_storage_id: name required"
  fi
  local cos_id=$(ibmcloud resource service-instance ${name} --id | awk '/crn/{ print $2 }')
  if [ "x$cos_id" == "x" ]; then
    _err "Could not get the id for the object storage service named '${name}', does the resource exist?"
    ibmcloud resource service-instances
    _fatal
  fi
  echo "${cos_id}"
}

function get_oauth_token() {
  echo "$(ibmcloud iam oauth-tokens | awk '/IAM/{ print $3" "$4 }')"
}

function check_if_bucket_exists() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_bucket: name required"
  fi
  ibmcloud cos bucket-head --bucket ${name}
  if [ $? -eq 0 ]
  then
    _err "Bucket ${name} already exists."
    return 1
  fi
  return 0
}

function create_bucket() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_bucket: name required"
  fi
  check_if_bucket_exists ${name}
  if [ $? -ne 0 ]; then
    # this is not a fatal error as there may
    # be other buckets and we can then add to 
    # an existing bucket
    return 1
  fi
  local object_storage_name="$2"
  if [ "x$object_storage_name" == "x" ]; then
    _fatal "create_bucket: object_storage_name required"
  fi
  _out Creating bucket for ${name}
  local cos_id=$(get_object_storage_id ${object_storage_name})
  ibmcloud cos create-bucket --bucket "${name}" --ibm-service-instance-id ${cos_id} --region ${BLUEMIX_REGION}
  if [ $? -ne 0 ]
  then
    _fatal "Failed to create new bucket called '${name}'."
  fi
}

function check_if_cloudant_service_exists() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "check_if_cloudant_service_exists: name required"
  fi
  ibmcloud resource service-instance "${name}"
  if [ $? -eq 0 ]; then
    _err "Cloudant service '${name}' already exists"
    return 1
  fi
  return 0
}

function create_cloudant_service() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_cloudant_service: name required"
  fi
  check_if_cloudant_service_exists "${name}"
  if [ $? -ne 0 ]; then
    return 1
  fi
  ibmcloud resource service-instance-create ${name} cloudantnosqldb lite ${BLUEMIX_REGION} -p '{"legacyCredentials": false}'  
  wait_for_service_to_become_active ${name}
  return 0
}

function create_cloudant_credentials() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_cloudant_credentials: name required"
  fi
  ibmcloud resource service-key-create ${name}_credentials Manager --instance-name ${name}
  if [ $? -ne 0 ]; then
    _fatal "create_cloudant_credentials: Could not create cloudant credentials service '${name}_credentials'"
  fi
  return 0
}

function get_service_key() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "get_service_key: name required"
  fi
  local apikey=$(ibmcloud resource service-key ${name}_credentials | awk '/apikey:/{print $2}')
  echo "${apikey}"
}

function get_service_username() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "get_service_username: name required"
  fi
  local username=$(ibmcloud resource service-key ${name}_credentials | awk '/username/{print $2}')
  echo "${username}"
}

function check_if_function_namespace_exist() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "check_if_function_namespace_exist: name required"
  fi
  local ns_exists=$( ibmcloud fn namespace list | grep "^$name" )
  if [ "x$ns_exists" == "x" ]; then
    return 0
  fi
  return 1
}

function create_function_namespace() {
  local name="$1"
  local description="$2"
  if [ "x$name" == "x" ]; then
    _fatal "create_function_namespace: name required"
  fi
  check_if_function_namespace_exist $name
  if [ $? -eq 1 ]; then
    _err "create_function_namespace: Function namespace ${name} already exists."
    return 1
  fi
  _out Creating namespace for ${name}
  ibmcloud fn namespace create ${name} --description "$description"
  if [ $? -ne 0 ]; then
    _fatal "create_function_namespace: Failed to create new namespace named '${name}'"
  fi
  return 0
}

function set_default_function_namespace() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_function_namespace: name required"
  fi
  check_if_function_namespace_exist $name
  if [ $? -eq 0 ]; then
    _fatal "set_default_function_namespace: Function namespace ${name} does not exist."
  fi
  ibmcloud fn property set --namespace ${name}
  if [ $? -ne 0 ]; then
    _fatal "set_default_function_namespace: Failed to set default namespace to '${name}', check it exists."
  fi
  return 0
}

function check_if_default_function_namespace_is_set() {
  local name="$1"
  local ns=$(ibmcloud fn property get --namespace | grep "^$name")
  if [ "x$ns" == "x" ]; then
    return 0
  fi
  return 1
}

# Only works if namespace has been set
function check_if_package_exists() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "check_if_package_exists: name required"
  fi
  FOUND=$(ibmcloud fn package list | grep "/${name} ")
  if [ "x$FOUND" == "x" ]; then
    return 0
  fi
  return 1
}

function create_function_package() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "create_function_package: name required"
  fi
  check_if_package_exists ${name}
  if [ $? == 1 ]; then
    _out "Package ${name} already exists."
    return 2
  fi
  ibmcloud wsk package create ${name}
  if [ $? -ne 0 ]; then
    _fatal "create_function_package: Failed to create new package '${name}'."
  fi
  return 0
}

function check_if_function_action_exists() {
  local action_name="$1"
  if [ "x$action_name" == "x" ]; then
    _fatal "check_if_function_action_exists: name required"
  fi
  FOUND=$( ibmcloud fn action list | grep "/${action_name}" )
  if [ "x${FOUND}" == "x" ]; then
    return 1
  fi
  return 0
}

#
# If you need to pass -p arguments to 'create action' then
# you need to use this structure in your code:
#
# action_name="${FN_GENERIC_PACKAGE}/login"
# action_js="${root_folder}/../../function-login/login.js"
# pre_check_for_function_action "$action_name" "$action_js" "${NODE_VERSION}"
# if [ $? -eq 0 ]; then
#     ibmcloud wsk action create "$action_name" "$action_js" --kind "${NODE_VERSION}" -p config "${CONFIG}"
#     if [ $? -ne 0 ]; then
#         _fatal "create_function_action: Could not create function action '${action_name}'"
#     fi
# fi
#
function pre_check_for_function_action() {
  local action_name="$1"
  local action_js="$2"
  local node_version="$3"
  if [ "x$action_name" == "x" ]; then
    _fatal "pre_check_for_function_action: name required"
  fi
  if [ ! -e "$action_js" ]; then
    _fatal "pre_check_for_function_action: Could not find '${action_js}', file is missing."
  fi
  if [ "x$node_version" == "x" ]; then
    _fatal "pre_check_for_function_action: --kind argument value is empty"
  fi
  check_if_function_action_exists ${action_name}
  if [ $? -eq 0 ]; then
    _out Function action ${action_name} already exists.
    return 2
  fi
  _out Creating action ${action_name}
}

# This function is hard and I am not sure it will actually be much use.
# Basically the create action takes a set of arguments that we can either
# pass as an array or as a string.  As a string we can use eval to expand
# the string into separate arguments, but this is a big security hole.
function create_function_action() {
  local action_name="$1"
  local action_js="$2"
  local node_version="$3"
  if [ "x$action_name" == "x" ]; then
    _fatal "create_function_action: name required"
  fi
  if [ ! -e "$action_js" ]; then
    _fatal "create_function_action: Could not find '${action_js}', file is missing."
  fi
  if [ "x$node_version" == "x" ]; then
    node_version="nodejs:10"
  fi
  check_if_function_action_exists ${action_name}
  if [ $? -eq 0 ]; then
    _out Function action ${action_name} already exists.
    return 2
  fi
  _out Creating action ${action_name}
  ibmcloud wsk action create "$action_name" "$action_js" --kind "${node_version}"
  if [ $? -ne 0 ]; then
    _fatal "create_function_action: Could not create function action '${action_name}'"
  fi
  return 0
}

# function update_function_action() {
#   local action_name="$1"
#   local action_js="$2"
#   local node_version="$3"
#   local args="$4"
#   local action_name="$1"
#   if [ "x$action_name" == "x" ]; then
#     _fatal "update_function_action: name required"
#   fi
#   if [ ! -e "$action_js" ]; then
#     _fatal "update_function_action: Could not find '${action_js}', file is missing."
#   fi
#   if [ "x$node_version" == "x"]; then
#     node_version="nodejs:10"
#   fi
#   ibmcloud wsk action update "${action_name}" "$action_js" --kind ${node_version} ${args}
#   if [ $? -ne 0 ]; then
#     _fatal "update_function_action: Could not update function action '${action_name}'"
#     return 1
#   fi
#   return 0 
# }

function pre_check_for_function_sequence() {
  local action_name="$1"
  local sequence="$2"
  if [ "x$action_name" == "x" ]; then
    _fatal "pre_check_for_function_sequence: name required"
  fi
  if [ "x$sequence" == "x" ]; then
    _fatal "pre_check_for_function_sequence: comma separated action sequence required"
  fi
  check_if_function_action_exists ${action_name}
  if [ $? -eq 0 ]; then
    _out Function action sequence ${action_name} already exists.
    return 2
  fi
}

# Can only be used when creating without any -p values, may be useless.
function create_function_sequence() {
  local action_name="$1"
  local sequence="$2"
  if [ "x$action_name" == "x" ]; then
    _fatal "create_function_sequence: name required"
  fi
  if [ "x$sequence" == "x" ]; then
    _fatal "create_function_sequence: comma separated action sequence required"
  fi
  check_if_function_action_exists ${action_name}
  if [ $? -eq 0 ]; then
    _out Function action sequence ${action_name} already exists.
    return 2
  fi
  ibmcloud wsk action update --sequence "${action_name}" "${sequence}"
  if [ $? -ne 0 ]; then
    _fatal "create_function_sequence: Could not create function sequence '${action_name}'"
    return 1
  fi
  return 0 
}

function create_api() {
return 0
}

function register_redirect_uri_with_app_id() {
return 0
}

function make_operation_from_name() {
  local name="$1"
  if [ "x$name" == "x" ]; then
    _fatal "make_operation_from_name: name required"
  fi
  local operation="$(tr '[:lower:]' '[:upper:]' <<< ${name:0:1})${name:1}"
  echo "get${operation}"
}

function upload_directory_to_storage_bucket() {
  local BUCKET_URL="$1"
  local DIRECTORY="$2"
  if [ "x$BUCKET_URL" == "x" ]; then
    _fatal "upload_directory_to_storage_bucket: bucket_url is empty string"
  fi
  # TODO For some reason we just need the 4th not 3,4 as we needed before - check why
  #IAM_TOKEN=$(get_oauth_token)
  IAM_TOKEN=$(ibmcloud iam oauth-tokens | awk '/IAM/{ print $4 }')
  if [ "x${IAM_TOKEN}" == "x" ]; then
    _fatal "Failed to get new oauth token, are you logged in?"
  fi

  _out Uploading files to bucket 
  for local_file in $( find "$DIRECTORY" -maxdepth 1 -type f )
  do
    base=$(basename "$local_file")
    _out "Uploading ${base}"
    curl -X "PUT" "${BUCKET_URL}/${base}" \
        -H "x-amz-acl: public-read" \
        -H "Authorization: Bearer ${IAM_TOKEN}" \
        -H "Content-Type: text/plain; charset=utf-8" \
        --upload-file "${local_file}"
    if [ $? -ne 0 ]; then
      _fatal "Failed to upload ${local_file} to ${BUCKET_URL}/${base}"
    else
      _ok "Successfully uploaded $(abbreviate_file_path ${local_file})"
    fi
  done
}

