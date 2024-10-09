#!/bin/bash -x

# Set your OpenShift cluster's API URL and your credentials
API_URL="https://api.ocp.ibm.edu:6443"

USERNAME="ocadmin"
PASSWORD="ibmrhocp"

# Log in to OpenShift and get the login token
#TOKEN=$(oc login $API_URL --username=$USERNAME --password=$PASSWORD --token-only 2>/dev/null)
TOKEN=$(oc login $API_URL --username=$USERNAME --password=$PASSWORD --insecure-skip-tls-verify)

# Check if the login was successful
if [ $? -eq 0 ]; then
    echo "Login successful. Your token is:"
    echo "$TOKEN"
else
    echo "Login failed. Please check your credentials or API URL."
    exit 1
fi

# Get the login token
TOKEN=$(oc whoami -t)

# Check if token retrieval was successful
if [ $? -ne 0 ]; then
    echo "Failed to retrieve the token."
    exit 1
fi

# Output the token
echo "Login token: $TOKEN"

# Optionally, you can save the token to a file
# echo "$TOKEN" > openshift_token.txt
