#!/bin/bash
export DOCKER_EXE=podman
export WORK_DIR=/home/ibmuser/concert
export OCP_URL=https://api.ocp.ibm.edu:6443
export PROJECT_OPERATOR=aaf
export PROJECT_INSTANCE=concert
export STG_CLASS_BLOCK=managed-nfs-storage
export STG_CLASS_FILE=managed-nfs-storage
export IBM_ENTITLEMENT_KEY=
export OCP_PASSWORD=ibmrhocp
export OCP_USERNAME=ocadmin

# =============================
# DO NOT change after this line
# =============================
# Log in to OpenShift and get the login token
TOKEN=$(oc login $OCP_URL --username=$OCP_USERNAME --password=$OCP_PASSWORD --insecure-skip-tls-verify)

# Check if the login was successful
if [ $? -eq 0 ]; then
    echo "Login successful. Your token is:"
    echo "$TOKEN"
else
    echo "Login failed. Please check your credentials or API URL."
    exit 1
fi

# Get the login token
OCP_TOKEN=$(oc whoami -t)

# Check if token retrieval was successful
if [ $? -ne 0 ]; then
    echo "Failed to retrieve the token."
    exit 1
fi

# Output the token
echo "Login token: $OCP_TOKEN"

# Optionally, you can save the token to a file
echo "$OCP_TOKEN" > openshift_token.txt

# Download the Concert manage script (ibm-concert-manage.sh) to the workstation
wget https://raw.githubusercontent.com/IBM/Concert/refs/heads/main/Software/manage/ibm-concert-manage.sh

# Update the permissions to make it executable
chmod +x ibm-concert-manage.sh

# Initialize the installation by deploying the ibm-aaf-utils container 
# through which all other commands are run
./ibm-concert-manage.sh initialize

# Log in to the Red Hat OpenShift Container Platform cluster
./ibm-concert-manage.sh login-to-ocp --user=${OCP_USERNAME} --password=${OCP_PASSWORD} --server=${OCP_URL}
./ibm-concert-manage.sh login-to-ocp --token=${OCP_TOKEN} --server=${OCP_URL}

# Set up your instance by deploying the prerequisites and the 
# Concert components on the operator and instance projects
./ibm-concert-manage.sh concert-setup

