#!/bin/bash

KEY_NAME="my_login_api_key"
KEY_DESC="key for logging into the ibm cloud cli"
KEY_FILE="ibm_api_key.txt"

echo "Generating new key in the file ${KEY_FILE}"
ibmcloud iam api-key-create "${KEY_NAME}" -d "${KEY_DESC}" --file "${KEY_FILE}"
echo "To check your keys online, find the key named ${KEY_NAME}."
echo "To find out more, check out https://cloud.ibm.com/docs/account?topic=account-federated_id"
