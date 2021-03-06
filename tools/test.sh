#!/bin/bash

set -e

# Implements run of the OPNFV functional tests (Functest)
# https://wiki.opnfv.org/pages/viewpage.action?pageId=29098314

export FUNCTEST_CACHE=${FUNCTEST_CACHE:-"${HOME}/.opnfv/functest"}
export SITE=${2:-"intel-pod17"}

cp tools/files/tempest_conf.yaml ${FUNCTEST_CACHE}
cp tools/files/rally_blacklist.yaml ${FUNCTEST_CACHE}
cp tools/files/tempest_blacklist.yaml ${FUNCTEST_CACHE}
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

trap "{ sudo rm -rf $TMP_DIR; }" EXIT


cat > env << EOF
S3_ENDPOINT_URL=https://storage.googleapis.com
S3_DST_URL=s3://artifacts.opnfv.org/xtesting/test
HTTP_DST_URL=http://artifacts.opnfv.org/xtesting/test
TEST_DB_URL=http://testresults.opnfv.org/test/api/v1/results
TEST_DB_EXT_URL=http://testresults.opnfv.org/test/api/v1/results
EXTERNAL_NETWORK=public
BLOCK_MIGRATION=False
DEPLOY_SCENARIO=ovs
NO_TENANT_NETWORK=true
FLAVOR_EXTRA_SPECS=hw:mem_page_size:large
NEW_USER_ROLE=_member_
EOF

cat > openstack.env << EOF
export OS_AUTH_URL=http://identity-nc.$SITE.opnfv.org/v3
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_USERNAME=admin
export OS_PROJECT_NAME=admin
export OS_PASSWORD=0bbaf9908f63abec8ffb
export OS_IDENTITY_API_VERSION=3
export OS_INTERFACE=public
export OS_REGION_NAME=$SITE
EOF

# check/download images
if [ ! -d $FUNCTEST_CACHE ]; then
  mkdir -p $FUNCTEST_CACHE/images && cd $FUNCTEST_CACHE
  wget -q -O- https://git.opnfv.org/functest/plain/functest/ci/download_images.sh?h=stable/iruya | bash -s -- images
  cd $TMP_DIR
fi


help() {
  echo "Usage: $0 <healthcheck|smoke|vnf>"
}


run_tests() {

  sudo rm -rf ${FUNCTEST_CACHE}/results && mkdir ${FUNCTEST_CACHE}/results
  sudo docker pull opnfv/functest-${1}:iruya
  sudo docker run -it --env-file env --network host \
      -v $(pwd)/openstack.env:/home/opnfv/functest/conf/env_file \
      -v ${FUNCTEST_CACHE}/.boto:/root/.boto \
      -v ${FUNCTEST_CACHE}/images:/home/opnfv/functest/images \
      -v ${FUNCTEST_CACHE}/results:/home/opnfv/functest/results \
      -v ${FUNCTEST_CACHE}/tempest_conf.yaml:/usr/lib/python3.6/site-packages/functest/opnfv_tests/openstack/tempest/custom_tests/tempest_conf.yaml \
      -v ${FUNCTEST_CACHE}/tempest_blacklist.yaml:/usr/lib/python3.6/site-packages/functest/opnfv_tests/openstack/tempest/custom_tests/blacklist.yaml \
      -v ${FUNCTEST_CACHE}/rally_blacklist.yaml:/usr/lib/python3.6/site-packages/functest/opnfv_tests/openstack/rally/blacklist.yaml \
      -v /home/opnfv/functest/singlevm.py:/usr/lib/python3.6/site-packages/functest/core/singlevm.py \
      opnfv/functest-${1}:iruya bash
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
