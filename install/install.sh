#!/bin/bash

export IBM_ENTITLEMENT_KEY=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE2MDE5MzU5MzIsImp0aSI6IjJjN2U3ZWJmNDkwYjRmODVhYWY1OGFhNmQ3NWI4ODYxIn0.SB8ceB6b630fG_mU-vGzkffAdLi9YhMEZK4maH10nF0
export CONCERT_ID=ibmconcert
export CONCERT_PW=passw0rd
export CONCERT_NS=ibm-concert
export CONCERT_SC=ocs-storagecluster-ceph-rbd
export OCP_USERNAME=ocadmin
export OCP_PASSWORD=ibmrhocp
export OCP_URL=https://api.ocp.ibm.edu:6443

# =============================
# DO NOT change after this line
# =============================

wget https://github.com/IBM/Concert/blob/main/Software/manage/ibm-concert-manage.sh 
chmod +x ibm-concert-manage.sh
./ibm-concert-manage.sh initialize
./ibm-concert-manage.sh login-to-ocp --user=${OCP_USERNAME} --password=${OCP_PASSWORD} --server=${OCP_URL}
podman cp ibm-aaf-utils:/opt/ansible/service-configs/concert/1.0.1/ibm-roja-k8s.tgz ibm-roja-k8s.tgz
tar -xzvf ibm-roja-k8s.tgz

export IMG_PREFIX=cp.icr.io/cp/concert
export REG_USER=cp
export REG_PASS=${IBM_ENTITLEMENT_KEY}
export ROJA_ADM_USERNAME=${CONCERT_ID}
export ROJA_ADM_PASSWORD=${CONCERT_PW}

./ibm-roja-k8s/deploy-k8s.sh --namespace=${CONCERT_NS} --storage_class=${CONCERT_SC} --cfg=sw_ent_native

./ibm-roja-k8s/ocp-route.sh ${CONCERT_NS}
