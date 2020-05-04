#!/bin/bash 
#Checks shipyard action status 
 
set -e 
CONTAINER="shipyard-api" 
TEMP_RESULT=${TEMP_RESULT:-$(mktemp)} 
API=$(kubectl get pods -n ucp -l application=shipyard,component=api --no-headers | awk '{print $1}' | head -n 1) 
# this doesn't actually get exported to environment unless the script is sourced 
export OS_PASSWORD=$(kubectl exec -it ${API} -n ucp -c ${CONTAINER} -- cat /etc/shipyard/shipyard.conf | grep "password =" | awk '{print $3}' | tr -d '\r') 
OS_AUTH_URL=$(kubectl exec -it ${API} -n ucp -c ${CONTAINER} -- cat /etc/shipyard/shipyard.conf |grep "auth_uri =" | awk '{print $3}' | tr -d '\r') 
SHIPYARD_IMAGE=$(kubectl get po ${API} -n ucp -o jsonpath="{.spec.containers[0].image}") 
SHIPYARD_HOSTPATH="/target" 
SHIPYARD_IMAGE="${SHIPYARD_IMAGE}" 
LIST_STEPS=$(mktemp) 
 
# Define Base Docker Command 
base_docker_command=$(cat << EndOfCommand 
sudo -E docker run -t --rm --net=host 
-e no_proxy=${NO_PROXY:-127.0.0.1,localhost,.svc.cluster.local} 
-e OS_AUTH_URL=${OS_AUTH_URL} 
-e OS_USERNAME=${OS_USERNAME:-shipyard} 
-e OS_USER_DOMAIN_NAME=${OS_DOMAIN:-default} 
-e OS_PASSWORD 
-e OS_PROJECT_DOMAIN_NAME=${OS_PROJECT_DOMAIN_NAME:-default} 
-e OS_PROJECT_NAME=${OS_PROJECT_NAME:-service} 
EndOfCommand 
) 
 
echo "$OS_AUTH_URL" 
 
# Execute Shipyard CLI 
 
     ${base_docker_command} -v "$(pwd)":"${SHIPYARD_HOSTPATH}" "${SHIPYARD_IMAGE}" "${@}"
