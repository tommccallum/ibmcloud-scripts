#!/bin/bash

source ibm_std_functions.sh
setup_logging "./test.log"

ENV_FILE="./test.env.conf"
[[ -e ${ENV_FILE} ]] && rm ${ENV_FILE}
touch $ENV_FILE

# add key to file
set_var_in_env "KEY" "VALUE"
cat ${ENV_FILE}
echo

# modify key in file
set_var_in_env "KEY" "VALUE2"
cat ${ENV_FILE}
echo

# remove key from file
set_var_in_env "KEY" 
cat ${ENV_FILE}
echo