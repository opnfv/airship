#!/bin/bash

set -e

# Implements run of the OPNFV functional tests (Functest)
# https://wiki.opnfv.org/pages/viewpage.action?pageId=29098314

export FUNCTEST_CACHE=${FUNCTEST_CACHE:-"${HOME}/.opnfv/functest"}

TMP_DIR=$(mktemp -d)
cd $TMP_DIR

trap "{ sudo rm -rf $TMP_DIR; }" EXIT


touch env

cat > openstack.creds << EOF
export OS_AUTH_URL='http://identity-airship.intel-pod17.opnfv.org:80/v3'
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_USERNAME=admin
export OS_PROJECT_NAME=admin
export OS_PASSWORD=password123
export OS_IDENTITY_API_VERSION=3
EOF

# check/download images
if [ ! -d $FUNCTEST_CACHE ]; then
  mkdir -p $FUNCTEST_CACHE/images && cd $FUNCTEST_CACHE
  wget -q -O- https://git.opnfv.org/functest/plain/functest/ci/download_images.sh?h=stable/hunter | bash -s -- images
  cd $TMP_DIR
fi


help() {
  echo "Usage: $0 <healthcheck|smoke>"
}


run_healthcheck_tests() {
  sudo docker run --env-file env \
      -v $(pwd)/openstack.creds:/home/opnfv/functest/conf/env_file \
      -v ${FUNCTEST_CACHE}/images:/home/opnfv/functest/images \
      opnfv/functest-healthcheck:hunter
}

run_smoke_tests() {
  sudo docker run --env-file env \
      -v $(pwd)/openstack.creds:/home/opnfv/functest/conf/env_file \
      -v ${FUNCTEST_CACHE}/images:/home/opnfv/functest/images \
      opnfv/functest-smoke:hunter
}


case "$1" in
'healthcheck')
  run_healthcheck_tests
  ;;
'smoke')
  run_smoke_tests
  ;;
*) help
   exit 1
  ;;
esac

