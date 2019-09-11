#!/bin/bash

set -e

# Implements run of the OPNFV functional tests (Functest)
# https://wiki.opnfv.org/pages/viewpage.action?pageId=29098314

export FUNCTEST_CACHE=${FUNCTEST_CACHE:-"${HOME}/.opnfv/functest"}

TMP_DIR=$(mktemp -d)
cd $TMP_DIR

trap "{ sudo rm -rf $TMP_DIR; }" EXIT


cat > env << EOF
EXTERNAL_NETWORK=public
BLOCK_MIGRATION=False
EOF

cat > tempest_conf.yaml << EOF
---
compute:
    max_microversion: 2.42
compute-feature-enabled:
    shelve: false
    vnc_console: false
    cold_migration: false
    block_migration_for_live_migration: false
identity-feature-enabled:
    api_v2: false
    api_v2_admin: false
image-feature-enabled:
    api_v2: true
    api_v1: false
placement:
    max_microversion: 1.4
volume:
    max_microversion: 3.27
    storage_protocol: ceph
volume-feature-enabled:
    backup: true
object-storage-feature-enabled:
    discoverability: false
EOF

cat > openstack.creds << EOF
export OS_AUTH_URL=http://identity-airship.intel-pod17.opnfv.org/v3
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_USERNAME=admin
export OS_PROJECT_NAME=admin
export OS_PASSWORD=password123
export OS_IDENTITY_API_VERSION=3
export OS_INTERFACE=public
export OS_REGION_NAME=intel-pod17
EOF

# check/download images
if [ ! -d $FUNCTEST_CACHE ]; then
  mkdir -p $FUNCTEST_CACHE/images && cd $FUNCTEST_CACHE
  wget -q -O- https://git.opnfv.org/functest/plain/functest/ci/download_images.sh?h=stable/hunter | bash -s -- images
  cd $TMP_DIR
fi


help() {
  echo "Usage: $0 <healthcheck|smoke|vnf>"
}


run_tests() {

  sudo rm -rf ${FUNCTEST_CACHE}/results && mkdir ${FUNCTEST_CACHE}/results

  sudo docker run --env-file env \
      -v $(pwd)/openstack.creds:/home/opnfv/functest/conf/env_file \
      -v ${FUNCTEST_CACHE}/images:/home/opnfv/functest/images \
      -v ${FUNCTEST_CACHE}/results:/home/opnfv/functest/results \
      -v $(pwd)/tempest_conf.yaml:/usr/lib/python2.7/site-packages/functest/opnfv_tests/openstack/tempest/custom_tests/tempest_conf.yaml \
      opnfv/functest-${1}:hunter
}

case "$1" in
'healthcheck')
  run_tests $1
  ;;
'smoke')
  run_tests $1
  ;;
'benchmarking')
  run_tests $1
  ;;
'vnf')
  run_tests $1
  ;;
*) help
   exit 1
  ;;
esac
